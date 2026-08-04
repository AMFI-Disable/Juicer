import Foundation
import Combine
import AppKit
import PDFKit

struct ConversionTask: Identifiable {
    let id = UUID()
    let inputName: String
    let inputFormat: String
    let outputFormat: String
    var status: String // "Pending", "Converting...", "Done", "Failed"
}

final class ConverterManager: ObservableObject {
    static let shared = ConverterManager()

    @Published var isConverting = false
    @Published var conversionHistory: [ConversionTask] = []
    @Published var lastOutputText: String = ""
    @Published var statusMessage: String = ""

    private var isInitialized = false

    private init() {}

    func ensureInitialized() {
        guard !isInitialized else { return }
        isInitialized = true
    }

    func purgeMemory() {
        lastOutputText = ""
        conversionHistory.removeAll(keepingCapacity: false)
    }

    // MARK: - Safe Destination Path Helper
    func resolveDestinationPath(inputURL: URL, targetFormat: String, outputDirectory: URL?) throws -> (destinationDir: URL, outputURL: URL) {
        let cleanExt = targetFormat
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".", with: "")
            .lowercased()

        guard !cleanExt.isEmpty else {
            throw NSError(domain: "ConverterManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid target format extension."])
        }

        let inputStd = inputURL.standardizedFileURL
        let destDir = (outputDirectory ?? inputStd.deletingLastPathComponent()).standardizedFileURL

        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true, attributes: nil)

        let baseName = inputStd.deletingPathExtension().lastPathComponent
        var outputURL = destDir.appendingPathComponent("\(baseName).\(cleanExt)").standardizedFileURL

        // Prevent destination path collision with source input path
        if outputURL.path == inputStd.path {
            outputURL = destDir.appendingPathComponent("\(baseName)_converted.\(cleanExt)").standardizedFileURL
        }

        return (destDir, outputURL)
    }

    // MARK: - Temp File Cleanup Helpers
    func createTempFileURL(in directory: URL, originalName: String, extension ext: String) -> URL {
        let tempName = ".tmp_\(UUID().uuidString)_\(originalName).\(ext)"
        return directory.appendingPathComponent(tempName).standardizedFileURL
    }

    func removeFileIfExists(at url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Document Conversion (Markdown, DOCX, PDF, HTML, RTF, TXT)
    func convertDocument(inputURL: URL, targetFormat: String, outputDirectory: URL? = nil, completion: @escaping (URL?) -> Void) {
        isConverting = true
        let inputStd = inputURL.standardizedFileURL

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            guard FileManager.default.fileExists(atPath: inputStd.path) else {
                DispatchQueue.main.async {
                    self.isConverting = false
                    self.statusMessage = "Input document does not exist."
                    completion(nil)
                }
                return
            }

            let destinationDir: URL
            let outputURL: URL
            do {
                let resolved = try self.resolveDestinationPath(inputURL: inputStd, targetFormat: targetFormat, outputDirectory: outputDirectory)
                destinationDir = resolved.destinationDir
                outputURL = resolved.outputURL
            } catch {
                DispatchQueue.main.async {
                    self.isConverting = false
                    self.statusMessage = "Failed to create destination path: \(error.localizedDescription)"
                    completion(nil)
                }
                return
            }

            let ext = outputURL.pathExtension.lowercased()
            let tempURL = self.createTempFileURL(in: destinationDir, originalName: inputStd.deletingPathExtension().lastPathComponent, extension: ext)

            let finish: (Bool) -> Void = { [weak self] ok in
                guard let self = self else { return }
                defer { self.removeFileIfExists(at: tempURL) }

                if ok && FileManager.default.fileExists(atPath: tempURL.path) {
                    do {
                        self.removeFileIfExists(at: outputURL)
                        try FileManager.default.moveItem(at: tempURL, to: outputURL)
                        DispatchQueue.main.async {
                            self.isConverting = false
                            self.statusMessage = "Converted successfully to \(outputURL.lastPathComponent)"
                            completion(outputURL)
                        }
                    } catch {
                        self.removeFileIfExists(at: outputURL)
                        DispatchQueue.main.async {
                            self.isConverting = false
                            self.statusMessage = "Failed to finalize document file: \(error.localizedDescription)"
                            completion(nil)
                        }
                    }
                } else {
                    self.removeFileIfExists(at: outputURL)
                    DispatchQueue.main.async {
                        self.isConverting = false
                        self.statusMessage = "Failed to convert document: \(inputStd.lastPathComponent)"
                        completion(nil)
                    }
                }
            }

            let srcExt = inputStd.pathExtension.lowercased()
            if srcExt == "md" && ext == "html" {
                if let mdText = try? String(contentsOf: inputStd, encoding: .utf8) {
                    let html = self.markdownToHTML(mdText)
                    do {
                        try html.write(to: tempURL, atomically: true, encoding: .utf8)
                        finish(true)
                    } catch {
                        finish(false)
                    }
                } else {
                    finish(false)
                }
            } else if srcExt == "md" && ext == "pdf" {
                if let mdText = try? String(contentsOf: inputStd, encoding: .utf8) {
                    let html = self.markdownToHTML(mdText)
                    self.renderHTMLToPDF(html, outputURL: tempURL) { ok in
                        finish(ok)
                    }
                } else {
                    finish(false)
                }
            } else {
                // Fallback to textutil
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
                process.arguments = ["-convert", ext, inputStd.path, "-output", tempURL.path]
                do {
                    try process.run()
                    process.waitUntilExit()
                    let success = process.terminationStatus == 0 && FileManager.default.fileExists(atPath: tempURL.path)
                    finish(success)
                } catch {
                    finish(false)
                }
            }
        }
    }

    private func markdownToHTML(_ md: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"><style>body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;padding:30px;line-height:1.6;color:#333;}h1,h2,h3{color:#111;}code{background:#f4f4f4;padding:2px 6px;border-radius:4px;font-family:monospace;}pre{background:#f4f4f4;padding:12px;border-radius:6px;overflow-x:auto;}</style></head>
        <body>
        \(md.replacingOccurrences(of: "\n", with: "<br>"))
        </body>
        </html>
        """
    }

    private func renderHTMLToPDF(_ html: String, outputURL: URL, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 800))
            textView.string = html.replacingOccurrences(of: "<br>", with: "\n")

            let pdfData = textView.dataWithPDF(inside: textView.bounds)
            do {
                try pdfData.write(to: outputURL, options: .atomic)
                completion(true)
            } catch {
                completion(false)
            }
        }
    }

    // MARK: - Image Scaling Bounds & Bitmap Extraction
    func createScaledBitmap(from image: NSImage, maxDimension: CGFloat? = 16384.0) -> NSBitmapImageRep? {
        var size = image.size
        guard size.width > 0 && size.height > 0 && size.width.isFinite && size.height.isFinite else {
            return nil
        }

        let safeMaxDim: CGFloat = min(maxDimension ?? 16384.0, 16384.0)
        if safeMaxDim > 0 && (size.width > safeMaxDim || size.height > safeMaxDim) {
            let scale = min(safeMaxDim / size.width, safeMaxDim / size.height)
            size.width = max(1.0, (size.width * scale).rounded(.down))
            size.height = max(1.0, (size.height * scale).rounded(.down))
        }

        let pixelWidth = Int(size.width)
        let pixelHeight = Int(size.height)
        guard pixelWidth > 0 && pixelHeight > 0 else { return nil }

        if size == image.size,
           let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           bitmap.pixelsWide > 0 && bitmap.pixelsHigh > 0,
           CGFloat(bitmap.pixelsWide) <= safeMaxDim && CGFloat(bitmap.pixelsHigh) <= safeMaxDim {
            return bitmap
        }

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        bitmap.size = size
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        return bitmap
    }

    // MARK: - Image Conversion (HEIC, PNG, JPEG, WebP, TIFF)
    func convertImage(inputURL: URL, targetFormat: String, outputDirectory: URL? = nil, maxDimension: CGFloat? = 16384.0, completion: @escaping (URL?) -> Void) {
        isConverting = true
        let inputStd = inputURL.standardizedFileURL

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            guard FileManager.default.fileExists(atPath: inputStd.path) else {
                DispatchQueue.main.async {
                    self.isConverting = false
                    self.statusMessage = "Input image file does not exist."
                    completion(nil)
                }
                return
            }

            let destinationDir: URL
            let outputURL: URL
            do {
                let resolved = try self.resolveDestinationPath(inputURL: inputStd, targetFormat: targetFormat, outputDirectory: outputDirectory)
                destinationDir = resolved.destinationDir
                outputURL = resolved.outputURL
            } catch {
                DispatchQueue.main.async {
                    self.isConverting = false
                    self.statusMessage = "Failed to create destination path: \(error.localizedDescription)"
                    completion(nil)
                }
                return
            }

            let ext = outputURL.pathExtension.lowercased()
            let tempURL = self.createTempFileURL(in: destinationDir, originalName: inputStd.deletingPathExtension().lastPathComponent, extension: ext)
            defer { self.removeFileIfExists(at: tempURL) }

            guard let image = NSImage(contentsOf: inputStd),
                  let bitmap = self.createScaledBitmap(from: image, maxDimension: maxDimension) else {
                DispatchQueue.main.async {
                    self.isConverting = false
                    self.statusMessage = "Failed to load or scale input image within safe bounds."
                    completion(nil)
                }
                return
            }

            var fileType: NSBitmapImageRep.FileType = .png
            if ext == "jpg" || ext == "jpeg" { fileType = .jpeg }
            else if ext == "bmp" { fileType = .bmp }
            else if ext == "tiff" { fileType = .tiff }
            else if ext == "gif" { fileType = .gif }

            var success = false
            if let data = bitmap.representation(using: fileType, properties: [:]) {
                do {
                    try data.write(to: tempURL, options: .atomic)
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        self.removeFileIfExists(at: outputURL)
                        try FileManager.default.moveItem(at: tempURL, to: outputURL)
                        success = true
                    }
                } catch {
                    success = false
                }
            }

            DispatchQueue.main.async {
                self.isConverting = false
                if success && FileManager.default.fileExists(atPath: outputURL.path) {
                    self.statusMessage = "Converted image successfully to \(outputURL.lastPathComponent)"
                    completion(outputURL)
                } else {
                    self.removeFileIfExists(at: outputURL)
                    self.statusMessage = "Failed to write image file."
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Code & Schema Conversion (JSON ↔ YAML ↔ Swift Struct ↔ TS Interface)
    func convertCodeSchema(input: String, fromFormat: String, toFormat: String) -> String {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }

        if toFormat == "Swift Struct" {
            return generateSwiftStruct(fromJSON: input)
        } else if toFormat == "TypeScript" {
            return generateTSInterface(fromJSON: input)
        } else if toFormat == "YAML" {
            return input.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "").replacingOccurrences(of: "\"", with: "")
        }
        return input
    }

    private func generateSwiftStruct(fromJSON jsonStr: String) -> String {
        guard let data = jsonStr.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "// Invalid JSON string provided."
        }

        var code = "struct GeneratedModel: Codable {\n"
        for (k, v) in dict {
            var typeStr = "String"
            if v is Int || v is Int64 { typeStr = "Int" } else if v is Double || v is Float { typeStr = "Double" } else if v is Bool { typeStr = "Bool" } else if v is [Any] { typeStr = "[String]" } else if v is [String: Any] { typeStr = "[String: Any]" }
            code += "    let \(k): \(typeStr)\n"
        }
        code += "}"
        return code
    }

    private func generateTSInterface(fromJSON jsonStr: String) -> String {
        guard let data = jsonStr.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "// Invalid JSON string provided."
        }

        var code = "export interface GeneratedModel {\n"
        for (k, v) in dict {
            var typeStr = "string"
            if v is Int || v is Double { typeStr = "number" } else if v is Bool { typeStr = "boolean" } else if v is [Any] { typeStr = "any[]" } else if v is [String: Any] { typeStr = "Record<string, any>" }
            code += "  \(k): \(typeStr);\n"
        }
        code += "}"
        return code
    }
}

