import SwiftUI
import AppKit

// MARK: - Data Models
struct HTTPHeaderPair: Identifiable, Equatable {
    let id = UUID()
    var key: String
    var value: String
    var isEnabled: Bool = true
}

struct URLParamPair: Identifiable, Equatable {
    let id = UUID()
    var key: String
    var value: String
    var isEnabled: Bool = true
}

struct APIHistoryRecord: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let method: String
    let urlString: String
    let statusCode: Int?
    let statusText: String
    let durationMs: Double
    let responseBody: String
}

// MARK: - cURL Parser & Generator Utility
enum cURLUtility {
    static func parse(curlCommand: String) -> (method: String, url: String, headers: [HTTPHeaderPair], body: String)? {
        let trimmed = curlCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("curl") else { return nil }

        var method = "GET"
        var urlString = ""
        var headers: [HTTPHeaderPair] = []
        var body = ""

        let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        if let xIdx = tokens.firstIndex(where: { $0 == "-X" || $0 == "--request" }), xIdx + 1 < tokens.count {
            method = tokens[xIdx + 1].replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\"", with: "").uppercased()
        }

        var i = 0
        while i < tokens.count {
            let tok = tokens[i]
            if (tok == "-H" || tok == "--header") && i + 1 < tokens.count {
                let headerStr = tokens[i+1].trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                let parts = headerStr.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if parts.count == 2 {
                    headers.append(HTTPHeaderPair(key: parts[0], value: parts[1], isEnabled: true))
                }
                i += 2
                continue
            }
            if (tok == "-d" || tok == "--data" || tok == "--data-raw") && i + 1 < tokens.count {
                body = tokens[i+1].trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                if method == "GET" { method = "POST" }
                i += 2
                continue
            }
            if (tok.hasPrefix("http://") || tok.hasPrefix("https://")) && urlString.isEmpty {
                urlString = tok.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            }
            i += 1
        }

        if urlString.isEmpty {
            if let range = trimmed.range(of: #"https?://[^\s'"]+"#, options: .regularExpression) {
                urlString = String(trimmed[range])
            }
        }

        guard !urlString.isEmpty else { return nil }
        return (method, urlString, headers, body)
    }

    static func generatecURL(method: String, url: String, headers: [HTTPHeaderPair], body: String) -> String {
        var components = ["curl -X \(method) \"\(url)\""]
        for h in headers where h.isEnabled && !h.key.isEmpty {
            components.append("-H \"\(h.key): \(h.value)\"")
        }
        if !body.isEmpty && (method == "POST" || method == "PUT" || method == "PATCH") {
            let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
            components.append("-d \"\(escapedBody)\"")
        }
        return components.joined(separator: " \\\n  ")
    }
}

// MARK: - Main API Studio View
typealias apistudioview = APIStudioView

struct APIStudioView: View {
    @State private var httpMethod = "GET"
    @State private var urlString = "https://api.github.com/zen"
    
    // Request Inspector Tabs
    @State private var inspectorTab = "Headers"
    @State private var paramsList: [URLParamPair] = [
        URLParamPair(key: "format", value: "json", isEnabled: false)
    ]
    @State private var headersList: [HTTPHeaderPair] = [
        HTTPHeaderPair(key: "User-Agent", value: "Juicer-API-Studio/1.0", isEnabled: true),
        HTTPHeaderPair(key: "Accept", value: "application/json", isEnabled: true)
    ]
    @State private var requestBody = ""
    @State private var authToken = ""
    
    // Response Inspector
    @State private var responseBody = ""
    @State private var statusCode = ""
    @State private var statusCodeValue: Int? = nil
    @State private var responseDurationMs: Double = 0
    @State private var responseSizeBytes: Int = 0
    @State private var responseHeaders: [HTTPHeaderPair] = []
    @State private var responseViewMode = "Pretty"
    @State private var isExecuting = false

    // Modals & Tabs
    @State private var selectedTab = "Workbench"
    @State private var showCurlImportSheet = false
    @State private var curlInputText = ""
    
    // Request History Storage
    @State private var historyRecords: [APIHistoryRecord] = []
    
    // Benchmark state
    @State private var benchmarkCount = "10"
    @State private var benchmarkResults = ""

