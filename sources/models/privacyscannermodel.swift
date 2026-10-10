import Foundation
import Combine

public enum PermissionCategory: String, Codable, CaseIterable, Identifiable {
    case microphone = "Microphone"
    case camera = "Camera"
    case screenCapture = "Screen Recording"
    case fullDiskAccess = "Full Disk Access"
    case accessibility = "Accessibility"
    case location = "Location"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .microphone: return "mic.fill"
        case .camera: return "camera.fill"
        case .screenCapture: return "desktopcomputer"
        case .fullDiskAccess: return "folder.fill"
        case .accessibility: return "figure.wave"
        case .location: return "location.fill"
        }
    }
}

public enum PermissionGrantState: String, Codable {
    case granted = "Granted"
    case denied = "Denied"
    case unknown = "Unknown / Not Requested"
}

public enum PermissionSource: String, Codable {
    case liveTCCDatabase = "Live TCC Database"
    case bundleMetadataHeuristic = "Bundle Info.plist Request"
    case sampleData = "Sample Baseline"
}

public enum ScanConfidence: String, Codable {
    case high = "High (Verified System DB)"
    case medium = "Medium (Bundle Usage Key Declared)"
    case low = "Low (Sample / Estimated Baseline)"
}

public struct PrivacyAppPermissionRecord: Identifiable, Codable, Equatable {
    public let id: String
    public let appName: String
    public let bundleID: String
    public let category: PermissionCategory
    public let grantState: PermissionGrantState
    public let source: PermissionSource
    public let lastModified: Date?
    public let confidence: ScanConfidence

    public init(id: String = UUID().uuidString, appName: String, bundleID: String, category: PermissionCategory, grantState: PermissionGrantState, source: PermissionSource, lastModified: Date? = nil, confidence: ScanConfidence) {
        self.id = id
        self.appName = appName
        self.bundleID = bundleID
        self.category = category
        self.grantState = grantState
        self.source = source
        self.lastModified = lastModified
        self.confidence = confidence
    }
}

public enum PrivacyScanState: Equatable {
    case idle
    case scanning(progress: Double, currentApp: String)
    case completed(totalAppsScanned: Int, recordsCount: Int)
    case cancelled
    case failed(error: String)
}

public enum PrivacyScannerEngine {
    public static func discoverApplicationPaths() -> [String] {
        let fm = FileManager.default
        let dirs = ["/Applications", "/System/Applications", ("~/Applications" as NSString).expandingTildeInPath]
        var results: [String] = []

        for dir in dirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                results.append("\(dir)/\(item)")
            }
        }
        return results.sorted()
    }

    public static func extractBundleID(at appPath: String) -> String? {
        let plistPath = "\(appPath)/Contents/Info.plist"
        guard let dict = NSDictionary(contentsOfFile: plistPath) else { return nil }
        return dict["CFBundleIdentifier"] as? String
    }

    static func inspectPermissions(forApp appName: String, bundleID: String, plistPath: String, tccItems: [TCCPermissionItem], isTCCReadable: Bool) -> [PrivacyAppPermissionRecord] {
        var results: [PrivacyAppPermissionRecord] = []
        let plistDict = NSDictionary(contentsOfFile: plistPath) as? [String: Any] ?? [:]

        let usageKeys: [(key: String, category: PermissionCategory)] = [
            ("NSMicrophoneUsageDescription", .microphone),
            ("NSCameraUsageDescription", .camera),
            ("NSScreenCaptureUsageDescription", .screenCapture),
            ("NSDesktopFolderUsageDescription", .fullDiskAccess),
            ("NSDocumentsFolderUsageDescription", .fullDiskAccess),
            ("NSDownloadsFolderUsageDescription", .fullDiskAccess),
            ("NSLocationWhenInUseUsageDescription", .location)
        ]

        if isTCCReadable && !tccItems.isEmpty {
            for item in tccItems {
                let cat = mapTCCServiceToCategory(item.service)
                results.append(PrivacyAppPermissionRecord(
                    appName: appName,
                    bundleID: bundleID,
                    category: cat,
                    grantState: item.isAllowed ? .granted : .denied,
                    source: .liveTCCDatabase,
                    lastModified: item.lastModified,
                    confidence: .high
                ))
            }
        } else {
            for (key, cat) in usageKeys where plistDict[key] != nil {
                results.append(PrivacyAppPermissionRecord(
                    appName: appName,
                    bundleID: bundleID,
                    category: cat,
                    grantState: .unknown,
                    source: .bundleMetadataHeuristic,
                    lastModified: nil,
                    confidence: .medium
                ))
            }
        }
        return results
    }

    public static func mapTCCServiceToCategory(_ service: String) -> PermissionCategory {
        let clean = service.replacingOccurrences(of: "kTCCService", with: "")
        switch clean {
        case "Microphone": return .microphone
        case "Camera": return .camera
        case "ScreenCapture": return .screenCapture
        case "SystemPolicyAllFiles": return .fullDiskAccess
        case "Accessibility": return .accessibility
        case "Location": return .location
        default: return .fullDiskAccess
        }
    }

    static func queryTCCDatabase(path: String) -> [TCCPermissionItem] {
        let task = Process()
        task.launchPath = "/usr/bin/sqlite3"
        task.arguments = [path, "SELECT client, service, allowed, last_modified FROM access;"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return parseSqliteOutput(output)
        } catch {
            return []
        }
    }

    private static func parseSqliteOutput(_ output: String) -> [TCCPermissionItem] {
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

            results.append(TCCPermissionItem(
                client: client,
                appName: client.components(separatedBy: ".").last?.capitalized ?? client,
                service: service,
                isAllowed: allowed,
                lastModified: date,
                isSampleData: false
            ))
        }
        return results
    }

    public static func getFallbackSampleRecords() -> [PrivacyAppPermissionRecord] {
        let now = Date()
        return [
            PrivacyAppPermissionRecord(appName: "Spotify", bundleID: "com.spotify.client", category: .microphone, grantState: .granted, source: .sampleData, lastModified: now.addingTimeInterval(-86400), confidence: .low),
            PrivacyAppPermissionRecord(appName: "Slack", bundleID: "com.tinyspeck.slackmacgap", category: .camera, grantState: .denied, source: .sampleData, lastModified: now.addingTimeInterval(-172800), confidence: .low),
            PrivacyAppPermissionRecord(appName: "Slack", bundleID: "com.tinyspeck.slackmacgap", category: .microphone, grantState: .granted, source: .sampleData, lastModified: now.addingTimeInterval(-172800), confidence: .low),
            PrivacyAppPermissionRecord(appName: "VS Code", bundleID: "com.microsoft.VSCode", category: .fullDiskAccess, grantState: .granted, source: .sampleData, lastModified: now.addingTimeInterval(-30000), confidence: .low),
            PrivacyAppPermissionRecord(appName: "Google Chrome", bundleID: "com.google.Chrome", category: .screenCapture, grantState: .granted, source: .sampleData, lastModified: now.addingTimeInterval(-600000), confidence: .low)
        ]
    }
}

