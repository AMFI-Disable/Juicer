import Foundation
import Combine

public struct DatabaseDaemon: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let port: Int
    public let isRunning: Bool
    public let defaultPort: Int
    public let iconName: String

    public init(id: UUID = UUID(), name: String, port: Int, isRunning: Bool, defaultPort: Int, iconName: String) {
        self.id = id
        self.name = name
        self.port = port
        self.isRunning = isRunning
        self.defaultPort = defaultPort
        self.iconName = iconName
    }
}

public struct LocalSQLiteFile: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let path: String
    public let size: String

    public init(id: UUID = UUID(), name: String, path: String, size: String) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
    }
}

public struct DatabaseConnectionInfo: Equatable {
    public let scheme: String
    public let host: String
    public let port: Int?
    public let username: String?
    public let password: String?
    public let databaseName: String?
    public let path: String?
    public let queryParameters: [String: String]

    public init(
        scheme: String,
        host: String,
        port: Int? = nil,
        username: String? = nil,
        password: String? = nil,
        databaseName: String? = nil,
        path: String? = nil,
        queryParameters: [String: String] = [:]
    ) {
        self.scheme = scheme
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.databaseName = databaseName
        self.path = path
        self.queryParameters = queryParameters
    }
}

public enum DatabaseError: Error, LocalizedError, Equatable {
    case invalidConnectionString(reason: String)
    case invalidPort(Int)
    case pathTraversalDenied(path: String)
    case fileNotFound(path: String)
    case queryExecutionFailed(reason: String)
    case timeout(duration: TimeInterval)
    case invalidHost(host: String)

    public var errorDescription: String? {
        switch self {
        case .invalidConnectionString(let reason):
            return "Invalid connection string: \(reason)"
        case .invalidPort(let port):
            return "Invalid port number: \(port). Port must be between 1 and 65535."
        case .pathTraversalDenied(let path):
            return "Access denied due to directory traversal sequence in path: \(path)"
        case .fileNotFound(let path):
            return "Database file not found: \(path)"
        case .queryExecutionFailed(let reason):
            return "Query execution failed: \(reason)"
        case .timeout(let duration):
            return "Database operation timed out after \(Int(duration)) seconds"
        case .invalidHost(let host):
            return "Invalid host specified: \(host)"
        }
    }
}

