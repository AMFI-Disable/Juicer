import Foundation
import Combine
import UniformTypeIdentifiers

public enum EnvPathValidationError: LocalizedError, Equatable {
    case emptyPath
    case invalidPath(String)
    case relativePathNotAllowed(String)
    case nullByteInPath
    case systemPathForbidden(String)
    case fileNotFound(String)
    case fileTooLarge(String)

    public var errorDescription: String? {
        switch self {
        case .emptyPath:
            return "Path cannot be empty."
        case .invalidPath(let p):
            return "Invalid path format: \(p)"
        case .relativePathNotAllowed(let p):
            return "Relative paths are not allowed: \(p)"
        case .nullByteInPath:
            return "Path contains invalid null characters."
        case .systemPathForbidden(let p):
            return "Access to system directory is forbidden: \(p)"
        case .fileNotFound(let p):
            return "File not found at path: \(p)"
        case .fileTooLarge(let p):
            return "File exceeds maximum allowed size (2 MB): \(p)"
        }
    }
}

struct EnvVariable: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var key: String
    var value: String
    var isSecret: Bool

    init(id: UUID = UUID(), key: String, value: String, isSecret: Bool? = nil) {
        self.id = id
        self.key = key
        self.value = value
        if let isSecret = isSecret {
            self.isSecret = isSecret
        } else {
            // Auto-detect secret based on key name patterns
            let k = key.uppercased()
            self.isSecret = k.contains("SECRET") || k.contains("KEY") || k.contains("PASSWORD") ||
                            k.contains("TOKEN") || k.contains("AUTH") || k.contains("PRIVATE") ||
                            k.contains("CREDENTIAL") || k.contains("DATABASE_URL")
        }
    }
}

struct EnvProfile: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var projectPath: String
    var variables: [EnvVariable]
    var updatedAt: Date
}

class EnvProfileManager: ObservableObject {
    @Published var profiles: [EnvProfile] = []
    @Published var selectedProfileID: UUID?

    private let storageKey = "juicer.envprofiles.data"

    static let maxEnvFileLength = 500_000
    static let maxEnvLineCount = 5000
    static let maxKeyLength = 256
    static let maxValueLength = 16_384

    private var storageFileURL: URL? {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent("Juicer", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("env_profiles.json")
    }

    init() {
        loadProfiles()
        if profiles.isEmpty {
            createSampleProfiles()
        }
    }

    // MARK: - Path Validation

    static func normalizeAndValidatePath(_ rawPath: String, mustExist: Bool = false) -> Result<URL, EnvPathValidationError> {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyPath) }
        guard !trimmed.contains("\0") else { return .failure(.nullByteInPath) }

        let expanded = (trimmed as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded).standardizedFileURL

        guard url.isFileURL else { return .failure(.invalidPath(rawPath)) }

        let path = url.path
        guard path.hasPrefix("/") else {
            return .failure(.relativePathNotAllowed(rawPath))
        }

        // Protect system root and core directories from accidental overwrites
        let forbiddenPaths = ["/", "/System", "/usr", "/usr/bin", "/usr/sbin", "/bin", "/sbin", "/etc", "/var", "/Library"]
        if forbiddenPaths.contains(path) {
            return .failure(.systemPathForbidden(path))
        }

        if mustExist {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else {
                return .failure(.fileNotFound(path))
            }
        }

