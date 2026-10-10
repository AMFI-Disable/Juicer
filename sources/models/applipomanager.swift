import Foundation
import AppKit

struct LipoAppItem: Identifiable, Hashable {
    let id: UUID = UUID()
    let appName: String
    let bundleIdentifier: String
    let path: URL
    let icon: NSImage
    let totalSize: Int64
    let architectures: [String]
    let estimatedSavings: Int64
    var isThinned: Bool
}

@MainActor
final class AppLipoManager: ObservableObject {
    @Published var universalApps: [LipoAppItem] = []
    @Published var isScanning = false
    @Published var isThinning = false

    private let fileManager = FileManager.default

    // Mach-O constants
    private let FAT_MAGIC: UInt32 = 0xcafebabe
    private let FAT_CIGAM: UInt32 = 0xbebafeca
    private let CPU_TYPE_ARM64: UInt32 = 0x100000c
    private let CPU_TYPE_X86_64: UInt32 = 0x01000007

    struct FatHeader {
        let magic: UInt32
        let numArchitectures: UInt32
    }

    struct FatArch {
        let cpuType: UInt32
        let cpuSubtype: UInt32
        let offset: UInt32
        let size: UInt32
        let align: UInt32
    }

    func scanForUniversalApps() {
        self.isScanning = true
        self.universalApps = []
        AppLogger.shared.log("Scanning applications directory for Universal binaries...")

        Task.detached(priority: .userInitiated) {
            let scanPaths = ["/Applications", "/System/Applications"]
            var discovered: [LipoAppItem] = []

            for basePath in scanPaths {
                let baseFolder = URL(fileURLWithPath: basePath)
                guard let enumerator = FileManager.default.enumerator(
                    at: baseFolder,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
                ) else { continue }

                while let fileURL = enumerator.nextObject() as? URL {
                    if fileURL.pathExtension == "app" {
                        self.processAppBundle(fileURL, discovered: &discovered)
                    }
                }
            }

            let sorted = discovered.sorted(by: { $0.estimatedSavings > $1.estimatedSavings })

            await MainActor.run {
                self.universalApps = sorted
                self.isScanning = false
                AppLogger.shared.log("Scan complete. Discovered \(sorted.count) universal applications.")
            }
        }
    }

    private nonisolated func processAppBundle(_ bundleURL: URL, discovered: inout [LipoAppItem]) {
        let info = AppInfo(path: bundleURL)
        guard !info.appName.isEmpty else { return }

        // Find main executable
        let infoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOf: infoPlistURL),
              let execName = plist["CFBundleExecutable"] as? String else { return }

