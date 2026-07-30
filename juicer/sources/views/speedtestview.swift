import SwiftUI
import Foundation

struct speedtestview: View {
    @State private var result = ""
    @State private var running = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            JuicerFeatureHeader(title: "Speed Test Tool", subtitle: "Measure real download throughput through Cloudflare's public speed endpoint.", icon: "speedometer", refreshing: running, action: test)
            HStack(spacing: 10) {
                Button("Run Speed Test") { test() }
                    .buttonStyle(.borderedProminent)
                    .disabled(running)
                if running {
                    Button("Cancel") { task?.cancel() }
                        .buttonStyle(.bordered)
                }
            }
            if running {
                ProgressView("Downloading a test payload…")
            }
            Text(result.isEmpty ? "No test run." : result)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
            Text("The result depends on your current connection, VPN, Wi-Fi conditions, and the selected test endpoint.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
        .onDisappear { task?.cancel() }
    }

    private func test() {
        task?.cancel()
        running = true
        result = "Connecting to the speed-test endpoint…"

        task = Task {
            do {
                guard let baseURL = URL(string: "https://speed.cloudflare.com/__down?bytes=10000000") else { throw URLError(.badURL) }
                var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
                components?.queryItems?.append(URLQueryItem(name: "cacheBust", value: UUID().uuidString))
                guard let url = components?.url else { throw URLError(.badURL) }

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

                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }

                let megabytes = Double(data.count) / 1_000_000
                let megabitsPerSecond = Double(data.count * 8) / elapsed / 1_000_000
                await MainActor.run {
                    result = String(format: "Downloaded %.2f MB in %.2f s\nEstimated download speed: %.2f Mbps\nHTTP status: %d", megabytes, elapsed, megabitsPerSecond, http.statusCode)
                    running = false
                    task = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    result = "Speed test cancelled."
                    running = false
                    task = nil
                }
            } catch {
                await MainActor.run {
                    result = "Speed test failed: \(error.localizedDescription)"
                    running = false
                    task = nil
                }
            }
        }
    }
}
