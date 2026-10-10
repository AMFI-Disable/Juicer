import Foundation

enum ReliabilityOperationState: String, Codable, Equatable {
    case idle
    case running
    case succeeded
    case partiallySucceeded
    case failed
    case timedOut
    case cancelled
}

struct ReliabilityProgress: Codable, Equatable {
    var completed: Int
    var total: Int
    var message: String

    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(completed) / Double(total)))
    }
}

struct ReliabilityOperationSnapshot: Codable, Equatable {
    let id: UUID
    var state: ReliabilityOperationState
    var progress: ReliabilityProgress
    var errorMessage: String?
    var startedAt: Date?
    var finishedAt: Date?
    var lastUpdatedAt: Date?
}

/// Deterministic state machine shared by long-running UI operations.
struct ReliabilityOperation {
    private(set) var snapshot: ReliabilityOperationSnapshot

    init(id: UUID = UUID(), total: Int = 0, message: String = "Ready") {
        snapshot = ReliabilityOperationSnapshot(
            id: id,
            state: .idle,
            progress: ReliabilityProgress(completed: 0, total: max(0, total), message: message),
            errorMessage: nil,
            startedAt: nil,
            finishedAt: nil,
            lastUpdatedAt: nil
        )
    }

    var isActive: Bool { snapshot.state == .running }

    mutating func start(message: String? = nil, at date: Date = Date()) -> Bool {
        guard !isActive else { return false }
        snapshot = ReliabilityOperationSnapshot(
            id: UUID(),
            state: .running,
            progress: ReliabilityProgress(completed: 0, total: snapshot.progress.total, message: message ?? snapshot.progress.message),
            errorMessage: nil,
            startedAt: date,
            finishedAt: nil,
            lastUpdatedAt: date
        )
        return true
    }

    mutating func update(completed: Int, message: String, at date: Date = Date()) {
        guard isActive else { return }
        snapshot.progress.completed = min(snapshot.progress.total, max(snapshot.progress.completed, completed))
        snapshot.progress.message = message
        snapshot.lastUpdatedAt = date
    }

    mutating func succeed(message: String = "Completed", at date: Date = Date()) {
        guard isActive else { return }
        snapshot.progress.completed = snapshot.progress.total
        snapshot.progress.message = message
        snapshot.state = .succeeded
        snapshot.finishedAt = date
        snapshot.lastUpdatedAt = date
    }

    mutating func finish(partial: Bool, message: String, at date: Date = Date()) {
        guard isActive else { return }
        snapshot.state = partial ? .partiallySucceeded : .succeeded
        snapshot.progress.message = message
        snapshot.finishedAt = date
        snapshot.lastUpdatedAt = date
    }

    mutating func fail(_ message: String, at date: Date = Date()) {
        guard isActive else { return }
        snapshot.state = .failed
        snapshot.errorMessage = message
        snapshot.progress.message = message
        snapshot.finishedAt = date
        snapshot.lastUpdatedAt = date
    }

    mutating func timeOut(_ message: String = "The operation timed out.", at date: Date = Date()) {
        guard isActive else { return }
        snapshot.state = .timedOut
        snapshot.errorMessage = message
        snapshot.progress.message = message
        snapshot.finishedAt = date
        snapshot.lastUpdatedAt = date
    }

    mutating func cancel(_ message: String = "The operation was cancelled.", at date: Date = Date()) {
        guard isActive else { return }
        snapshot.state = .cancelled
        snapshot.errorMessage = message
        snapshot.progress.message = message
        snapshot.finishedAt = date
        snapshot.lastUpdatedAt = date
    }
}

enum PackageManagementSource: String, Codable, Equatable {
    case homebrew
    case external
    case available
    case unknown
}

enum PackageLifecycleState: String, Codable, Equatable {
    case installed
    case external
    case available
    case updating
    case failed
    case unknown
}

struct PackageStatusMapping: Codable, Equatable {
    let source: PackageManagementSource
    let state: PackageLifecycleState

    static func resolve(isInstalled: Bool, isHomebrewManaged: Bool, isUpdating: Bool = false, failed: Bool = false) -> Self {
        if failed { return .init(source: isHomebrewManaged ? .homebrew : .unknown, state: .failed) }
        if isUpdating { return .init(source: isHomebrewManaged ? .homebrew : .unknown, state: .updating) }
        if isHomebrewManaged && isInstalled { return .init(source: .homebrew, state: .installed) }
        if isInstalled { return .init(source: .external, state: .external) }
        return .init(source: .available, state: .available)
    }
}

struct FormulaUpdateRecord: Codable, Equatable {
    let name: String
    let installedVersion: String?
    let latestVersion: String?

    var hasUpdate: Bool { installedVersion != nil && latestVersion != nil && installedVersion != latestVersion }
}

enum FormulaUpdateParser {
    static func parse(json data: Data) -> [FormulaUpdateRecord] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        return ([("formulae", false), ("casks", true)] as [(String, Bool)]).flatMap { key, _ in
            (root[key] as? [[String: Any]] ?? []).compactMap { item in
                guard let name = item["name"] as? String else { return nil }
                let latest = (item["current_version"] as? String) ?? (item["version"] as? String)
                let installed = (item["installed_versions"] as? [String])?.first ?? (item["installed_version"] as? String)
                return FormulaUpdateRecord(name: name, installedVersion: installed, latestVersion: latest)
            }
        }
    }
}

struct ParsedServiceStatus: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let status: String
    let user: String?
    let path: String?
    let rawStatusCode: Int?
}

enum ServiceStatusParser {
    static func parseLaunchctlList(_ output: String) -> [ParsedServiceStatus] {
        output.split(separator: "\n").dropFirst().compactMap { line in
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count >= 3 else { return nil }
            let pid = Int(parts[0])
            let code = Int(parts[1])
            let label = String(parts[2])
            let status: String
            if pid != nil { status = "Running" } else if code == -9 { status = "Killed (-9)" } else if code == -1 { status = "Failed (-1)" } else if code == 78 { status = "Configuration error (78)" } else { status = "Stopped" }
            return ParsedServiceStatus(id: label, name: label, status: status, user: nil, path: nil, rawStatusCode: code)
        }
    }
}

enum ProtectedProcessPolicy {
    static let protectedNames: Set<String> = ["launchd", "kernel_task", "WindowServer", "loginwindow", "systemuiserver", "Dock"]

    static func isProtected(pid: Int, name: String) -> Bool {
        pid <= 1 || protectedNames.contains(name) || name.hasPrefix("kernel_")
    }
}
