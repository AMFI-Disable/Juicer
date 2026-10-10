import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Converter Domain & Modes
enum ConverterCategory: String, CaseIterable, Identifiable {
    case codeSchemas = "Code Schemas"
    case encodings = "Encodings & Web"
    case dataFormats = "Data Formats"
    case colors = "Colors"
    case batchFiles = "Batch Files"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .codeSchemas: return "curlybraces"
        case .encodings: return "lock.shield"
        case .dataFormats: return "doc.text"
        case .colors: return "paintpalette"
        case .batchFiles: return "square.stack.3d.up"
        }
    }
}

enum ConverterMode: String, CaseIterable, Identifiable {
    // Code Schemas
    case jsonToSwift = "JSON → Swift Struct"
    case jsonToTS = "JSON → TypeScript"
    case jsonToGo = "JSON → Go Struct"
    case jsonToPython = "JSON → Python Dataclass"

    // Encodings
    case base64Encode = "Base64 Encode"
    case base64Decode = "Base64 Decode"
    case urlEncode = "URL Encode"
    case urlDecode = "URL Decode"
    case htmlEntityEncode = "HTML Entity Encode"

    // Data Formats
    case jsonToYAML = "JSON → YAML"
    case jsonToXML = "JSON → XML"
    case csvToJSON = "CSV → JSON"

    // Colors
    case hexToRGB = "HEX → RGB / HSL"

    var id: String { rawValue }

    var category: ConverterCategory {
        switch self {
        case .jsonToSwift, .jsonToTS, .jsonToGo, .jsonToPython:
            return .codeSchemas
        case .base64Encode, .base64Decode, .urlEncode, .urlDecode, .htmlEntityEncode:
            return .encodings
        case .jsonToYAML, .jsonToXML, .csvToJSON:
            return .dataFormats
        case .hexToRGB:
            return .colors
        }
    }
}

// MARK: - Batch Item Model
struct BatchConversionItem: Identifiable {
    let id = UUID()
    let url: URL
    var status: BatchStatus

    enum BatchStatus {
        case pending
        case converting
        case completed(String)
        case failed(String)
    }
}

// MARK: - View Model
final class ConverterStudioViewModel: ObservableObject {
    @Published var selectedCategory: ConverterCategory = .codeSchemas {
        didSet {
            if let firstMode = modesForCategory(selectedCategory).first {
                selectedMode = firstMode
            }
        }
    }
    @Published var selectedMode: ConverterMode = .jsonToSwift {
        didSet { convertInput() }
    }

    @Published var inputText: String = "{\n  \"name\": \"Juicer\",\n  \"version\": \"1.0.3\",\n  \"active\": true\n}" {
        didSet { convertInput() }
    }
    @Published var outputText: String = ""
    @Published var validationError: String?
    @Published var showCopyToast: Bool = false
    @Published var isTargetedForDrop: Bool = false
    @Published var batchItems: [BatchConversionItem] = []

    func modesForCategory(_ category: ConverterCategory) -> [ConverterMode] {
        ConverterMode.allCases.filter { $0.category == category }
    }

    func convertInput() {
        validationError = nil
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            outputText = ""
            return
        }

