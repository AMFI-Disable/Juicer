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

    // MARK: - Document Conversion (Markdown, DOCX, PDF, HTML, RTF, TXT)
    func convertDocument(inputURL: URL, targetFormat: String, outputDirectory: URL? = nil, completion: @escaping (URL?) -> Void) {
        isConverting = true
        let ext = targetFormat.lowercased()
        let destinationDir = outputDirectory ?? inputURL.deletingLastPathComponent()
        let outputURL = destinationDir.appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent + ".\(ext)")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard FileManager.default.fileExists(atPath: inputURL.path) else {
                DispatchQueue.main.async {
                    self?.isConverting = false
                    self?.statusMessage = "Input document does not exist."
                    completion(nil)
                }
                return
            }

            try? FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true, attributes: nil)

            let finish: (Bool) -> Void = { ok in
                DispatchQueue.main.async {
                    self?.isConverting = false
                    if ok && FileManager.default.fileExists(atPath: outputURL.path) {
                        self?.statusMessage = "Converted successfully to \(outputURL.lastPathComponent)"
                        completion(outputURL)
                    } else {
                        if FileManager.default.fileExists(atPath: outputURL.path) {
                            try? FileManager.default.removeItem(at: outputURL)
                        }
                        self?.statusMessage = "Failed to convert document: \(inputURL.lastPathComponent)"
                        completion(nil)
                    }
                }
            }

            if inputURL.pathExtension.lowercased() == "md" && ext == "html" {
                if let mdText = try? String(contentsOf: inputURL, encoding: .utf8) {
                    let html = self?.markdownToHTML(mdText) ?? ""
                    do {
                        try html.write(to: outputURL, atomically: true, encoding: .utf8)
                        finish(true)
                    } catch {
                        finish(false)
                    }
                } else {
                    finish(false)
                }
            } else if inputURL.pathExtension.lowercased() == "md" && ext == "pdf" {
                if let mdText = try? String(contentsOf: inputURL, encoding: .utf8) {
                    let html = self?.markdownToHTML(mdText) ?? ""
                    self?.renderHTMLToPDF(html, outputURL: outputURL) { ok in
                        finish(ok)
                    }
                } else {
                    finish(false)
                }
            } else {
                // Fallback to textutil
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
                process.arguments = ["-convert", ext, inputURL.path, "-output", outputURL.path]
                do {
                    try process.run()
                    process.waitUntilExit()
                    let success = process.terminationStatus == 0 && FileManager.default.fileExists(atPath: outputURL.path)
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

    // MARK: - Image Conversion (HEIC, PNG, JPEG, WebP, TIFF)
    func convertImage(inputURL: URL, targetFormat: String, outputDirectory: URL? = nil, completion: @escaping (URL?) -> Void) {
        isConverting = true
        let ext = targetFormat.lowercased()
        let destinationDir = outputDirectory ?? inputURL.deletingLastPathComponent()
        let outputURL = destinationDir.appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent + ".\(ext)")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard FileManager.default.fileExists(atPath: inputURL.path) else {
                DispatchQueue.main.async {
                    self?.isConverting = false
                    self?.statusMessage = "Input image file does not exist."
                    completion(nil)
                }
                return
            }

            try? FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true, attributes: nil)

            guard let image = NSImage(contentsOf: inputURL),
                  let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData) else {
                DispatchQueue.main.async {
                    self?.isConverting = false
                    self?.statusMessage = "Failed to load input image."
                    completion(nil)
                }
                return
            }

            var fileType: NSBitmapImageRep.FileType = .png
            if ext == "jpg" || ext == "jpeg" { fileType = .jpeg } else if ext == "bmp" { fileType = .bmp } else if ext == "tiff" { fileType = .tiff } else if ext == "gif" { fileType = .gif }

            var success = false
            if let data = bitmap.representation(using: fileType, properties: [:]) {
                do {
                    try data.write(to: outputURL, options: .atomic)
                    success = true
                } catch {
                    success = false
                }
            }

            DispatchQueue.main.async {
                self?.isConverting = false
                if success && FileManager.default.fileExists(atPath: outputURL.path) {
                    self?.statusMessage = "Converted image successfully to \(outputURL.lastPathComponent)"
                    completion(outputURL)
                } else {
                    if FileManager.default.fileExists(atPath: outputURL.path) {
                        try? FileManager.default.removeItem(at: outputURL)
                    }
                    self?.statusMessage = "Failed to write image file."
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
