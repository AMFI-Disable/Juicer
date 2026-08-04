import SwiftUI
import AppKit

typealias dockerstudioview = DockerStudioView

struct DockerStudioView: View {
    @StateObject private var dockerManager = DockerManager.shared
    @State private var selectedTab = "Containers"
    @State private var searchText = ""
    @State private var statusFilter: ContainerFilter = .all
    @State private var selectedContainerID: String?
    @State private var logOutput: String = ""
    @State private var isAutoScrollEnabled = true
    @State private var logFilterText = ""
    @State private var containerToDelete: DockerContainer?
    
    enum ContainerFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case running = "Running"
        case stopped = "Stopped"
        var id: String { rawValue }
    }

    var filteredContainers: [DockerContainer] {
        dockerManager.containers.filter { container in
            let matchesSearch = searchText.isEmpty || 
                container.name.localizedCaseInsensitiveContains(searchText) ||
                container.image.localizedCaseInsensitiveContains(searchText) ||
                container.id.localizedCaseInsensitiveContains(searchText)
            
            switch statusFilter {
            case .all: return matchesSearch
            case .running: return matchesSearch && container.isRunning
            case .stopped: return matchesSearch && !container.isRunning
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            JuicerFeatureHeader(
                title: "Juicer Docker Studio",
                subtitle: "Inspect containers, stream logs, manage stacks, and reclaim disk space.",
                icon: "cube.fill",
                refreshing: dockerManager.isRefreshing,
                action: { dockerManager.refreshAll() }
            )
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

            Divider()

            HStack(spacing: 12) {
                Picker("", selection: $selectedTab) {
                    Text("Containers (\(dockerManager.containers.count))").tag("Containers")
                    Text("Log Streamer").tag("Logs")
                    Text("Disk Reclaimer").tag("Prune")
                }
                .pickerStyle(.segmented)
                .frame(width: 340)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(dockerManager.isDaemonRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(dockerManager.isDaemonRunning ? "Daemon Active" : "Daemon Offline")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            switch selectedTab {
            case "Containers":
                containersView
            case "Logs":
                logStreamerView
            case "Prune":
                diskReclaimerView
            default:
                EmptyView()
            }
        }
        .onAppear {
            dockerManager.ensureInitialized()
        }
        .allowWindowDragAndFit()
        .confirmationDialog(
            "Remove Container?",
            isPresented: Binding(get: { containerToDelete != nil }, set: { if !$0 { containerToDelete = nil } }),
            presenting: containerToDelete
        ) { container in
            Button("Remove Container \(container.name)", role: .destructive) {
                dockerManager.removeContainer(id: container.id)
            }
        } message: { container in
            Text("Are you sure you want to forcibly remove '\(container.name)' (\(container.id))?")
        }
    }

    @ViewBuilder
    private var containersView: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Filter", selection: $statusFilter) {
                    ForEach(ContainerFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Spacer()

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search containers...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .frame(width: 220)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if filteredContainers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(dockerManager.isDaemonRunning ? "No matching containers found." : "Docker daemon is not running.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Button("Refresh Status") { dockerManager.refreshAll() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredContainers) { container in
                    containerRow(container)
                }
                .listStyle(.inset)
            }
        }
    }

    @ViewBuilder
    private func containerRow(_ container: DockerContainer) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(container.isRunning ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(container.name).font(.headline)
                    Text(String(container.id.prefix(12)))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text(container.image)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !container.ports.isEmpty {
                        Text(container.ports)
                            .font(.caption2.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if let mappedPort = extractMappedPort(from: container.ports) {
                    Button(action: {
                        let urlStr = "http://localhost:\(mappedPort)"
                        StudioContextBridgeManager.shared.testEndpointInAPIStudio(urlString: urlStr, sourceStudio: .containers)
                    }) {
                        Label("Test Endpoint in API Studio", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Jump to API Studio to test HTTP endpoint http://localhost:\(mappedPort)")
                } else {
                    Button(action: {
                        let urlStr = "http://localhost:8080"
                        StudioContextBridgeManager.shared.testEndpointInAPIStudio(urlString: urlStr, sourceStudio: .containers)
                    }) {
                        Label("Test Endpoint in API Studio", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Jump to API Studio to test container HTTP endpoints")
                }

                Button(action: {
                    selectedContainerID = container.id
                    selectedTab = "Logs"
                    fetchLogs(for: container.id)
                }) {
                    Label("Logs", systemImage: "text.alignleft")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if container.isRunning {
                    Button(action: { dockerManager.stopContainer(id: container.id) }) {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .controlSize(.small)
                } else {
                    Button(action: { dockerManager.startContainer(id: container.id) }) {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)
                }

                Menu {
                    Button("Inspect Sockets in Network Studio") {
                        StudioContextBridgeManager.shared.inspectSocketsInNetworkStudio(query: container.name, sourceStudio: .containers)
                    }
                    Divider()
                    Button("Restart Container") { dockerManager.restartContainer(id: container.id) }
                    Button("Copy Container ID") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(container.id, forType: .string) }
                    Divider()
                    Button("Remove Container", role: .destructive) { containerToDelete = container }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
            }
        }
        .padding(.vertical, 4)
    }

    private func extractMappedPort(from portsString: String) -> String? {
        let pattern = #"(\d+)->"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: portsString, range: NSRange(portsString.startIndex..., in: portsString)),
           let range = Range(match.range(at: 1), in: portsString) {
            return String(portsString[range])
        }
        let digitsPattern = #"^(\d+)"#
        if let regex = try? NSRegularExpression(pattern: digitsPattern),
           let match = regex.firstMatch(in: portsString, range: NSRange(portsString.startIndex..., in: portsString)),
           let range = Range(match.range(at: 1), in: portsString) {
            return String(portsString[range])
        }
        return nil
    }

    @ViewBuilder
    private var logStreamerView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Container:").font(.subheadline).foregroundStyle(.secondary)
                Picker("", selection: $selectedContainerID) {
                    Text("Select a Container").tag(Optional<String>.none)
                    ForEach(dockerManager.containers) { c in
                        Text("\(c.name) (\(c.image))").tag(Optional(c.id))
                    }
                }
                .frame(width: 260)
                .onChange(of: selectedContainerID) { newID in
                    if let id = newID { fetchLogs(for: id) }
                }

                Spacer()

                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(.secondary)
                    TextField("Filter logs...", text: $logFilterText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .frame(width: 180)

                Button(action: { if let id = selectedContainerID { fetchLogs(for: id) } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    Text(filteredLogOutput)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .id("LogBottom")
                }
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal)
                .onChange(of: logOutput) { _ in
                    if isAutoScrollEnabled {
                        withAnimation { proxy.scrollTo("LogBottom", anchor: .bottom) }
                    }
                }
            }
        }
        .padding(.bottom, 8)
    }

    private var filteredLogOutput: String {
        if logOutput.isEmpty { return "Select a container above to inspect output logs." }
        if logFilterText.isEmpty { return logOutput }
        return logOutput.components(separatedBy: .newlines)
            .filter { $0.localizedCaseInsensitiveContains(logFilterText) }
            .joined(separator: "\n")
    }

    private func fetchLogs(for id: String) {
        guard let path = URL(string: dockerManager.dockerPath)?.path, !path.isEmpty else { return }
        Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["logs", "--tail", "200", id]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try? process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? "No log output."
            await MainActor.run { logOutput = text }
        }
    }

    @ViewBuilder
    private var diskReclaimerView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.red)
                Text("Docker Disk Space Reclaimer")
                    .font(.title2.bold())
                Text("Clean dangling build caches, stopped containers, and unused volumes to free up disk space.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                reclaimCard(title: "Build Cache", icon: "hammer.fill", action: { dockerManager.purgeBuildCache() })
                reclaimCard(title: "Stopped Containers", icon: "cube.transparent", action: { dockerManager.purgeStoppedContainers() })
                reclaimCard(title: "Unused Images", icon: "photo.stack", action: { dockerManager.purgeImages() })
                reclaimCard(title: "Volumes", icon: "internaldrive", action: { dockerManager.purgeVolumes() })
            }
            .padding(.horizontal)

            Divider()

            Button("Purge All Docker Resources") {
                dockerManager.purgeEverything()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func reclaimCard(title: String, icon: String, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
            }
            Spacer()
            Button("Purge", action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(8)
    }
}