        switch selectedMode {
        case .jsonToSwift:
            outputText = convertJSONToSwift(json: inputText)
        case .jsonToTS:
            outputText = convertJSONToTS(json: inputText)
        case .jsonToGo:
            outputText = convertJSONToGo(json: inputText)
        case .jsonToPython:
            outputText = convertJSONToPython(json: inputText)
        case .base64Encode:
            outputText = Data(inputText.utf8).base64EncodedString()
        case .base64Decode:
            if let data = Data(base64Encoded: inputText.trimmingCharacters(in: .whitespacesAndNewlines)) {
                outputText = String(data: data, encoding: .utf8) ?? "Error: Binary data cannot be represented as UTF-8."
            } else {
                validationError = "Invalid Base64 string."
                outputText = "// Error: Invalid Base64 input string."
            }
        case .urlEncode:
            outputText = inputText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? inputText
        case .urlDecode:
            outputText = inputText.removingPercentEncoding ?? inputText
        case .htmlEntityEncode:
            outputText = inputText
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
        case .jsonToYAML:
            outputText = convertJSONToYAML(json: inputText)
        case .jsonToXML:
            outputText = convertJSONToXML(json: inputText)
        case .csvToJSON:
            outputText = convertCSVToJSON(csv: inputText)
        case .hexToRGB:
            outputText = convertHEXToRGB(hex: inputText)
        }
    }

    func copyOutputToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        JuicerHaptic.performSuccess()
        withAnimation { showCopyToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { self.showCopyToast = false }
        }
    }

    func loadSampleData() {
        switch selectedCategory {
        case .codeSchemas, .dataFormats:
            inputText = "{\n  \"id\": 101,\n  \"title\": \"Juicer Studio\",\n  \"tags\": [\"swift\", \"macos\"],\n  \"enabled\": true\n}"
        case .encodings:
            inputText = "Juicer Offline Converter Studio 2026"
        case .colors:
            inputText = "#007AFF"
        case .batchFiles:
            break
        }
    }

    func clearInput() {
        inputText = ""
        outputText = ""
        validationError = nil
    }

    func handleDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    if self.selectedCategory == .batchFiles {
                        self.batchItems.append(BatchConversionItem(url: url, status: .pending))
                    } else if let content = try? String(contentsOf: url) {
                        self.inputText = content
                    }
                }
            }
        }
        return true
    }

    private func parseJSONDictionary(_ json: String) -> [String: Any]? {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            validationError = "Invalid JSON Object Syntax"
            return nil
        }
        return dict
    }

    private func convertJSONToSwift(json: String) -> String {
        guard let dict = parseJSONDictionary(json) else { return "// Error: Please provide a valid JSON object." }
        var code = "struct GeneratedModel: Codable {\n"
        for (key, val) in dict.sorted(by: { $0.key < $1.key }) {
            let swiftType: String
            if val is String { swiftType = "String" } else if val is Bool { swiftType = "Bool" } else if val is Int { swiftType = "Int" } else if val is Double { swiftType = "Double" } else if val is [Any] { swiftType = "[String]" } else { swiftType = "AnyCodable" }
            code += "    let \(key): \(swiftType)\n"
        }
        code += "}"
        return code
    }

    private func convertJSONToTS(json: String) -> String {
        guard let dict = parseJSONDictionary(json) else { return "// Error: Please provide a valid JSON object." }
        var code = "export interface GeneratedModel {\n"
        for (key, val) in dict.sorted(by: { $0.key < $1.key }) {
            let tsType: String
            if val is String { tsType = "string" } else if val is Int || val is Double { tsType = "number" } else if val is Bool { tsType = "boolean" } else if val is [Any] { tsType = "any[]" } else { tsType = "any" }
            code += "  \(key): \(tsType);\n"
        }
        code += "}"
        return code
    }

    private func convertJSONToGo(json: String) -> String {
        guard let dict = parseJSONDictionary(json) else { return "// Error: Please provide a valid JSON object." }
        var code = "type GeneratedModel struct {\n"
        for (key, val) in dict.sorted(by: { $0.key < $1.key }) {
            let goType: String
            if val is String { goType = "string" } else if val is Int { goType = "int" } else if val is Double { goType = "float64" } else if val is Bool { goType = "bool" } else { goType = "interface{}" }
            let fieldName = key.capitalized
            code += "    \(fieldName) \(goType) `json:\"\(key)\"`\n"
        }
        code += "}"
        return code
    }

    private func convertJSONToPython(json: String) -> String {
        guard let dict = parseJSONDictionary(json) else { return "# Error: Please provide a valid JSON object." }
        var code = "from dataclasses import dataclass\nfrom typing import Any, List\n\n@dataclass\nclass GeneratedModel:\n"
        for (key, val) in dict.sorted(by: { $0.key < $1.key }) {
            let pyType: String
            if val is String { pyType = "str" } else if val is Int { pyType = "int" } else if val is Double { pyType = "float" } else if val is Bool { pyType = "bool" } else { pyType = "Any" }
            code += "    \(key): \(pyType)\n"
        }
        return code
    }

    private func convertJSONToYAML(json: String) -> String {
        guard let dict = parseJSONDictionary(json) else { return "# Error: Invalid JSON" }
        var yaml = "---\n"
        for (key, val) in dict {
            yaml += "\(key): \(val)\n"
        }
        return yaml
    }

    private func convertJSONToXML(json: String) -> String {
        guard let dict = parseJSONDictionary(json) else { return "<!-- Error: Invalid JSON -->" }
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root>\n"
        for (key, val) in dict {
            xml += "  <\(key)>\(val)</\(key)>\n"
        }
        xml += "</root>"
        return xml
    }

    private func convertCSVToJSON(csv: String) -> String {
        let lines = csv.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard let headerLine = lines.first else { return "[]" }
        let headers = headerLine.components(separatedBy: ",")
        var results: [[String: String]] = []
        for line in lines.dropFirst() {
            let values = line.components(separatedBy: ",")
            var row: [String: String] = [:]
            for (idx, header) in headers.enumerated() {
                row[header.trimmingCharacters(in: .whitespaces)] = idx < values.count ? values[idx].trimmingCharacters(in: .whitespaces) : ""
            }
            results.append(row)
        }
        if let data = try? JSONSerialization.data(withJSONObject: results, options: .prettyPrinted) {
            return String(data: data, encoding: .utf8) ?? "[]"
        }
        return "[]"
    }

    private func convertHEXToRGB(hex: String) -> String {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if cleanHex.count == 3 {
            cleanHex = cleanHex.map { "\($0)\($0)" }.joined()
        }
        guard cleanHex.count == 6, let rgb = UInt32(cleanHex, radix: 16) else {
            validationError = "Invalid HEX color format (use #RRGGBB)"
            return "// Error: Enter a valid 6-digit hex string like #007AFF"
        }
        let r = Int((rgb >> 16) & 0xFF)
        let g = Int((rgb >> 8) & 0xFF)
        let b = Int(rgb & 0xFF)
        return """
        RGB: rgb(\(r), \(g), \(b))
        RGBA: rgba(\(r), \(g), \(b), 1.0)
        Float: Red: \(String(format: "%.2f", Double(r)/255.0)), Green: \(String(format: "%.2f", Double(g)/255.0)), Blue: \(String(format: "%.2f", Double(b)/255.0))
        CSS Var: --color-custom: #\(cleanHex.uppercased());
        """
    }
}