        // Strict whitelist validation for executable name to prevent path injection
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " .-_\n\r"))
        guard execName.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) else { return }

        let macosDir = bundleURL.appendingPathComponent("Contents/MacOS").resolvingSymlinksInPath()
        let execURL = macosDir.appendingPathComponent(execName).resolvingSymlinksInPath()
        guard execURL.path.hasPrefix(macosDir.path + "/"),
              FileManager.default.fileExists(atPath: execURL.path),
              let attributes = try? FileManager.default.attributesOfItem(atPath: execURL.path),
              let fileSizeNum = attributes[.size] as? NSNumber else { return }

        let fileSize = fileSizeNum.uint64Value
        // Minimum valid FAT binary: FAT header (8 bytes) + at least 1 FatArch struct (20 bytes) = 28 bytes
        guard fileSize >= 28 else { return }

        // Parse Mach-O header
        guard let fileHandle = try? FileHandle(forReadingFrom: execURL) else { return }
        defer { try? fileHandle.close() }

        guard let headerData = try? fileHandle.read(upToCount: 8), headerData.count == 8 else { return }

        let magic = headerData.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self).bigEndian }

        if magic == FAT_MAGIC || magic == FAT_CIGAM {
            // It is a FAT / Universal binary!
            let numArchs = headerData.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self).bigEndian }

            // Guard against invalid or malicious architecture counts
            guard numArchs > 0 && numArchs <= 64, UInt64(8 + numArchs * 20) <= fileSize else { return }

            var archs: [FatArch] = []
            for _ in 0..<numArchs {
                guard let archData = try? fileHandle.read(upToCount: 20), archData.count == 20 else { return }

                let arch = archData.withUnsafeBytes { ptr in
                    FatArch(
                        cpuType: ptr.load(fromByteOffset: 0, as: UInt32.self).bigEndian,
                        cpuSubtype: ptr.load(fromByteOffset: 4, as: UInt32.self).bigEndian,
                        offset: ptr.load(fromByteOffset: 8, as: UInt32.self).bigEndian,
                        size: ptr.load(fromByteOffset: 12, as: UInt32.self).bigEndian,
                        align: ptr.load(fromByteOffset: 16, as: UInt32.self).bigEndian
                    )
                }

                // Strict bounds checking: slice offset & size must fit within binary file length
                guard UInt64(arch.offset) >= 28,
                      UInt64(arch.size) > 0,
                      UInt64(arch.offset) + UInt64(arch.size) <= fileSize else { return }

                archs.append(arch)
            }

            // Build arch string representations and calculate sizes
            var architectures: [String] = []
            var armSize: Int64 = 0
            var intelSize: Int64 = 0

            for arch in archs {
                if arch.cpuType == CPU_TYPE_ARM64 {
                    architectures.append("Apple Silicon (arm64)")
                    armSize = Int64(arch.size)
                } else if arch.cpuType == CPU_TYPE_X86_64 {
                    architectures.append("Intel (x86_64)")
                    intelSize = Int64(arch.size)
                }
            }

            // If it has multiple slices, calculate potential savings
            if architectures.count > 1 {
                let appSize = getPathSize(bundleURL)

                // Native arch determination
                var estimatedSavings: Int64 = 0
                #if arch(arm64)
                estimatedSavings = intelSize // Thinning on Apple Silicon saves the Intel binary size
                #else
                estimatedSavings = armSize   // Thinning on Intel saves the ARM binary size
                #endif

                discovered.append(LipoAppItem(
                    appName: info.appName,
                    bundleIdentifier: info.bundleIdentifier,
                    path: bundleURL,
                    icon: info.icon,
                    totalSize: appSize,
                    architectures: architectures,
                    estimatedSavings: estimatedSavings,
                    isThinned: false
                ))
            }
        }
    }

    func thinApplication(_ app: LipoAppItem, completion: @escaping @MainActor (Bool) -> Void) {
        self.isThinning = true
        AppLogger.shared.log("Thinning application binary: \(app.appName)...")

        Task.detached(priority: .userInitiated) {
            let infoPlistURL = app.path.appendingPathComponent("Contents/Info.plist")
            guard let plist = NSDictionary(contentsOf: infoPlistURL),
                  let execName = plist["CFBundleExecutable"] as? String else {
                await MainActor.run {
                    self.isThinning = false
                    completion(false)
                }
                return
            }

            // Strict whitelist validation for executable name to prevent path injection
            let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " .-_\n\r"))
            guard execName.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) else {
                await MainActor.run {
                    self.isThinning = false
                    completion(false)
                }
                return
            }

            let macosDir = app.path.appendingPathComponent("Contents/MacOS").resolvingSymlinksInPath()
            let execURL = macosDir.appendingPathComponent(execName).resolvingSymlinksInPath()
            guard execURL.path.hasPrefix(macosDir.path + "/"),
                  let attributes = try? FileManager.default.attributesOfItem(atPath: execURL.path),
                  let fileSizeNum = attributes[.size] as? NSNumber else {
                await MainActor.run {
                    self.isThinning = false
                    completion(false)
                }
                return
            }

            let fileSize = fileSizeNum.uint64Value
            guard fileSize >= 28 else {
                await MainActor.run {
                    self.isThinning = false
                    completion(false)
                }
                return
            }

            guard let fileHandle = try? FileHandle(forReadingFrom: execURL) else {
                await MainActor.run {
                    self.isThinning = false
                    completion(false)
                }
                return
            }

            // Read headers to find native offset
            guard let headerData = try? fileHandle.read(upToCount: 8), headerData.count == 8 else {
                try? fileHandle.close()
                await MainActor.run {
                    self.isThinning = false
                    completion(false)
                }
                return
            }

            let numArchs = headerData.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self).bigEndian }
            guard numArchs > 0 && numArchs <= 64, UInt64(8 + numArchs * 20) <= fileSize else {
                try? fileHandle.close()
                await MainActor.run {
                    self.isThinning = false
                    completion(false)
                }
                return
            }

            var targetArch: FatArch?

            for _ in 0..<numArchs {
                guard let archData = try? fileHandle.read(upToCount: 20), archData.count == 20 else { break }

                let arch = archData.withUnsafeBytes { ptr in
                    FatArch(
                        cpuType: ptr.load(fromByteOffset: 0, as: UInt32.self).bigEndian,
                        cpuSubtype: ptr.load(fromByteOffset: 4, as: UInt32.self).bigEndian,
                        offset: ptr.load(fromByteOffset: 8, as: UInt32.self).bigEndian,
                        size: ptr.load(fromByteOffset: 12, as: UInt32.self).bigEndian,
                        align: ptr.load(fromByteOffset: 16, as: UInt32.self).bigEndian
                    )
                }

                // Verify slice bounds
                guard UInt64(arch.offset) >= 28,
                      UInt64(arch.size) > 0,
                      UInt64(arch.offset) + UInt64(arch.size) <= fileSize else { continue }

                #if arch(arm64)
                if arch.cpuType == self.CPU_TYPE_ARM64 {
                    targetArch = arch
                    break
                }
                #else
                if arch.cpuType == self.CPU_TYPE_X86_64 {
                    targetArch = arch
                    break
                }
                #endif
            }

            guard let target = targetArch else {
                try? fileHandle.close()
                await MainActor.run {
                    self.isThinning = false
                    completion(false)
                }
                return
            }

            // Harden bounds check for slice extraction
            let sliceOffset = UInt64(target.offset)
            let sliceSize = UInt64(target.size)
            guard sliceOffset >= 28, sliceSize > 0, sliceOffset + sliceSize <= fileSize else {
                try? fileHandle.close()
                await MainActor.run {
                    self.isThinning = false
                    completion(false)
                }
                return
            }

            // Extract the slice bytes
            do {
                try fileHandle.seek(toOffset: sliceOffset)
            } catch {
                try? fileHandle.close()
                await MainActor.run {
                    self.isThinning = false
                    completion(false)
                }
                return
            }

            guard let sliceData = try? fileHandle.read(upToCount: Int(target.size)),
                  sliceData.count == Int(target.size) else {
                try? fileHandle.close()
                await MainActor.run {
                    self.isThinning = false
                    completion(false)
                }
                return
            }
            try? fileHandle.close()

            // Verify extracted slice has valid Mach-O header magic number before overwriting executable
            guard sliceData.count >= 4 else {
                await MainActor.run {
                    self.isThinning = false
                    completion(false)
                }
                return
            }

            let sliceMagic = sliceData.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
            let sliceMagicBig = sliceMagic.bigEndian
            let validMagics: Set<UInt32> = [
                0xfeedfacf, // MH_MAGIC_64
                0xcffaedfe, // MH_CIGAM_64
                0xfeedface, // MH_MAGIC
                0xcefaedfe  // MH_CIGAM
            ]
            guard validMagics.contains(sliceMagic) || validMagics.contains(sliceMagicBig) else {
                AppLogger.shared.log("Extracted binary slice failed Mach-O magic validation.")
                await MainActor.run {
                    self.isThinning = false
                    completion(false)
                }
                return
            }

            // Preserve executable permissions
            let posixPermissions = attributes[.posixPermissions] as? NSNumber ?? NSNumber(value: 0o755)

            // Overwrite binary with native slice
            do {
                try sliceData.write(to: execURL, options: .atomic)
                try? FileManager.default.setAttributes([.posixPermissions: posixPermissions], ofItemAtPath: execURL.path)

                AppLogger.shared.log("Successfully thinned binary for \(app.appName). Saved \(self.formatBytes(app.estimatedSavings))!")

                // Update local status on MainActor
                await MainActor.run {
                    if let index = self.universalApps.firstIndex(where: { $0.id == app.id }) {
                        self.universalApps[index].isThinned = true
                    }
                    self.isThinning = false
                    self.scanForUniversalApps()
                    completion(true)
                }
            } catch {
                AppLogger.shared.log("Failed to write thinned slice: \(error.localizedDescription)")
                await MainActor.run {
                    self.isThinning = false
                    completion(false)
                }
            }
        }
    }

    private nonisolated func getPathSize(_ url: URL) -> Int64 {
        var size: Int64 = 0
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: []
        ) else { return 0 }

        while let fileURL = enumerator.nextObject() as? URL {
            if let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)) {
                let isDirectory = resourceValues.isDirectory ?? false
                if !isDirectory {
                    size += Int64(resourceValues.fileSize ?? 0)
                }
            }
        }

        return size
    }

    private nonisolated func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
