import Foundation

struct LargeFileItem: Identifiable, Hashable {
    let id: UUID = UUID()
    let url: URL
    let size: Int64
    let modificationDate: Date
    var isSelected: Bool

    var name: String { url.lastPathComponent }
    var path: String { url.path }
    var matchReason: String { size >= 100 * 1024 * 1024 ? "Size threshold" : "Age threshold" }
}

@MainActor
class LargeFilesManager: ObservableObject {
    @Published var largeFiles: [LargeFileItem] = []
    @Published var isScanning = false
    @Published var isTrashing = false
    @Published var sizeThresholdMB: Double = 100.0
    @Published var ageThresholdMonths: Int = 12
    @Published var searchDirectories: [URL]
    @Published var scanState: DiskScanState = .idle
    @Published var scanError: String?
    @Published var lastScanAt: Date?
    @Published var scanSourceDescription = "Downloads, Documents, Desktop"

    private let fileManager = FileManager.default
    private var scanTask: Task<Void, Never>?

    init() {
        let home = fileManager.homeDirectoryForCurrentUser
        searchDirectories = ["Downloads", "Documents", "Desktop"].map { home.appendingPathComponent($0) }
    }

    func addSearchDirectory(_ url: URL) {
        guard !searchDirectories.contains(url) else { return }
        searchDirectories.append(url)
        startScan()
    }

    func startScan() {
        guard !isScanning else { return }
        scanTask?.cancel()
        self.isScanning = true
        self.scanState = .scanning(progress: 0)
        self.scanError = nil
        self.largeFiles = []
        AppLogger.shared.log("Scanning Downloads, Documents, and Desktop folders for large or old files...")

        let sizeLimit = Int64(sizeThresholdMB) * 1024 * 1024
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .month, value: -ageThresholdMonths, to: Date()) ?? Date.distantPast
        let directories = self.searchDirectories
        let fm = self.fileManager

        scanTask = Task.detached(priority: .userInitiated) {
            var discovered: [LargeFileItem] = []
            let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]

            for (directoryIndex, directory) in directories.enumerated() {
                guard fm.fileExists(atPath: directory.path) else { continue }

                guard let enumerator = fm.enumerator(
                    at: directory,
                    includingPropertiesForKeys: keys,
                    options: [.skipsPackageDescendants, .skipsHiddenFiles]
                ) else { continue }

                for case let fileURL as URL in enumerator {
                    if Task.isCancelled { await MainActor.run { self.isScanning = false; self.scanState = .cancelled }; return }
                    guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)),
                          let isFile = resourceValues.isRegularFile, isFile,
                          let fileSize = resourceValues.fileSize,
                          let modDate = resourceValues.contentModificationDate
                    else { continue }

                    let size = Int64(fileSize)

                    // Match either larger than size threshold OR older than age threshold
                    if size >= sizeLimit || modDate < cutoffDate {
                        discovered.append(LargeFileItem(
                            url: fileURL,
                            size: size,
                            modificationDate: modDate,
                            isSelected: false
                        ))
                    }
                }
                await MainActor.run { self.scanState = .scanning(progress: Double(directoryIndex + 1) / Double(max(directories.count, 1))) }
            }

            // Sort by size descending
            let sorted = discovered.sorted(by: { $0.size > $1.size })

            await MainActor.run {
                self.largeFiles = sorted
                self.isScanning = false
                self.scanState = .completed
                self.lastScanAt = Date()
                self.scanTask = nil
                AppLogger.shared.log("Found \(sorted.count) large or old files matching criteria.")
            }
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            guard let self else { return }
            let scanning = await self.isScanning
            guard scanning else { return }
            await MainActor.run {
                self.scanTask?.cancel()
                self.isScanning = false
                self.scanState = .timedOut
                self.scanError = "The file scan exceeded 60 seconds. Narrow the folders or retry."
                self.scanTask = nil
            }
        }
    }

    func trashSelectedItems(completion: @escaping (Bool) -> Void) {
        self.isTrashing = true
        let itemsToTrash = largeFiles.filter { $0.isSelected }
        let fm = self.fileManager

        AppLogger.shared.log("Moving \(itemsToTrash.count) selected large files to Trash...")

        Task.detached(priority: .userInitiated) {
            var success = true

            for item in itemsToTrash {
                do {
                    if fm.fileExists(atPath: item.path) {
                        try fm.trashItem(at: item.url, resultingItemURL: nil)
                    }
                } catch {
                    AppLogger.shared.log("Failed to trash file \(item.name): \(error.localizedDescription)")
                    success = false
                }
            }

            await MainActor.run {
                self.isTrashing = false
                self.startScan() // Refresh scan
                completion(success)
            }
        }
    }
}