// MARK: - Main Studio View
typealias converterstudioview = ConverterStudioView

struct ConverterStudioView: View {
    @StateObject private var viewModel = ConverterStudioViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            JuicerFeatureHeader(
                title: "Juicer Converter Studio",
                subtitle: "Offline converter for code schemas, text encodings, data formats, colors, and batch documents.",
                icon: "arrow.triangle.2.circlepath.doc.on.clipboard",
                refreshing: false,
                action: { viewModel.convertInput() }
            )
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

            Divider()

            // Category & Format Toolbar
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    ForEach(ConverterCategory.allCases) { cat in
                        Button(action: {
                            viewModel.selectedCategory = cat
                        }) {
                            Label(cat.rawValue, systemImage: cat.icon)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(viewModel.selectedCategory == cat ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                                .foregroundStyle(viewModel.selectedCategory == cat ? Color.accentColor : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                if viewModel.selectedCategory != .batchFiles {
                    Picker("Target Format:", selection: $viewModel.selectedMode) {
                        ForEach(viewModel.modesForCategory(viewModel.selectedCategory)) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 220)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))

            Divider()

            // Main Content Area
            if viewModel.selectedCategory == .batchFiles {
                batchFilesView
            } else {
                textStudioSplitView
            }
        }
        .onAppear { viewModel.convertInput() }
        .allowWindowDragAndFit()
    }

    private var textStudioSplitView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: viewModel.loadSampleData) {
                    Label("Sample Data", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: viewModel.clearInput) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                if let error = viewModel.validationError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(error).font(.caption).bold().foregroundStyle(.orange)
                    }
                }

                if viewModel.showCopyToast {
                    Text("✓ Copied to Clipboard!")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }

                Button(action: viewModel.copyOutputToClipboard) {
                    Label("Copy Output", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(viewModel.outputText.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            Divider()

            HSplitView {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Input Text").font(.headline)
                        Spacer()
                        Text("\(viewModel.inputText.count) chars")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ZStack(alignment: .center) {
                        TextEditor(text: $viewModel.inputText)
                            .font(.system(.body, design: .monospaced))
                            .padding(4)
                            .background(RoundedRectangle(cornerRadius: 8).stroke(viewModel.isTargetedForDrop ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: viewModel.isTargetedForDrop ? 2 : 1))

                        if viewModel.inputText.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.down.doc.fill")
                                    .font(.title)
                                    .foregroundStyle(.tertiary)
                                Text("Type, paste, or drop a file here")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                            }
                            .allowsHitTesting(false)
                        }
                    }
                    .onDrop(of: [.fileURL], isTargeted: $viewModel.isTargetedForDrop) { providers in
                        viewModel.handleDroppedFiles(providers)
                    }
                }
                .padding()

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Converted Output").font(.headline)
                        Spacer()
                        Text("\(viewModel.outputText.count) chars")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    TextEditor(text: .constant(viewModel.outputText))
                        .font(.system(.body, design: .monospaced))
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                }
                .padding()
            }
        }
    }

    private var batchFilesView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down.on.square.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                Text("Drag & Drop Files for Batch Processing")
                    .font(.headline)
                Text("Drop JSON, XML, CSV, or Text documents to convert them in bulk.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .foregroundStyle(viewModel.isTargetedForDrop ? Color.accentColor : Color.secondary.opacity(0.4))
                    .background(viewModel.isTargetedForDrop ? Color.accentColor.opacity(0.08) : Color.clear)
            )
            .padding()
            .onDrop(of: [.fileURL], isTargeted: $viewModel.isTargetedForDrop) { providers in
                viewModel.handleDroppedFiles(providers)
            }

            if viewModel.batchItems.isEmpty {
                JuicerEmptyState(title: "No Files Queued", detail: "Drop files above to begin batch conversion.")
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.batchItems) { item in
                        HStack {
                            Image(systemName: "doc.fill").foregroundStyle(.tint)
                            Text(item.url.lastPathComponent).font(.body.weight(.medium))
                            Spacer()
                            Text(item.url.pathExtension.uppercased())
                                .font(.caption.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}
