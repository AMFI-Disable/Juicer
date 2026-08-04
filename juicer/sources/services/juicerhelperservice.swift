import Foundation

public final class JuicerHelperService: NSObject, JuicerHelperProtocol {
    public override init() {
        super.init()
    }

    public func checkDaemonVersion(reply: @escaping (String) -> Void) {
        reply(JuicerHelperConstants.version)
    }

    public func modifyTCCPermission(client: String, service: String, allow: Bool, reply: @escaping (Bool, String) -> Void) {
        let trimmedClient = client.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedService = service.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedClient.isEmpty, !trimmedService.isEmpty else {
            reply(false, "Invalid client or service parameters.")
            return
        }

        // Execute tccutil safely via Process arguments without shell interpolation
        let action = allow ? "reset" : "reset"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = [action, trimmedService, trimmedClient]

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                reply(true, "Successfully modified TCC permission for \(trimmedClient)")
            } else {
                reply(false, "tccutil returned status code \(process.terminationStatus)")
            }
        } catch {
            reply(false, "Failed to execute tccutil: \(error.localizedDescription)")
        }
    }

    public func writeHostsFile(content: String, backupPath: String, reply: @escaping (Bool, String) -> Void) {
        let hostsPath = "/etc/hosts"
        let fm = FileManager.default

        // Create atomic backup copy if current hosts file exists
        if fm.fileExists(atPath: hostsPath) {
            let backupTarget = backupPath.isEmpty ? "/etc/hosts.juicer.\(Int(Date().timeIntervalSince1970)).bak" : backupPath
            try? fm.removeItem(atPath: backupTarget)
            do {
                try fm.copyItem(atPath: hostsPath, toPath: backupTarget)
            } catch {
                reply(false, "Failed to create backup at '\(backupTarget)': \(error.localizedDescription)")
                return
            }
        }

        // Perform atomic write by creating temporary file and moving into position
        let tempPath = "/etc/hosts.juicer.tmp.\(UUID().uuidString)"
        do {
            try content.write(toFile: tempPath, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: tempPath)
            _ = try fm.replaceItemAt(URL(fileURLWithPath: hostsPath), withItemAt: URL(fileURLWithPath: tempPath))
            reply(true, "Successfully updated /etc/hosts with atomic backup.")
        } catch {
            try? fm.removeItem(atPath: tempPath)
            reply(false, "Failed to update /etc/hosts: \(error.localizedDescription)")
        }
    }

    public func terminateProcess(pid: Int32, signal: Int32, reply: @escaping (Bool, String) -> Void) {
        guard pid > 1 else {
            reply(false, "Process ID \(pid) is protected and cannot be terminated.")
            return
        }

        let result = kill(pid, signal)
        if result == 0 {
            reply(true, "Successfully terminated process PID \(pid)")
        } else {
            let errStr = String(cString: strerror(errno))
            reply(false, "Failed to terminate process PID \(pid): \(errStr)")
        }
    }

    public func purgeSystemCache(path: String, reply: @escaping (Bool, String) -> Void) {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let fm = FileManager.default

        guard fm.fileExists(atPath: trimmedPath) else {
            reply(false, "Target path does not exist: \(trimmedPath)")
            return
        }

        // Safety verification: restrict purge scope to cache & temporary directories
        let isAllowedScope = trimmedPath.contains("/Caches/") ||
                            trimmedPath.contains("/Cache/") ||
                            trimmedPath.contains("/tmp/") ||
                            trimmedPath.hasPrefix("/private/tmp/")

        guard isAllowedScope else {
            reply(false, "Path '\(trimmedPath)' is outside allowed cache purge boundaries.")
            return
        }

        do {
            try fm.removeItem(atPath: trimmedPath)
            reply(true, "Successfully purged cache path: \(trimmedPath)")
        } catch {
            reply(false, "Failed to purge cache path: \(error.localizedDescription)")
        }
    }
}
