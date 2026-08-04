import Foundation
import Combine

@MainActor
final class ArchiveUtilityManager: ObservableObject {
    @Published var inputURL: URL?
    @Published var message = "Drop an archive or folder here."
    @Published var working = false

    func setInput(_ url: URL) {
        let stdURL = url.standardizedFileURL.resolvingSymlinksInPath()
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: stdURL.path, isDirectory: &isDir) else {
            message = "Input path does not exist."
            return
        }
        inputURL = stdURL
        message = "Ready: \(stdURL.lastPathComponent)"
    }

    func extract(to destination: URL) {
        guard let inputURL else {
            message = "No input archive selected."
            return
        }

        let inputPath = inputURL.standardizedFileURL.resolvingSymlinksInPath().path
        guard FileManager.default.fileExists(atPath: inputPath) else {
            message = "Input file no longer exists."
            return
        }

        let destURL = destination.standardizedFileURL.resolvingSymlinksInPath()
        guard isValidExtractionDestination(destURL) else {
            message = "Extraction destination path is outside safe bounds."
            return
        }

        working = true
        let isZip = inputURL.pathExtension.lowercased() == "zip"
        let arguments = isZip ? ["-x", "-k", inputPath, destURL.path] : ["-xf", inputPath, "-C", destURL.path]
        let command = isZip ? "/usr/bin/ditto" : "/usr/bin/tar"

        DispatchQueue.global(qos: .userInitiated).async {
            let result = SystemMetricsSupport.run(command, arguments)
            Task { @MainActor in
                self.message = (result?.isEmpty == false) ? result! : "Extracted \(inputURL.lastPathComponent)."
                self.working = false
            }
        }
    }

    func createZip(at destination: URL) {
        guard let inputURL else {
            message = "No input item selected."
            return
        }

        let inputPath = inputURL.standardizedFileURL.resolvingSymlinksInPath().path
        guard FileManager.default.fileExists(atPath: inputPath) else {
            message = "Input item no longer exists."
            return
        }

        let destURL = destination.standardizedFileURL.resolvingSymlinksInPath()
        let destDir = destURL.deletingLastPathComponent()

        guard isValidDestinationDirectory(destDir) else {
            message = "Destination directory path is outside safe bounds."
            return
        }

        working = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = SystemMetricsSupport.run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", "--keepParent", inputPath, destURL.path])
            Task { @MainActor in
                self.message = (result?.isEmpty == false) ? result! : "Created \(destURL.lastPathComponent)."
                self.working = false
            }
        }
    }

    private func isValidExtractionDestination(_ url: URL) -> Bool {
        let path = url.path
        guard !path.isEmpty, path != "/" else { return false }

        let restrictedPrefixes = ["/System", "/bin", "/sbin", "/usr", "/private/var/root"]
        for prefix in restrictedPrefixes {
            if path == prefix || path.hasPrefix(prefix + "/") {
                return false
            }
        }

        if url.pathComponents.contains("..") {
            return false
        }

        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            return isDir.boolValue
        } else {
            let parent = url.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath()
            return isValidDestinationDirectory(parent)
        }
    }

    private func isValidDestinationDirectory(_ url: URL) -> Bool {
        let path = url.path
        guard !path.isEmpty, path != "/" else { return false }

        let restrictedPrefixes = ["/System", "/bin", "/sbin", "/usr", "/private/var/root"]
        for prefix in restrictedPrefixes {
            if path == prefix || path.hasPrefix(prefix + "/") {
                return false
            }
        }

        if url.pathComponents.contains("..") {
            return false
        }

        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
}