final class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()

    @Published var daemons: [DatabaseDaemon] = []
    @Published var sqliteFiles: [LocalSQLiteFile] = []
    @Published var isRefreshing = false
    @Published var activeCount = 0

    private var isInitialized = false

    private init() {}

    func ensureInitialized() {
        guard !isInitialized else { return }
        isInitialized = true
        refreshAll()
    }

    func purgeMemory() {
        sqliteFiles.removeAll(keepingCapacity: false)
    }

    func refreshAll() {
        isRefreshing = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let postgresOk = self.checkPort(5432)
            let mysqlOk = self.checkPort(3306)
            let redisOk = self.checkPort(6379)
            let mongoOk = self.checkPort(27017)

            let daemonList = [
                DatabaseDaemon(name: "PostgreSQL", port: 5432, isRunning: postgresOk, defaultPort: 5432, iconName: "cylinder.split.1x2.fill"),
                DatabaseDaemon(name: "MySQL / MariaDB", port: 3306, isRunning: mysqlOk, defaultPort: 3306, iconName: "externaldrive.fill"),
                DatabaseDaemon(name: "Redis Cache", port: 6379, isRunning: redisOk, defaultPort: 6379, iconName: "bolt.horizontal.fill"),
                DatabaseDaemon(name: "MongoDB", port: 27017, isRunning: mongoOk, defaultPort: 27017, iconName: "leaf.fill")
            ]

            let active = daemonList.filter { $0.isRunning }.count
            let foundSQLite = self.scanSQLiteFiles()

            DispatchQueue.main.async {
                self.daemons = daemonList
                self.activeCount = active
                self.sqliteFiles = foundSQLite
                self.isRefreshing = false
            }
        }
    }

    @discardableResult
    func checkPort(_ port: Int, host: String = "127.0.0.1", timeout: TimeInterval = 2.0) -> Bool {
        guard (1...65535).contains(port) else {
            return false
        }
        let sanitizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedHost.isEmpty,
              !sanitizedHost.contains(where: { $0.isWhitespace || $0.isNewline || $0 == ";" || $0 == "&" || $0 == "|" }) else {
            return false
        }

        let boundedTimeout = max(1.0, min(timeout, 10.0))
        let timeoutSecs = Int(ceil(boundedTimeout))

        let result = CommandExecutor.shared.run(
            executablePath: "/usr/bin/nc",
            arguments: ["-z", "-w", "\(timeoutSecs)", sanitizedHost, "\(port)"],
            timeout: boundedTimeout + 1.0
        )
        return result.succeeded
    }

    func parseConnectionString(_ uriString: String) -> Result<DatabaseConnectionInfo, DatabaseError> {
        let trimmed = uriString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.invalidConnectionString(reason: "Connection string cannot be empty"))
        }

        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(), !scheme.isEmpty else {
            return .failure(.invalidConnectionString(reason: "Missing or invalid URI scheme"))
        }

        let supportedSchemes = ["postgres", "postgresql", "mysql", "redis", "mongodb", "sqlite", "file"]
        guard supportedSchemes.contains(scheme) else {
            return .failure(.invalidConnectionString(reason: "Unsupported database scheme: \(scheme)"))
        }

        var queryParams: [String: String] = [:]
        if let queryItems = components.queryItems {
            for item in queryItems {
                queryParams[item.name] = item.value ?? ""
            }
        }

        if scheme == "sqlite" || scheme == "file" {
            let path = components.path
            guard !path.isEmpty else {
                return .failure(.invalidConnectionString(reason: "SQLite path cannot be empty"))
            }
            if path.contains("..") {
                return .failure(.pathTraversalDenied(path: path))
            }
            return .success(DatabaseConnectionInfo(
                scheme: scheme,
                host: "localhost",
                path: path,
                queryParameters: queryParams
            ))
        }

        let host = components.host ?? "127.0.0.1"
        if host.contains(where: { $0.isWhitespace || $0 == ";" || $0 == "&" || $0 == "|" }) {
            return .failure(.invalidHost(host: host))
        }

        let port: Int? = components.port
        if let p = port {
            guard (1...65535).contains(p) else {
                return .failure(.invalidPort(p))
            }
        }

        let username = components.user?.isEmpty == false ? components.user : nil
        let password = components.password?.isEmpty == false ? components.password : nil
        let dbName = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let databaseName = dbName.isEmpty ? nil : dbName

        return .success(DatabaseConnectionInfo(
            scheme: scheme,
            host: host,
            port: port,
            username: username,
            password: password,
            databaseName: databaseName,
            queryParameters: queryParams
        ))
    }

    func sanitizeSQLitePath(_ path: String) -> Result<String, DatabaseError> {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.fileNotFound(path: path))
        }
        if trimmed.contains("..") {
            return .failure(.pathTraversalDenied(path: trimmed))
        }
        let expandedPath = (trimmed as NSString).expandingTildeInPath
        let canonicalPath = (expandedPath as NSString).standardizingPath
        if canonicalPath.contains("..") {
            return .failure(.pathTraversalDenied(path: canonicalPath))
        }
        guard FileManager.default.fileExists(atPath: canonicalPath) else {
            return .failure(.fileNotFound(path: canonicalPath))
        }
        return .success(canonicalPath)
    }

    func runSQLiteQuery(
        dbPath: String,
        query: String,
        options: [String] = [],
        timeout: TimeInterval = 10.0
    ) -> Result<String, DatabaseError> {
        switch sanitizeSQLitePath(dbPath) {
        case .failure(let error):
            return .failure(error)
        case .success(let safePath):
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedQuery.isEmpty else {
                return .failure(.queryExecutionFailed(reason: "Query string cannot be empty"))
            }
            guard !trimmedQuery.contains("\0") else {
                return .failure(.queryExecutionFailed(reason: "Query contains null byte character"))
            }

            let boundedTimeout = max(1.0, min(timeout, 60.0))
            let safeOptions = options.filter { $0.hasPrefix("-") && !$0.contains("..") && !$0.contains(";") }
            var arguments = safeOptions
            arguments.append(safePath)
            arguments.append(trimmedQuery)

            let result = CommandExecutor.shared.run(
                executablePath: "/usr/bin/sqlite3",
                arguments: arguments,
                timeout: boundedTimeout
            )

            if result.didTimeOut {
                return .failure(.timeout(duration: boundedTimeout))
            }

            if let status = result.terminationStatus, status != 0 {
                let stderr = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
                let msg = stderr.isEmpty ? "Process exited with status code \(status)" : stderr
                return .failure(.queryExecutionFailed(reason: msg))
            }

            if !result.succeeded {
                let err = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
                return .failure(.queryExecutionFailed(reason: err.isEmpty ? "Unknown execution failure" : err))
            }

            return .success(result.standardOutput)
        }
    }

    private func scanSQLiteFiles() -> [LocalSQLiteFile] {
        var results: [LocalSQLiteFile] = []
        let home = NSHomeDirectory()
        let locations = [
            home + "/Library/Application Support",
            home + "/Desktop/Projects"
        ]

        let fm = FileManager.default
        for folder in locations {
            let expanded = (folder as NSString).expandingTildeInPath
            guard !expanded.contains(".."), fm.fileExists(atPath: expanded) else { continue }

            if let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: expanded),
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) {
                var count = 0
                for case let fileURL as URL in enumerator {
                    if count >= 15 { break }
                    let ext = fileURL.pathExtension.lowercased()
                    if ext == "sqlite" || ext == "sqlite3" || ext == "db" {
                        let path = fileURL.path
                        if path.contains("..") { continue }

                        if let values = try? fileURL.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey]),
                           values.isSymbolicLink != true,
                           let sizeBytes = values.fileSize {
                            let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
                            let name = fileURL.lastPathComponent
                            results.append(LocalSQLiteFile(name: name, path: path, size: sizeStr))
                            count += 1
                        }
                    }
                }
            }
        }
        return results
    }
}

