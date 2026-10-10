import Foundation

enum StudioSecretRedactor {
    private static let patterns = [
        #"(?i)(authorization\s*:\s*bearer\s+)[^\s,]+"#,
        #"(?i)(api[_-]?key\s*[=:]\s*)[^\s,]+"#,
        #"(?i)(password|passwd|secret|token|private[_-]?key)\s*[=:]\s*[^\s,]+"#,
        #"AKIA[0-9A-Z]{16}"#
    ]

    static func redact(_ value: String) -> String {
        patterns.reduce(value) { result, pattern in
            result.replacingOccurrences(of: pattern, with: "$1[REDACTED]", options: .regularExpression)
        }
    }
}

struct StudioURLError: Error, LocalizedError, CustomStringConvertible, Equatable {
    let message: String
    var description: String { message }
    var errorDescription: String? { message }
}

enum StudioURLPolicy {
    static func validate(_ raw: String, allowExternal: Bool = true) -> Result<URL, StudioURLError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host != nil else { return .failure(StudioURLError(message: "Enter a valid HTTP or HTTPS URL.")) }
        if !allowExternal, let host = url.host, !["localhost", "127.0.0.1", "::1"].contains(host) { return .failure(StudioURLError(message: "External network destinations are disabled for this operation.")) }
        return .success(url)
    }
}

struct RuntimeDetection: Equatable { let name: String; let executable: String; let detected: Bool; let version: String?; let message: String }
enum RuntimeDetector {
    static func result(name: String, executable: String, version: String?) -> RuntimeDetection {
        RuntimeDetection(name: name, executable: executable, detected: version != nil, version: version, message: version == nil ? "Not installed or not detected" : "Detected (version!)")
    }
}

struct ScriptExecutionPolicy: Equatable {
    let path: String
    let interpreter: String
    let timeout: TimeInterval
    let outputLimit: Int
    let requiresConfirmation: Bool
}

enum DockerSafetyPolicy {
    static func canPurge(isDaemonRunning: Bool, hasPreview: Bool) -> Bool { isDaemonRunning && hasPreview }
}

enum SQLiteSafetyPolicy {
    static let maxRows = 10_000
    static let maxBytes = 50 * 1024 * 1024
    static func isReadOnly(_ query: String) -> Bool {
        query.range(of: #"(?i)\b(insert|update|delete|drop|alter|create|replace|vacuum)\b"#, options: .regularExpression) == nil
    }
}
