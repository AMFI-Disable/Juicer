import SwiftUI
import AppKit

final class LocalWebServerModel: ObservableObject {
    @Published var running = false
    @Published var message = ""
    @Published var exposure = ""
    private var process: Process?

    func start(folder: URL, port: String) {
        guard !running, let number = Int(port), (1...65535).contains(number), folder.isFileURL else {
            message = "Choose a folder and valid port."
            return
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        task.arguments = ["-m", "http.server", "\(number)", "--directory", folder.path]
        do {
            try task.run()
            process = task
            running = true
            message = "Serving http://127.0.0.1:\(number)"
            exposure = "Loopback only • directory: \(folder.path) • stop behavior: terminates this server process"
        } catch {
            message = error.localizedDescription
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        running = false
            message = "Server stopped."
            exposure = ""
    }
}

struct localwebserverview: View {
    @StateObject private var model = LocalWebServerModel()
    @State private var folder: URL?
    @State private var port = "8000"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            JuicerFeatureHeader(
                title: "Local Web Server",
                subtitle: "Serve a selected folder with Python's built-in HTTP server.",
                icon: "server.rack",
                refreshing: model.running,
                action: {}
            )

            HStack(spacing: 12) {
                Button("Choose Folder…") { choose() }
                TextField("Port", text: $port).frame(width: 90)
                Button(model.running ? "Stop" : "Start") {
                    if model.running {
                        model.stop()
                    } else if let folder {
                        model.start(folder: folder, port: port)
                    }
                }
                .buttonStyle(.borderedProminent)

                if model.running {
                    Button(action: {
                        let urlStr = "http://127.0.0.1:\(port)"
                        StudioContextBridgeManager.shared.testEndpointInAPIStudio(urlString: urlStr, sourceStudio: .developer)
                    }) {
                        Label("Test Endpoint in API Studio", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.bordered)
                    .help("Jump to API Studio to test HTTP requests on http://127.0.0.1:\(port)")
                }
            }

            if let folder {
                Text("Directory: \(folder.path)").font(.caption).foregroundStyle(.secondary)
            }

            Text(model.message).font(.caption)
            if !model.exposure.isEmpty { Text(model.exposure).font(.caption).foregroundStyle(.orange) }

            Spacer()
        }
        .padding(24)
        .onDisappear { model.stop() }
        .onAppear {
            if let payload = StudioContextBridgeManager.shared.pendingPayload, let f = payload.folderURL {
                folder = f
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: StudioContextBridgeManager.bridgeNotification)) { notification in
            if let payload = notification.userInfo?["payload"] as? ContextPayload, let f = payload.folderURL {
                folder = f
            }
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK {
            folder = panel.url
        }
    }
}
