import Foundation
import Combine

struct DockerContainer: Identifiable, Hashable {
    let id: String
    let name: String
    let image: String
    let status: String
    let state: String
    let created: String
    let ports: String

    var isRunning: Bool {
        state.lowercased() == "running" || status.lowercased().contains("up")
    }
}

struct DockerDiskUsage: Identifiable {
    let id = UUID()
    let type: String
    let totalCount: Int
    let activeCount: Int
    let size: String
    let reclaimable: String
}

final class DockerManager: ObservableObject {
    static let shared = DockerManager()

    @Published var isDockerInstalled = false
    @Published var isDaemonRunning = false
    @Published var dockerPath: String = ""
    @Published var containers: [DockerContainer] = []
    @Published var diskUsage: [DockerDiskUsage] = []
    @Published var isRefreshing = false
    @Published var statusMessage: String = ""
    @Published var totalReclaimableSpace: String = "0 B"

    private var isInitialized = false

    private init() {}

    func ensureInitialized() {
        guard !isInitialized else { return }
        isInitialized = true
        detectDocker()
    }

    func purgeMemory() {
        diskUsage.removeAll(keepingCapacity: false)
    }

    func detectDocker() {
        let candidates = [
            "/opt/homebrew/bin/docker",
            "/usr/local/bin/docker",
            NSHomeDirectory() + "/.orbstack/bin/docker",
            NSHomeDirectory() + "/.colima/bin/docker",
            "/usr/bin/docker"
        ]

        self.dockerPath = ""
        self.isDockerInstalled = false

        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                self.dockerPath = path
                self.isDockerInstalled = true
                break
            }
        }

        if !isDockerInstalled {
            let result = CommandExecutor.shared.run(
                executablePath: "/usr/bin/which",
                arguments: ["docker"],
                timeout: 5,
                category: .readOnly
            )
            if result.succeeded {
                let output = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                if output.hasPrefix("/") && FileManager.default.fileExists(atPath: output) {
                    self.dockerPath = output
                    self.isDockerInstalled = true
                }
            }
        }

        if !isDockerInstalled {
            self.statusMessage = "Docker CLI is not installed"
            self.isDaemonRunning = false
            return
        }

        refreshAll()
    }

    func refreshAll() {
        guard isDockerInstalled, !dockerPath.isEmpty else {
            DispatchQueue.main.async {
                self.isRefreshing = false
                self.isDaemonRunning = false
            }
            return
        }
        isRefreshing = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let daemonOk = self.checkDaemonStatus()
            let loadedContainers = daemonOk ? self.loadContainers() : []
            let loadedDiskUsage = daemonOk ? self.loadDiskUsage() : []

            DispatchQueue.main.async {
                self.isDaemonRunning = daemonOk
                self.containers = loadedContainers
                self.diskUsage = loadedDiskUsage
                self.statusMessage = daemonOk ? "Docker daemon connected" : "Docker daemon unreachable"
                self.isRefreshing = false
            }
        }
    }

    private func checkDaemonStatus() -> Bool {
        guard !dockerPath.isEmpty else { return false }
        let result = CommandExecutor.shared.run(
            executablePath: dockerPath,
            arguments: ["info"],
            timeout: 10,
            category: .readOnly
        )
        return result.succeeded
    }

    private func loadContainers() -> [DockerContainer] {
        guard !dockerPath.isEmpty else { return [] }
        let result = CommandExecutor.shared.run(
            executablePath: dockerPath,
            arguments: ["ps", "-a", "--format", "{{.ID}}||{{.Names}}||{{.Image}}||{{.Status}}||{{.State}}||{{.CreatedAt}}||{{.Ports}}"],
            timeout: 15,
            category: .readOnly
        )
        guard result.succeeded else { return [] }

        var items: [DockerContainer] = []
        let lines = result.standardOutput.components(separatedBy: .newlines)
        for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            let parts = line.components(separatedBy: "||")
            if parts.count >= 5 {
                let container = DockerContainer(
                    id: parts[0].trimmingCharacters(in: .whitespaces),
                    name: parts[1].trimmingCharacters(in: .whitespaces),
                    image: parts[2].trimmingCharacters(in: .whitespaces),
                    status: parts[3].trimmingCharacters(in: .whitespaces),
                    state: parts[4].trimmingCharacters(in: .whitespaces),
                    created: parts.count > 5 ? parts[5].trimmingCharacters(in: .whitespaces) : "",
                    ports: parts.count > 6 ? parts[6].trimmingCharacters(in: .whitespaces) : ""
                )
                items.append(container)
            }
        }
        return items
    }

    private func loadDiskUsage() -> [DockerDiskUsage] {
        guard !dockerPath.isEmpty else { return [] }
        let result = CommandExecutor.shared.run(
            executablePath: dockerPath,
            arguments: ["system", "df"],
            timeout: 15,
            category: .readOnly
        )
        guard result.succeeded else { return [] }

        var items: [DockerDiskUsage] = []
        let lines = result.standardOutput.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Images") || trimmed.hasPrefix("Containers") || trimmed.hasPrefix("Local Volumes") || trimmed.hasPrefix("Build Cache") {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                let isTwoWordType = trimmed.hasPrefix("Local Volumes") || trimmed.hasPrefix("Build Cache")
                let minParts = isTwoWordType ? 4 : 3
                if parts.count >= minParts {
                    let type = isTwoWordType && parts.count >= 2 ? "\(parts[0]) \(parts[1])" : parts[0]
                    let totalIdx = isTwoWordType ? 2 : 1
                    let activeIdx = isTwoWordType ? 3 : 2
                    let sizeIdx = isTwoWordType ? 4 : 3

                    let totalCount = totalIdx < parts.count ? (Int(parts[totalIdx]) ?? 0) : 0
                    let activeCount = activeIdx < parts.count ? (Int(parts[activeIdx]) ?? 0) : 0
                    let size = sizeIdx < parts.count ? parts[sizeIdx] : "0B"
                    let reclaimable = parts.count > (sizeIdx + 1) ? parts[parts.count - 1] : "0B"

                    let usage = DockerDiskUsage(
                        type: type,
                        totalCount: totalCount,
                        activeCount: activeCount,
                        size: size,
                        reclaimable: reclaimable
                    )
                    items.append(usage)
                }
            }
        }
        return items
    }

    // Container Actions
    func startContainer(id: String) {
        runDockerCommand(["start", id]) { [weak self] _ in self?.refreshAll() }
    }

    func stopContainer(id: String) {
        runDockerCommand(["stop", id]) { [weak self] _ in self?.refreshAll() }
    }

    func restartContainer(id: String) {
        runDockerCommand(["restart", id]) { [weak self] _ in self?.refreshAll() }
    }

    func removeContainer(id: String) {
        runDockerCommand(["rm", "-f", id]) { [weak self] _ in self?.refreshAll() }
    }

    // Purge Reclaimer Actions
    func purgeImages() {
        runDockerCommand(["image", "prune", "-a", "-f"]) { [weak self] _ in self?.refreshAll() }
    }

    func purgeStoppedContainers() {
        runDockerCommand(["container", "prune", "-f"]) { [weak self] _ in self?.refreshAll() }
    }

    func purgeVolumes() {
        runDockerCommand(["volume", "prune", "-f"]) { [weak self] _ in self?.refreshAll() }
    }

    func purgeBuildCache() {
        runDockerCommand(["builder", "prune", "-a", "-f"]) { [weak self] _ in self?.refreshAll() }
    }

    func purgeEverything() {
        runDockerCommand(["system", "prune", "-a", "--volumes", "-f"]) { [weak self] _ in self?.refreshAll() }
    }

    private func runDockerCommand(_ args: [String], completion: @escaping (Bool) -> Void) {
        guard !dockerPath.isEmpty else { completion(false); return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, !self.dockerPath.isEmpty else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            let category: CommandCategory = ["start", "stop", "restart"].contains(args.first ?? "")
                ? .reversibleMutation
                : .destructiveMutation
            let result = CommandExecutor.shared.run(
                executablePath: self.dockerPath,
                arguments: args,
                timeout: 60,
                category: category
            )
            let success = result.succeeded
            DispatchQueue.main.async { completion(success) }
        }
    }
}
