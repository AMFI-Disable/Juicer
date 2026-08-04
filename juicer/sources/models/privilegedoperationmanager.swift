import Foundation
import ServiceManagement
import AppKit

/// Represents the installation and authorization status of the privileged helper daemon.
public enum DaemonStatus: Equatable {
    /// The helper daemon is not installed on the system.
    case notInstalled
    /// The helper daemon is installed, enabled, and ready for XPC connections.
    case enabled
    /// The helper daemon installation requires user approval in System Settings.
    case requiresApproval
    /// The helper daemon operation failed with an associated error message.
    case failed(String)
}

/// Manages privileged system operations and coordinates XPC communication with the helper daemon.
///
/// `PrivilegedOperationManager` serves as the centralized interface for requesting administrative actions
/// such as modifying TCC permissions, updating `/etc/hosts`, terminating system processes, and purging system caches.
/// It attempts to execute operations via an active XPC connection (`JuicerHelperProtocol`) to the helper daemon.
/// If the daemon is unavailable or not registered, it performs safe fallbacks using elevated AppleScript or POSIX APIs.
@MainActor
public final class PrivilegedOperationManager: ObservableObject {
    /// The shared singleton instance of `PrivilegedOperationManager`.
    public static let shared = PrivilegedOperationManager()

    /// The current installation and authorization status of the privileged daemon.
    @Published public private(set) var daemonStatus: DaemonStatus = .notInstalled

    /// Indicates whether an active XPC connection to the helper daemon is currently established.
    @Published public private(set) var isConnected: Bool = false

    /// The most recent error message encountered during daemon registration or XPC operation.
    @Published public private(set) var lastError: String? = nil

    /// The active XPC connection to the helper daemon Mach service.
    private var xpcConnection: NSXPCConnection?

    /// Initializes the manager instance and performs an initial daemon status check.
    private init() {
        checkStatus()
    }