    var body: some View {
        VStack(spacing: 0) {
            JuicerFeatureHeader(
                title: "Juicer API & HTTP Studio",
                subtitle: "Native REST workbench, cURL importer/exporter, header inspector, & load benchmarker.",
                icon: "paperplane.fill",
                refreshing: isExecuting,
                action: { sendRequest() }
            )
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

            Divider()

            HStack {
                Picker("", selection: $selectedTab) {
                    Text("REST Workbench").tag("Workbench")
                    Text("Load Benchmarker").tag("Benchmark")
                    Text("History (\(historyRecords.count))").tag("History")
                }
                .pickerStyle(.segmented)
                .frame(width: 380)

                Spacer()

                if selectedTab == "Workbench" {
                    Button(action: { showCurlImportSheet = true }) {
                        Label("Import cURL", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: { copyAsCurl() }) {
                        Label("Copy cURL", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if selectedTab == "Workbench" {
                workbenchView()
            } else if selectedTab == "Benchmark" {
                benchmarkView()
            } else {
                historyView()
            }
        }
        .sheet(isPresented: $showCurlImportSheet) {
            curlImportModal()
        }
        .allowWindowDragAndFit()
    }

    @ViewBuilder
    private func workbenchView() -> some View {
        VSplitView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Picker("", selection: $httpMethod) {
                        Text("GET").tag("GET")
                        Text("POST").tag("POST")
                        Text("PUT").tag("PUT")
                        Text("PATCH").tag("PATCH")
                        Text("DELETE").tag("DELETE")
                        Text("HEAD").tag("HEAD")
                    }
                    .frame(width: 100)

                    TextField("https://api.example.com/v1/resource", text: $urlString)
                        .textFieldStyle(.roundedBorder)

                    Button(action: sendRequest) {
                        HStack {
                            if isExecuting {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text("Send")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isExecuting || urlString.isEmpty)
                }

                Picker("", selection: $inspectorTab) {
                    Text("Params (\(paramsList.filter { $0.isEnabled && !$0.key.isEmpty }.count))").tag("Params")
                    Text("Headers (\(headersList.filter { $0.isEnabled && !$0.key.isEmpty }.count))").tag("Headers")
                    Text("Body").tag("Body")
                    Text("Auth").tag("Auth")
                }
                .pickerStyle(.segmented)

                Group {
                    if inspectorTab == "Params" {
                        paramsEditorView()
                    } else if inspectorTab == "Headers" {
                        headersEditorView()
                    } else if inspectorTab == "Body" {
                        bodyEditorView()
                    } else {
                        authEditorView()
                    }
                }
                .frame(maxHeight: 140)
            }
            .padding()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Response Inspector").font(.headline)

                    if let code = statusCodeValue {
                        Text("\(code) \(statusCode)")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(code >= 200 && code < 300 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                            .foregroundColor(code >= 200 && code < 300 ? .green : .red)
                            .cornerRadius(6)

                        Text("\(Int(responseDurationMs)) ms")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(ByteCountFormatter.string(fromByteCount: Int64(responseSizeBytes), countStyle: .file))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Picker("", selection: $responseViewMode) {
                        Text("Pretty JSON").tag("Pretty")
                        Text("Raw Text").tag("Raw")
                        Text("Headers (\(responseHeaders.count))").tag("Headers")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 250)
                }

                if responseViewMode == "Headers" {
                    List(responseHeaders) { h in
                        HStack {
                            Text(h.key).bold().frame(width: 160, alignment: .leading)
                            Text(h.value).foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                    .listStyle(.inset)
                } else {
                    ScrollView {
                        Text(formattedResponseBody)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
                }
            }
            .padding()
        }
    }

    private var formattedResponseBody: String {
        if responseBody.isEmpty {
            return "Response payload will appear here after sending a request..."
        }
        if responseViewMode == "Pretty",
           let data = responseBody.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let prettyStr = String(data: prettyData, encoding: .utf8) {
            return prettyStr
        }
        return responseBody
    }

    @ViewBuilder
    private func headersEditorView() -> some View {
        VStack(spacing: 6) {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach($headersList) { $header in
                        HStack {
                            Toggle("", isOn: $header.isEnabled).labelsHidden()
                            TextField("Header Key", text: $header.key).textFieldStyle(.roundedBorder)
                            TextField("Value", text: $header.value).textFieldStyle(.roundedBorder)
                            Button(action: { headersList.removeAll { $0.id == header.id } }) {
                                Image(systemName: "minus.circle.fill").foregroundColor(.red)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            Button("+ Add Header") {
                headersList.append(HTTPHeaderPair(key: "", value: "", isEnabled: true))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func paramsEditorView() -> some View {
        VStack(spacing: 6) {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach($paramsList) { $param in
                        HStack {
                            Toggle("", isOn: $param.isEnabled).labelsHidden()
                            TextField("Param Key", text: $param.key).textFieldStyle(.roundedBorder)
                            TextField("Value", text: $param.value).textFieldStyle(.roundedBorder)
                            Button(action: { paramsList.removeAll { $0.id == param.id } }) {
                                Image(systemName: "minus.circle.fill").foregroundColor(.red)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            Button("+ Add Parameter") {
                paramsList.append(URLParamPair(key: "", value: "", isEnabled: true))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func bodyEditorView() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("HTTP Request Payload (JSON / Plain Text)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Format JSON") {
                    if let data = requestBody.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data),
                       let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
                       let prettyStr = String(data: prettyData, encoding: .utf8) {
                        requestBody = prettyStr
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            TextEditor(text: $requestBody)
                .font(.system(.body, design: .monospaced))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
        }
    }

    @ViewBuilder
    private func authEditorView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Authorization Header Helper").font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("Bearer Token:").bold()
                SecureField("e.g. eyJhbGciOi...", text: $authToken)
                    .textFieldStyle(.roundedBorder)
                Button("Apply Auth Header") {
                    if !authToken.isEmpty {
                        headersList.removeAll { $0.key.lowercased() == "authorization" }
                        headersList.append(HTTPHeaderPair(key: "Authorization", value: "Bearer \(authToken)", isEnabled: true))
                        inspectorTab = "Headers"
                    }
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func historyView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Request History Log").font(.headline)
                Spacer()
                if !historyRecords.isEmpty {
                    Button("Clear History") { historyRecords.removeAll() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            if historyRecords.isEmpty {
                JuicerEmptyState(title: "No Request History", detail: "Executed API calls will be logged here for rapid re-testing.")
            } else {
                List(historyRecords) { rec in
                    HStack(spacing: 12) {
                        Text(rec.method)
                            .bold()
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(methodColor(rec.method).opacity(0.2))
                            .foregroundColor(methodColor(rec.method))
                            .cornerRadius(4)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(rec.urlString).lineLimit(1).bold()
                            Text(rec.timestamp.formatted(date: .numeric, time: .standard))
                                .font(.caption2).foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let code = rec.statusCode {
                            Text("\(code)")
                                .font(.caption.bold())
                                .foregroundColor(code >= 200 && code < 300 ? .green : .red)
                        }

                        Text("\(Int(rec.durationMs)) ms")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Load") {
                            httpMethod = rec.method
                            urlString = rec.urlString
                            selectedTab = "Workbench"
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func benchmarkView() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Endpoint Load & Latency Benchmarker").font(.headline)
                Spacer()
                Text("Total Requests:")
                TextField("Count", text: $benchmarkCount)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Button("Run Benchmark") { runBenchmark() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isExecuting)
            }

            ScrollView {
                Text(benchmarkResults.isEmpty ? "Click 'Run Benchmark' to execute rapid endpoint metrics..." : benchmarkResults)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
        }
        .padding()
    }

    @ViewBuilder
    private func curlImportModal() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import cURL Command").font(.title3.bold())
            Text("Paste a cURL command below to automatically populate the URL, method, headers, and body payload.")
                .font(.caption).foregroundStyle(.secondary)

            TextEditor(text: $curlInputText)
                .font(.system(.body, design: .monospaced))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))

            HStack {
                Button("Cancel") { showCurlImportSheet = false }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Parse & Import") {
                    if let parsed = cURLUtility.parse(curlCommand: curlInputText) {
                        httpMethod = parsed.method
                        urlString = parsed.url
                        if !parsed.headers.isEmpty { headersList = parsed.headers }
                        if !parsed.body.isEmpty {
                            requestBody = parsed.body
                            inspectorTab = "Body"
                        }
                        showCurlImportSheet = false
                        curlInputText = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(curlInputText.isEmpty)
            }
        }
        .padding()
        .frame(width: 520, height: 320)
    }

    private func sendRequest() {
        guard var urlComponents = URLComponents(string: urlString) else { return }
        
        var queryItems = urlComponents.queryItems ?? []
        for p in paramsList where p.isEnabled && !p.key.isEmpty {
            queryItems.append(URLQueryItem(name: p.key, value: p.value))
        }
        if !queryItems.isEmpty { urlComponents.queryItems = queryItems }
        
        guard let finalURL = urlComponents.url else { return }

        isExecuting = true
        responseBody = "Connecting..."
        statusCode = ""
        statusCodeValue = nil
        responseHeaders.removeAll()

        var request = URLRequest(url: finalURL)
        request.httpMethod = httpMethod
        
        for h in headersList where h.isEnabled && !h.key.isEmpty {
            request.setValue(h.value, forHTTPHeaderField: h.key)
        }
        
        if !requestBody.isEmpty && (httpMethod == "POST" || httpMethod == "PUT" || httpMethod == "PATCH") {
            request.httpBody = requestBody.data(using: .utf8)
        }

        let startTime = Date()

        URLSession.shared.dataTask(with: request) { data, response, error in
            let duration = Date().timeIntervalSince(startTime) * 1000.0

            DispatchQueue.main.async {
                isExecuting = false
                responseDurationMs = duration

                if let httpResponse = response as? HTTPURLResponse {
                    statusCodeValue = httpResponse.statusCode
                    statusCode = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                    
                    responseHeaders = httpResponse.allHeaderFields.compactMap { key, val in
                        HTTPHeaderPair(key: String(describing: key), value: String(describing: val), isEnabled: true)
                    }
                }

                if let data = data {
                    responseSizeBytes = data.count
                    responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode text payload"
                } else if let error = error {
                    responseBody = "Error: \(error.localizedDescription)"
                }

                historyRecords.insert(APIHistoryRecord(
                    timestamp: Date(),
                    method: httpMethod,
                    urlString: finalURL.absoluteString,
                    statusCode: statusCodeValue,
                    statusText: statusCode,
                    durationMs: duration,
                    responseBody: responseBody
                ), at: 0)
            }
        }.resume()
    }

    private func copyAsCurl() {
        let curlStr = cURLUtility.generatecURL(method: httpMethod, url: urlString, headers: headersList, body: requestBody)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(curlStr, forType: .string)
    }

    private func methodColor(_ method: String) -> Color {
        switch method.uppercased() {
        case "GET": return .green
        case "POST": return .orange
        case "PUT": return .blue
        case "DELETE": return .red
        default: return .purple
        }
    }

    private func runBenchmark() {
        guard let count = Int(benchmarkCount), count > 0, let url = URL(string: urlString) else { return }
        isExecuting = true
        benchmarkResults = "Running \(count) requests to \(urlString)..."

        Task.detached {
            let start = Date()
            var successes = 0
            var failures = 0
            var latencies: [Double] = []
            
            let batchSize = 10
            var remaining = count

            while remaining > 0 {
                let currentBatch = min(remaining, batchSize)
                remaining -= currentBatch

                await withTaskGroup(of: (Bool, Double).self) { group in
                    for _ in 0..<currentBatch {
                        group.addTask {
                            let reqStart = Date()
                            var req = URLRequest(url: url)
                            req.httpMethod = self.httpMethod
                            do {
                                let (_, resp) = try await URLSession.shared.data(for: req)
                                let reqDur = Date().timeIntervalSince(reqStart) * 1000.0
                                let isSuccess = (resp as? HTTPURLResponse)?.statusCode ?? 500 < 400
                                return (isSuccess, reqDur)
                            } catch {
                                return (false, Date().timeIntervalSince(reqStart) * 1000.0)
                            }
                        }
                    }

                    for await (success, lat) in group {
                        latencies.append(lat)
                        if success { successes += 1 } else { failures += 1 }
                    }
                }
            }

            let elapsed = Date().timeIntervalSince(start)
            let rps = Double(count) / elapsed
            let avgLat = latencies.isEmpty ? 0 : latencies.reduce(0, +) / Double(latencies.count)
            let minLat = latencies.min() ?? 0
            let maxLat = latencies.max() ?? 0

            await MainActor.run {
                isExecuting = false
                benchmarkResults = """
                Benchmark Report
                =======================================
                Target URL:               \(urlString)
                HTTP Method:              \(httpMethod)
                Total Requests Executed:  \(count)
                Total Elapsed Time:       \(String(format: "%.3f", elapsed)) s
                Requests Per Second (RPS):\(String(format: "%.1f", rps)) req/s

                Status Breakdown:
                ---------------------------------------
                Successful Requests:      \(successes) (\(Int(Double(successes)/Double(count)*100))%)
                Failed / Error Requests:  \(failures)

                Latency Metrics (ms):
                ---------------------------------------
                Min Latency:              \(String(format: "%.1f", minLat)) ms
                Avg Latency:              \(String(format: "%.1f", avgLat)) ms
                Max Latency:              \(String(format: "%.1f", maxLat)) ms
                =======================================
                """
            }
        }
    }
}
