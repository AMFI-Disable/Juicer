import Foundation
import AppKit

struct TCCPermissionItem: Identifiable, Codable {
    let id: String
    let client: String
    let appName: String
    let service: String
    let isAllowed: Bool
    let lastModified: Date
    let isSampleData: Bool

    init(id: String = UUID().uuidString, client: String, appName: String, service: String, isAllowed: Bool, lastModified: Date, isSampleData: Bool = false) {
        self.id = id
        self.client = client
        self.appName = appName
        self.service = service
        self.isAllowed = isAllowed
        self.lastModified = lastModified
        self.isSampleData = isSampleData
    }
}

enum TCCScanSource: String, Codable {
    case liveSystemDB = "Live System Database (Read-Only)"
    case sampleData = "Sample Data (App Sandboxed / TCC Unreadable)"
}

class TCCViewerManager: ObservableObject {
    static let shared = TCCViewerManager()

    @Published var permissions: [TCCPermissionItem] = []
    @Published var isScanning: Bool = false
    @Published var hasAccess: Bool = true
    @Published var scanSource: TCCScanSource = .sampleData
    @Published var activeDatabasePath: String = ""
    @Published var lastScanError: String?

    private init() {}

    func scanPermissions() {
        isScanning = true
        permissions = []
        lastScanError = nil

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let userTCCPath = ("~/Library/Application Support/com.apple.TCC/TCC.db" as NSString).expandingTildeInPath

            let fm = FileManager.default
            guard fm.isReadableFile(atPath: userTCCPath) else {
                await MainActor.run {
                    self.hasAccess = false
                    self.scanSource = .sampleData
                    self.activeDatabasePath = userTCCPath
                    self.lastScanError = "TCC.db is unreadable due to macOS App Sandbox/Full Disk Access restrictions."
                    self.permissions = self.getMockPermissions()
                    self.isScanning = false
                }
                return
            }

            let query = "SELECT client, service, allowed, last_modified FROM access;"
            let output = self.runSqliteQuery(dbPath: userTCCPath, sql: query)
            let parsed = self.parseSqliteOutput(output)

            await MainActor.run {
                if parsed.isEmpty {
                    self.hasAccess = false
                    self.scanSource = .sampleData
                    self.activeDatabasePath = userTCCPath
                    self.lastScanError = output.isEmpty ? "No TCC permission records found." : output
                    self.permissions = self.getMockPermissions()
                } else {
                    self.hasAccess = true
                    self.scanSource = .liveSystemDB
                    self.activeDatabasePath = userTCCPath
                    self.lastScanError = nil
                    self.permissions = parsed
                }
                self.isScanning = false
            }
        }
    }

    func resetPermission(for item: TCCPermissionItem, completion: @escaping (Bool, String) -> Void) {
        if item.isSampleData {
            completion(false, "Cannot revoke permissions for sample data. Grant Full Disk Access to inspect and manage actual TCC permissions.")
            return
        }

        let serviceName = item.service.replacingOccurrences(of: "kTCCService", with: "")
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let output = self.runShellCommand("/usr/bin/tccutil", args: ["reset", serviceName, item.client])

            await MainActor.run {
                self.scanPermissions()
                let success = !output.contains("failed") && !output.contains("Error")
                completion(success, output.isEmpty ? "Successfully reset \(serviceName) for \(item.client)" : output)
            }
        }
    }

    func resetAllPermissions(forBundle client: String, completion: @escaping (Bool, String) -> Void) {
        if permissions.first(where: { $0.client == client })?.isSampleData == true {
            completion(false, "Cannot revoke permissions for sample data. Grant Full Disk Access to inspect and manage actual TCC permissions.")
            return
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let output = self.runShellCommand("/usr/bin/tccutil", args: ["reset", "All", client])
            await MainActor.run {
                self.scanPermissions()
                let success = !output.contains("failed") && !output.contains("Error")
                completion(success, output.isEmpty ? "Successfully reset all permissions for \(client)" : output)
            }
        }
    }

    private func runSqliteQuery(dbPath: String, sql: String) -> String {
        return runShellCommand("/usr/bin/sqlite3", args: [dbPath, sql])
    }

    private func runShellCommand(_ cmd: String, args: [String]) -> String {
        let task = Process()
        task.launchPath = cmd
        task.arguments = args
        let pipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errPipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let outStr = String(data: data, encoding: .utf8) ?? ""
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            return outStr.isEmpty ? errStr : outStr
        } catch {
            return "Execution error: \(error.localizedDescription)"
        }
    }

    private func parseSqliteOutput(_ output: String) -> [TCCPermissionItem] {
        var results: [TCCPermissionItem] = []
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 3 else { continue }

            let client = parts[0]
            let service = parts[1]
            let allowed = parts[2] == "1"
            let timestampDouble = parts.count >= 4 ? Double(parts[3]) ?? Date().timeIntervalSince1970 : Date().timeIntervalSince1970
            let date = Date(timeIntervalSince1970: timestampDouble)

            let appName = getCleanAppName(from: client)

            results.append(TCCPermissionItem(
                client: client,
                appName: appName,
                service: service,
                isAllowed: allowed,
                lastModified: date,
                isSampleData: false
            ))
        }
        return results
    }

    private func getCleanAppName(from client: String) -> String {
        if client.contains(".") {
            let last = client.components(separatedBy: ".").last ?? client
            return last.capitalized
        }
        return client
    }

    func getMockPermissions() -> [TCCPermissionItem] {
        let now = Date()
        return [
            TCCPermissionItem(client: "com.spotify.client", appName: "Spotify", service: "kTCCServiceMicrophone", isAllowed: true, lastModified: now.addingTimeInterval(-86400), isSampleData: true),
            TCCPermissionItem(client: "com.tinyspeck.slackmacgap", appName: "Slack", service: "kTCCServiceCamera", isAllowed: false, lastModified: now.addingTimeInterval(-172800), isSampleData: true),
            TCCPermissionItem(client: "com.tinyspeck.slackmacgap", appName: "Slack", service: "kTCCServiceMicrophone", isAllowed: true, lastModified: now.addingTimeInterval(-172800), isSampleData: true),
            TCCPermissionItem(client: "com.microsoft.VSCode", appName: "VS Code", service: "kTCCServiceSystemPolicyAllFiles", isAllowed: true, lastModified: now.addingTimeInterval(-30000), isSampleData: true),
            TCCPermissionItem(client: "com.google.Chrome", appName: "Google Chrome", service: "kTCCServiceScreenCapture", isAllowed: true, lastModified: now.addingTimeInterval(-600000), isSampleData: true)
        ]
    }
}