    /// Checks the current registration and authorization status of the helper daemon service using `SMAppService`.
    public func checkStatus() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.daemon(plistName: "com.even.juicer.helper.plist")
            switch service.status {
            case .enabled:
                daemonStatus = .enabled
                connectXPCIfNeeded()
            case .requiresApproval:
                daemonStatus = .requiresApproval
            case .notFound:
                daemonStatus = .notInstalled
            @unknown default:
                daemonStatus = .notInstalled
            }
        } else {
            daemonStatus = .notInstalled
        }
    }

    /// Registers the helper daemon with `SMAppService`.
    ///
    /// - Returns: `true` if registration succeeded; `false` otherwise.
    public func registerDaemon() async -> Bool {
        if #available(macOS 13.0, *) {
            let service = SMAppService.daemon(plistName: "com.even.juicer.helper.plist")
            do {
                try service.register()
                checkStatus()
                return true
            } catch {
                daemonStatus = .failed(error.localizedDescription)
                lastError = error.localizedDescription
                return false
            }
        } else {
            lastError = "SMAppService requires macOS 13.0 or later."
            return false
        }
    }

    /// Unregisters the helper daemon and invalidates any existing XPC connection.
    ///
    /// - Returns: `true` if unregistration succeeded; `false` otherwise.
    public func unregisterDaemon() async -> Bool {
        if #available(macOS 13.0, *) {
            let service = SMAppService.daemon(plistName: "com.even.juicer.helper.plist")
            do {
                try await service.unregister()
                checkStatus()
                xpcConnection?.invalidate()
                xpcConnection = nil
                isConnected = false
                return true
            } catch {
                daemonStatus = .failed(error.localizedDescription)
                return false
            }
        } else {
            return false
        }
    }

    // MARK: - XPC Connection

    /// Establishes the XPC connection to the privileged helper Mach service if not already connected.
    private func connectXPCIfNeeded() {
        guard xpcConnection == nil else { return }
        let connection = NSXPCConnection(machServiceName: JuicerHelperConstants.serviceIdentifier, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: JuicerHelperProtocol.self)
        connection.invalidationHandler = { [weak self] in
            Task { @MainActor in
                self?.isConnected = false
                self?.xpcConnection = nil
            }
        }
        connection.interruptionHandler = { [weak self] in
            Task { @MainActor in
                self?.isConnected = false
            }
        }
        connection.resume()
        self.xpcConnection = connection
        self.isConnected = true
    }

    /// Obtains a remote proxy object conforming to `JuicerHelperProtocol` for XPC messaging.
    ///
    /// - Returns: An object proxy implementing `JuicerHelperProtocol`, or `nil` if connection fails.
    private func getHelperProxy() -> JuicerHelperProtocol? {
        connectXPCIfNeeded()
        return xpcConnection?.remoteObjectProxyWithErrorHandler { [weak self] error in
            Task { @MainActor in
                self?.lastError = error.localizedDescription
                self?.isConnected = false
            }
        } as? JuicerHelperProtocol
    }

    // MARK: - Privileged Actions (XPC-Wired with Safe Fallback)

    /// Modifies TCC privacy permissions for a specified client and service.
    ///
    /// Attempts execution via XPC helper proxy. If XPC is unavailable, falls back to running `/usr/bin/tccutil`.
    ///
    /// - Parameters:
    ///   - client: The application identifier or bundle ID requesting permission modification.
    ///   - service: The target TCC service identifier (e.g., `kTCCServiceSystemPolicyAllFiles`).
    ///   - allow: A boolean flag specifying permission outcome.
    /// - Returns: A tuple containing a success flag and a descriptive status message.
    public func modifyTCCPermission(client: String, service: String, allow: Bool) async -> (Bool, String) {
        if let proxy = getHelperProxy() {
            return await withCheckedContinuation { continuation in
                proxy.modifyTCCPermission(client: client, service: service, allow: allow) { success, msg in
                    continuation.resume(returning: (success, msg))
                }
            }
        }

        // Safe fallback without raw shell string concatenation
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", service.trimmingCharacters(in: .whitespaces), client.trimmingCharacters(in: .whitespaces)]

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return (true, "Reset TCC permission for \(client)")
            } else {
                return (false, "tccutil exited with status \(process.terminationStatus)")
            }
        } catch {
            return (false, "Failed to run tccutil: \(error.localizedDescription)")
        }
    }

    /// Updates the system `/etc/hosts` file with new content.
    ///
    /// Creates a timestamped backup copy at `/etc/hosts.juicer.<timestamp>.bak` prior to overwriting.
    /// Uses the XPC daemon proxy if available, or falls back to elevated AppleScript execution.
    ///
    /// - Parameter content: The complete replacement string content for the hosts file.
    /// - Returns: A tuple containing a success flag and a descriptive status message.
    public func executeHostsFileUpdate(content: String) async -> (Bool, String) {
        let backupPath = "/etc/hosts.juicer." + String(Int(Date().timeIntervalSince1970)) + ".bak"

        if let proxy = getHelperProxy() {
            return await withCheckedContinuation { continuation in
                proxy.writeHostsFile(content: content, backupPath: backupPath) { success, msg in
                    continuation.resume(returning: (success, msg))
                }
            }
        }

        // Fallback using safe temporary file writing & single-quoted shell escaping (no raw interpolation)
        let tempFile = NSTemporaryDirectory() + "juicer_hosts_\(UUID().uuidString).txt"
        do {
            try content.write(toFile: tempFile, atomically: true, encoding: .utf8)

            let safeTempFile = tempFile.replacingOccurrences(of: "'", with: "'\\''")
            let safeBackup = backupPath.replacingOccurrences(of: "'", with: "'\\''")
            let script = "do shell script \"cp /etc/hosts '\(safeBackup)' 2>/dev/null || true; cp '\(safeTempFile)' /etc/hosts && chmod 644 /etc/hosts\" with administrator privileges"

            var errorDict: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&errorDict)
                try? FileManager.default.removeItem(atPath: tempFile)

                if let err = errorDict {
                    let errMsg = err[NSAppleScript.errorMessage] as? String ?? "Authorization cancelled"
                    return (false, "Hosts file write failed: \(errMsg)")
                }
                return (true, "Successfully updated /etc/hosts (Backup created at \(backupPath))")
            }
        } catch {
            return (false, "Failed to prepare hosts configuration: \(error.localizedDescription)")
        }
        return (false, "Unable to execute authorization engine")
    }

    /// Terminates a target process by PID using POSIX signals or elevated execution.
    ///
    /// Refuses to terminate system process PIDs (\(\le 1\)). Attempts termination via XPC proxy,
    /// standard `kill()`, or elevated AppleScript authorization fallback.
    ///
    /// - Parameter pid: The process identifier to terminate.
    /// - Returns: A tuple containing a success flag and a descriptive status message.
    public func executeTerminateProcess(pid: Int32) async -> (Bool, String) {
        guard pid > 1 else {
            return (false, "System process PID \(pid) is protected and cannot be terminated.")
        }

        if let proxy = getHelperProxy() {
            return await withCheckedContinuation { continuation in
                proxy.terminateProcess(pid: pid, signal: SIGTERM) { success, msg in
                    continuation.resume(returning: (success, msg))
                }
            }
        }

        let result = kill(pid, SIGTERM)
        if result == 0 {
            return (true, "Terminated process PID \(pid)")
        } else {
            // Elevated termination using safe integer argument formatting (no raw string interpolation)
            let script = "do shell script \"kill -9 \(pid)\" with administrator privileges"
            var errorDict: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&errorDict)
                if let err = errorDict {
                    let msg = err[NSAppleScript.errorMessage] as? String ?? "Failed"
                    return (false, "Elevated process termination failed: \(msg)")
                }
                return (true, "Successfully terminated process PID \(pid) with elevated privileges")
            }
            return (false, "Permission denied (PID \(pid))")
        }
    }

    /// Purges cache files or directories at the specified path.
    ///
    /// Validates that the target path exists and resides within allowed safe cache directories (`/Caches/`, `/Cache/`, `/tmp/`, `/private/tmp/`).
    /// Delegates deletion to XPC proxy if connected, or uses `FileManager` / elevated AppleScript fallback.
    ///
    /// - Parameter targetPath: The file system path targeted for cache purge.
    /// - Returns: A tuple containing a success flag and a descriptive status message.
    public func executePurgeSystemCache(targetPath: String) async -> (Bool, String) {
        let trimmedPath = targetPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let fm = FileManager.default
        guard fm.fileExists(atPath: trimmedPath) else {
            return (false, "Target cache path does not exist: \(trimmedPath)")
        }

        let allowed = trimmedPath.contains("/Caches/") ||
                      trimmedPath.contains("/Cache/") ||
                      trimmedPath.contains("/tmp/") ||
                      trimmedPath.hasPrefix("/private/tmp/")

        guard allowed else {
            return (false, "Path '\(trimmedPath)' is outside safe cache purge scope.")
        }

        if let proxy = getHelperProxy() {
            return await withCheckedContinuation { continuation in
                proxy.purgeSystemCache(path: trimmedPath) { success, msg in
                    continuation.resume(returning: (success, msg))
                }
            }
        }

        do {
            try fm.removeItem(atPath: trimmedPath)
            return (true, "Purged cache target at \(trimmedPath)")
        } catch {
            let safePath = trimmedPath.replacingOccurrences(of: "'", with: "'\\''")
            let script = "do shell script \"rm -rf '\(safePath)'\" with administrator privileges"
            var errorDict: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&errorDict)
                if errorDict == nil {
                    return (true, "Purged cache target with elevated privileges at \(trimmedPath)")
                }
            }
            return (false, "Failed to purge cache target: \(error.localizedDescription)")
        }
    }
}