@MainActor
public final class PrivacyScannerManager: ObservableObject {
    public static let shared = PrivacyScannerManager()

    @Published public private(set) var state: PrivacyScanState = .idle
    @Published public private(set) var records: [PrivacyAppPermissionRecord] = []
    @Published public var filterCategory: PermissionCategory?
    @Published public var searchQuery: String = ""

    private var scanTask: Task<Void, Never>?

    public init() {}

    public var filteredRecords: [PrivacyAppPermissionRecord] {
        records.filter { record in
            let matchesCategory = filterCategory == nil || record.category == filterCategory
            let matchesSearch = searchQuery.isEmpty ||
                record.appName.localizedCaseInsensitiveContains(searchQuery) ||
                record.bundleID.localizedCaseInsensitiveContains(searchQuery)
            return matchesCategory && matchesSearch
        }
    }

    public func startScan() {
        scanTask?.cancel()

        state = .scanning(progress: 0.0, currentApp: "Initializing scanner...")
        records = []

        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let appPaths = PrivacyScannerEngine.discoverApplicationPaths()
            let total = max(appPaths.count, 1)
            var accumulativeRecords: [PrivacyAppPermissionRecord] = []

            let userTCCPath = ("~/Library/Application Support/com.apple.TCC/TCC.db" as NSString).expandingTildeInPath
            let isTCCReadable = FileManager.default.isReadableFile(atPath: userTCCPath)

            var tccEntries: [String: [TCCPermissionItem]] = [:]
            if isTCCReadable {
                let liveItems = PrivacyScannerEngine.queryTCCDatabase(path: userTCCPath)
                tccEntries = Dictionary(grouping: liveItems, by: \.client)
            }

            for (index, path) in appPaths.enumerated() {
                if Task.isCancelled {
                    await MainActor.run { self.state = .cancelled }
                    return
                }

                let appName = (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
                let bundleID = PrivacyScannerEngine.extractBundleID(at: path) ?? "com.unknown.\(appName.lowercased())"

                await MainActor.run {
                    self.state = .scanning(progress: Double(index + 1) / Double(total), currentApp: appName)
                }

                let appRecords = PrivacyScannerEngine.inspectPermissions(forApp: appName, bundleID: bundleID, plistPath: "\(path)/Contents/Info.plist", tccItems: tccEntries[bundleID] ?? [], isTCCReadable: isTCCReadable)
                accumulativeRecords.append(contentsOf: appRecords)

                try? await Task.sleep(nanoseconds: 5_000_000)
            }

            if accumulativeRecords.isEmpty {
                accumulativeRecords = PrivacyScannerEngine.getFallbackSampleRecords()
            }

            if Task.isCancelled {
                await MainActor.run { self.state = .cancelled }
                return
            }

            let finalRecords = accumulativeRecords
            let appCount = appPaths.count
            await MainActor.run {
                self.records = finalRecords
                self.state = .completed(totalAppsScanned: appCount, recordsCount: finalRecords.count)
            }
        }
    }

    public func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        state = .cancelled
    }
}
