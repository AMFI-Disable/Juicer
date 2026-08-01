import Foundation

enum SystemMetricsSupport {
    /// Runs a system utility without allowing a stalled command to hang the app forever.
    ///
    /// A number of macOS utilities can wait on permission prompts, unavailable
    /// services, or network timeouts. Keep this synchronous API for existing
    /// callers while delegating execution, capture, and timeout handling to
    /// the shared command executor.
    static func run(_ path: String, _ arguments: [String] = [], timeout: TimeInterval = 30) -> String? {
        let result = CommandExecutor.shared.run(executablePath: path, arguments: arguments, timeout: timeout)
        return result.succeeded ? result.standardOutput : nil
    }

    /// Runs a command with stdout and stderr returned together, with the same
    /// timeout guarantees as `run`. This is useful for terminal-like features.
    static func runCombined(
        _ path: String,
        _ arguments: [String] = [],
        currentDirectoryURL: URL? = nil,
        timeout: TimeInterval = 30
    ) -> String? {
        let result = CommandExecutor.shared.run(
            executablePath: path,
            arguments: arguments,
            currentDirectoryURL: currentDirectoryURL,
            timeout: timeout
        )
        guard result.succeeded else { return nil }
        return result.standardOutput + result.standardError
    }
    static func bytes(_ value: UInt64) -> String { ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .binary) }
    static func formatBytes(_ value: UInt64) -> String { bytes(value) }
    static func percent(_ value: Double) -> String { String(format: "%.1f%%", value) }
    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
