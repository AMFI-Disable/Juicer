import SwiftUI
import Foundation

struct speedtestview: View {
    private let endpoint = "https://speed.cloudflare.com/__down?bytes=10000000"
    @State private var state: ReliabilityOperationState = .idle
    @State private var message = "No test run."
    @State private var lastUpdated: Date?
    @State private var task: Task<Void, Never>?
    @State private var startedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            JuicerFeatureHeader(title: "Speed Test Tool", subtitle: "Measure real download throughput through Cloudflare's public speed endpoint.", icon: "speedometer", refreshing: state == .running, action: test)
            HStack(spacing: 10) {
                Button(state == .failed || state == .timedOut ? "Retry Speed Test" : "Run Speed Test") { test() }
                    .buttonStyle(.borderedProminent)
                    .disabled(state == .running)
                if state == .running { Button("Cancel") { cancel() }.buttonStyle(.bordered) }
                if state != .idle && state != .running { Button("Dismiss") { state = .idle; message = "No test run." }.buttonStyle(.bordered) }
            }
            if state == .running {
                ProgressView(value: nil, total: 1)
                Text("Downloading test payload… (elapsedText)").font(.caption).foregroundStyle(.secondary)
            }
            Text(message).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            Text("Endpoint: (endpoint)").font(.caption).foregroundStyle(.secondary)
            if let lastUpdated { Text("Last updated (lastUpdated.formatted(date: .omitted, time: .standard))").font(.caption).foregroundStyle(.secondary) }
            Spacer()
        }
        .padding(24)
        .onDisappear { cancel() }
    }

    private var elapsedText: String {
        guard let startedAt else { return "" }
        return String(format: "%.1fs", Date().timeIntervalSince(startedAt))
    }

    private func cancel() {
        guard state == .running else { return }
        task?.cancel()
        task = nil
        state = .cancelled
        message = "Speed test cancelled. The request was aborted."
        lastUpdated = Date()
    }

    private func test() {
        guard state != .running else { return }
        task?.cancel()
        state = .running
        startedAt = Date()
        message = "Connecting to the speed-test endpoint…"
        task = Task {
            do {
                guard var components = URLComponents(string: endpoint) else { throw URLError(.badURL) }
                components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "cacheBust", value: UUID().uuidString)]
                guard let url = components.url else { throw URLError(.badURL) }
                var request = URLRequest(url: url)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.timeoutInterval = 30
                request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                request.setValue("Juicer-Speed-Test/1.0", forHTTPHeaderField: "User-Agent")
                let configuration = URLSessionConfiguration.ephemeral
                configuration.waitsForConnectivity = false
                configuration.timeoutIntervalForRequest = 30
                configuration.timeoutIntervalForResource = 45
                let session = URLSession(configuration: configuration)
                defer { session.invalidateAndCancel() }
                let started = Date()
                let (data, response) = try await session.data(for: request)
                try Task.checkCancellation()
                let elapsed = max(0.001, Date().timeIntervalSince(started))
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
                let summary = SpeedTestSummary(endpoint: endpoint, bytes: data.count, elapsed: elapsed, statusCode: http.statusCode)
                await MainActor.run {
                    state = .succeeded
                    message = String(format: "Downloaded %.2f MB in %.2f s\nEstimated download speed: %.2f Mbps\nHTTP status: %d", Double(summary.bytes) / 1_000_000, summary.elapsed, summary.megabitsPerSecond, summary.statusCode)
                    lastUpdated = Date(); task = nil
                }
            } catch is CancellationError {
                await MainActor.run { if state == .running { state = .cancelled; message = "Speed test cancelled. The request was aborted."; lastUpdated = Date() }; task = nil }
            } catch {
                await MainActor.run { if state == .running { state = (error as? URLError)?.code == .timedOut ? .timedOut : .failed; message = "Speed test failed: (error.localizedDescription). Retry when the endpoint is reachable."; lastUpdated = Date() }; task = nil }
            }
        }
    }
}