        return .success(url)
    }

    // MARK: - Persistence & Atomic Saving

    func loadProfiles() {
        if let fileURL = storageFileURL,
           let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([EnvProfile].self, from: data) {
            self.profiles = decoded
            return
        }

        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([EnvProfile].self, from: data) {
            self.profiles = decoded
        }
    }

    func saveProfiles() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)

        if let fileURL = storageFileURL {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func addProfile(name: String, projectPath: String = "", variables: [EnvVariable] = []) {
        let sanitizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = sanitizedName.isEmpty ? "New Profile" : sanitizedName
        var cleanPath = ""
        if case .success(let url) = Self.normalizeAndValidatePath(projectPath) {
            cleanPath = url.path
        } else if !projectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cleanPath = (projectPath as NSString).expandingTildeInPath
        }

        let newProfile = EnvProfile(
            name: finalName,
            projectPath: cleanPath,
            variables: variables,
            updatedAt: Date()
        )
        profiles.append(newProfile)
        selectedProfileID = newProfile.id
        saveProfiles()
    }

    func updateProfile(_ profile: EnvProfile) {
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            var updated = profile
            updated.updatedAt = Date()
            profiles[idx] = updated
            saveProfiles()
        }
    }

    func deleteProfile(id: UUID) {
        profiles.removeAll { $0.id == id }
        if selectedProfileID == id {
            selectedProfileID = profiles.first?.id
        }
        saveProfiles()
    }

    // MARK: - Export & Import Operations

    func exportAsEnvString(profile: EnvProfile) -> String {
        profile.variables.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
    }

    func exportAsShellExport(profile: EnvProfile) -> String {
        profile.variables.map { "export \($0.key)=\"\($0.value)\"" }.joined(separator: "\n")
    }

    func exportProfileToEnvFile(profile: EnvProfile, to targetPath: String) throws {
        switch Self.normalizeAndValidatePath(targetPath) {
        case .failure(let error):
            throw error
        case .success(let url):
            let content = exportAsEnvString(profile: profile)
            guard let data = content.data(using: .utf8) else {
                throw EnvPathValidationError.invalidPath(targetPath)
            }
            let parentDir = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        }
    }

    func importProfileFromEnvFile(at sourcePath: String, name: String = "") throws -> EnvProfile {
        switch Self.normalizeAndValidatePath(sourcePath, mustExist: true) {
        case .failure(let error):
            throw error
        case .success(let url):
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attrs[.size] as? UInt64, size > 2_000_000 {
                throw EnvPathValidationError.fileTooLarge(sourcePath)
            }
            let content = try String(contentsOf: url, encoding: .utf8)
            let vars = parseEnvFile(content: content)
            let profileName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? url.deletingPathExtension().lastPathComponent
                : name.trimmingCharacters(in: .whitespacesAndNewlines)

            let profile = EnvProfile(
                name: profileName,
                projectPath: url.deletingLastPathComponent().path,
                variables: vars,
                updatedAt: Date()
            )
            profiles.append(profile)
            selectedProfileID = profile.id
            saveProfiles()
            return profile
        }
    }

    // MARK: - Key-Value Parsing

    func parseEnvFile(content: String) -> [EnvVariable] {
        guard content.count <= Self.maxEnvFileLength else { return [] }

        var result: [EnvVariable] = []
        let lines = content.components(separatedBy: .newlines)
        let cappedLines = Array(lines.prefix(Self.maxEnvLineCount))

        for line in cappedLines {
            var trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("//") {
                continue
            }

            if trimmed.hasPrefix("export ") {
                trimmed = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("export\t") {
                trimmed = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            }

            guard let equalsIndex = trimmed.firstIndex(of: "=") else {
                continue
            }

            let rawKey = String(trimmed[..<equalsIndex]).trimmingCharacters(in: .whitespaces)
            var rawValue = String(trimmed[trimmed.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)

            guard !rawKey.isEmpty, rawKey.count <= Self.maxKeyLength else { continue }
            let validKeyChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_.-"))
            guard rawKey.unicodeScalars.allSatisfy({ validKeyChars.contains($0) }) else { continue }

            if !rawValue.hasPrefix("\"") && !rawValue.hasPrefix("'") {
                if let commentIndex = rawValue.firstIndex(of: "#") {
                    rawValue = String(rawValue[..<commentIndex]).trimmingCharacters(in: .whitespaces)
                }
            }

            if (rawValue.hasPrefix("\"") && rawValue.hasSuffix("\"") && rawValue.count >= 2) ||
               (rawValue.hasPrefix("'") && rawValue.hasSuffix("'") && rawValue.count >= 2) {
                let start = rawValue.index(after: rawValue.startIndex)
                let end = rawValue.index(before: rawValue.endIndex)
                rawValue = String(rawValue[start..<end])
                rawValue = rawValue
                    .replacingOccurrences(of: "\\n", with: "\n")
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\'", with: "'")
                    .replacingOccurrences(of: "\\\\", with: "\\")
            }

            guard rawValue.count <= Self.maxValueLength else { continue }

            result.append(EnvVariable(key: rawKey, value: rawValue))
        }
        return result
    }

    private func createSampleProfiles() {
        let devVars = [
            EnvVariable(key: "PORT", value: "3000"),
            EnvVariable(key: "NODE_ENV", value: "development"),
            EnvVariable(key: "DATABASE_URL", value: "postgres://localhost:5432/dev_db"),
            EnvVariable(key: "API_SECRET_KEY", value: "sk_dev_9876543210123456789"),
            EnvVariable(key: "JWT_SECRET", value: "super-secret-dev-jwt-token")
        ]

        let prodVars = [
            EnvVariable(key: "PORT", value: "8080"),
            EnvVariable(key: "NODE_ENV", value: "production"),
            EnvVariable(key: "DATABASE_URL", value: "postgres://prod-db.internal:5432/main"),
            EnvVariable(key: "AWS_ACCESS_KEY_ID", value: "AKIAIOSFODNN7EXAMPLE"),
            EnvVariable(key: "AWS_SECRET_ACCESS_KEY", value: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY")
        ]

        profiles = [
            EnvProfile(name: "Development Local", projectPath: "~/Projects/MyApp", variables: devVars, updatedAt: Date()),
            EnvProfile(name: "Production Staging", projectPath: "~/Projects/MyApp", variables: prodVars, updatedAt: Date())
        ]
        selectedProfileID = profiles.first?.id
        saveProfiles()
    }
}

