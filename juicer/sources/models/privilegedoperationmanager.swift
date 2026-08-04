import Foundation
import ServiceManagement
import AppKit

public enum DaemonStatus: Equatable {
    case notInstalled
    case enabled
    case requiresApproval
    case failed(String)
}

@MainActor
public final class PrivilegedOperationManager: ObservableObject {
    public static let shared = PrivilegedOperationManager()

    @Published public private(set) var daemonStatus: DaemonStatus = .notInstalled
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var lastError: String? = nil

    private var xpcConnection: NSXPCConnection?

    private init() {
        checkStatus()
    }

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
