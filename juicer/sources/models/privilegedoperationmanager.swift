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
                return true
            } catch {
                daemonStatus = .failed(error.localizedDescription)
                return false
            }
        } else {
            return false
        }
    }

    // MARK: - Privileged Actions
    public func executeHostsFileUpdate(content: String) async -> (Bool, String) {
        // First try native AppleScript authorization for Hosts File atomic write
        let backupPath = ("/etc/hosts.juicer." + String(Int(Date().timeIntervalSince1970)) + ".bak")
        let tempFile = NSTemporaryDirectory() + "juicer_hosts_\(UUID().uuidString).txt"

        do {
            try content.write(toFile: tempFile, atomically: true, encoding: .utf8)
            let script = """
            do shell script "cp /etc/hosts \(backupPath) 2>/dev/null || true; cp \(tempFile) /etc/hosts && chmod 644 /etc/hosts" with administrator privileges
            """

            var errorDict: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                let result = appleScript.executeAndReturnError(&errorDict)
                try? FileManager.default.removeItem(atPath: tempFile)

                if let err = errorDict {
                    let errMsg = err[NSAppleScript.errorMessage] as? String ?? "Authorization failed"
                    return (false, "Hosts file write cancelled or failed: \(errMsg)")
                }
                return (true, "Successfully updated /etc/hosts (Backup created at \(backupPath))")
            }
        } catch {
            return (false, "Failed to prepare hosts configuration: \(error.localizedDescription)")
        }
        return (false, "Unable to execute AppleScript engine")
    }

    public func executeTerminateProcess(pid: Int32) async -> (Bool, String) {
        if pid <= 1 {
            return (false, "System process PID \(pid) is protected and cannot be terminated.")
        }
        let result = kill(pid, SIGTERM)
        if result == 0 {
            return (true, "Terminated process PID \(pid)")
        } else {
            // Attempt elevated termination via AppleScript
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
        let fm = FileManager.default
        guard fm.fileExists(atPath: targetPath) else {
            return (false, "Target cache path does not exist: \(targetPath)")
        }

        // Restrict purging to cache directories
        let allowed = targetPath.contains("/Caches/") || targetPath.contains("/Cache/") || targetPath.contains("/tmp/")
        guard allowed else {
            return (false, "Path '\(targetPath)' is outside safe cache purge scope.")
        }

        do {
            try fm.removeItem(atPath: targetPath)
            return (true, "Purged cache target at \(targetPath)")
        } catch {
            let script = "do shell script \"rm -rf '\(targetPath)'\" with administrator privileges"
            var errorDict: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&errorDict)
                if errorDict == nil {
                    return (true, "Purged cache target with elevated privileges at \(targetPath)")
                }
            }
            return (false, "Failed to purge cache target: \(error.localizedDescription)")
        }
    }
}
