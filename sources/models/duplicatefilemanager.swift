import Foundation
import Combine

struct DuplicateFile: Identifiable, Sendable {
    let id: UUID
    let url: URL
    let size: Int64
    let hash: String
    var selected: Bool

    init(id: UUID = UUID(), url: URL, size: Int64, hash: String, selected: Bool = false) {
        self.id = id
        self.url = url
        self.size = size
        self.hash = hash
        self.selected = selected
    }
}

@MainActor
final class DuplicateFileManager: ObservableObject {
    @Published var files: [DuplicateFile] = []
    @Published var isScanning = false
    @Published var message = ""

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        message = "Scanning user folders for matching file content…"

        Task {
            let maxTotalCandidates = 10_000
            let maxFilesPerGroupToHash = 50
            let maxDuplicatesToReturn = 1_000
            let maxFilePathLength = 1024
            let maxFileSize: Int64 = 5 * 1024 * 1024 * 1024

            let roots = ["Downloads", "Documents", "Desktop"].compactMap { folder -> URL? in
                let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(folder)
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    return url
                }
                return nil
            }

            let duplicates = await Task.detached(priority: .userInitiated) { () -> [DuplicateFile] in
                var candidates: [URL: Int64] = [:]
                let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]

                for root in roots {
                    guard candidates.count < maxTotalCandidates else { break }
                    guard let enumerator = FileManager.default.enumerator(
                        at: root,
                        includingPropertiesForKeys: Array(keys),
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    ) else { continue }

                    for case let url as URL in enumerator {
                        guard candidates.count < maxTotalCandidates else { break }
                        let path = url.path
                        guard path.count <= maxFilePathLength else { continue }
                        guard let values = try? url.resourceValues(forKeys: keys),
                              values.isRegularFile == true,
                              let size = values.fileSize,
                              size > 0,
                              Int64(size) <= maxFileSize else { continue }
                        candidates[url] = Int64(size)
                    }
                }

                var bySize = [Int64: [URL]]()
                candidates.forEach { bySize[$0.value, default: []].append($0.key) }

                var foundDuplicates: [DuplicateFile] = []
                for (size, urls) in bySize where urls.count > 1 {
                    guard foundDuplicates.count < maxDuplicatesToReturn else { break }
                    var byHash = [String: [URL]]()
                    let urlsToHash = Array(urls.prefix(maxFilesPerGroupToHash))

                    for url in urlsToHash {
                        guard let rawHash = SystemMetricsSupport.run("/usr/bin/shasum", ["-a", "256", url.path]),
                              let firstToken = rawHash.split(separator: " ").first else { continue }
                        byHash[String(firstToken), default: []].append(url)
                    }

                    for (hash, matches) in byHash where matches.count > 1 {
                        let items = matches.map { DuplicateFile(url: $0, size: size, hash: hash) }
                        foundDuplicates.append(contentsOf: items)
                        if foundDuplicates.count >= maxDuplicatesToReturn {
                            break
                        }
                    }
                }

                return Array(foundDuplicates.prefix(maxDuplicatesToReturn))
            }.value

            self.files = duplicates.sorted { $0.size > $1.size }
            self.message = duplicates.isEmpty ? "No duplicate files found." : "Found \(duplicates.count) duplicate file(s)."
            self.isScanning = false
        }
    }

    func trashSelected() {
        let selected = files.filter(\.selected)
        guard !selected.isEmpty else { return }

        let forbiddenPrefixes = ["/System", "/bin", "/sbin", "/usr", "/etc", "/var", "/private"]

        for file in selected {
            guard file.url.isFileURL else { continue }
            let standardizedURL = file.url.standardizedFileURL
            let path = standardizedURL.path

            guard !path.isEmpty && path != "/" else { continue }
            if forbiddenPrefixes.contains(where: { path.hasPrefix($0) }) { continue }

            try? FileManager.default.trashItem(at: standardizedURL, resultingItemURL: nil)
        }

        scan()
    }
}
