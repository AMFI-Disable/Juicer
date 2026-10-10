import Foundation

enum DiskScanState: Equatable { case idle, scanning(progress: Double), completed, cancelled, failed(String), timedOut }

struct DiskScanMetadata: Equatable {
    let sourcePath: String
    let startedAt: Date
    var finishedAt: Date?
    var entriesVisited: Int
    var excludedPaths: [String]
    var permissionFailures: [String]
}

struct CleanupPreviewBinding: Equatable {
    let operationID: UUID
    let source: String
    let createdAt: Date
    let paths: [String]
    let bytes: Int64
}

enum DiskSafetyPolicy {
    static func canMutateSnapshot(volume: String, snapshotID: String, confirmedID: String) -> Bool {
        !volume.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !snapshotID.isEmpty && snapshotID == confirmedID
    }
}

enum DiskPathPresentation {
    static func display(_ path: String, reveal: Bool) -> String {
        guard !reveal else { return path }
        let url = URL(fileURLWithPath: path)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : url.lastPathComponent
    }
}
