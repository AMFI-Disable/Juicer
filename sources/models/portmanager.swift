import Foundation

struct ActivePort: Identifiable, Hashable, Codable {
    var id: String { "\(port)-\(pid)" }
    let port: Int
    let protocolName: String // "TCP" or "UDP"
    let processName: String
    let pid: Int
    var commandLineArgs: String = ""
    var parentPid: Int?
}

class PortManager: ObservableObject {
    @Published var activePorts: [ActivePort] = []
    @Published var isLoading = false

    // Default development ports filter
    static let devPorts: Set<Int> = [80, 443, 3000, 3001, 4000, 5000, 5001, 8000, 8080, 9000, 9090, 8081]

    func loadPorts() {
        self.isLoading = true
        self.activePorts = []

        Task.detached(priority: .userInitiated) {
            var portsList: [ActivePort] = []

            // Run lsof -nP -i -sTCP:LISTEN (gets both IPv4/IPv6 listening TCP sockets)
            let lsofOutput = Self.runCommand(
                "/usr/sbin/lsof",
                arguments: ["-nP", "-iTCP", "-sTCP:LISTEN"]
            )
            let lines = lsofOutput.components(separatedBy: "\n")

            // Expected format: COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
            for line in lines.dropFirst() {
                let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                guard parts.count >= 8 else { continue }

                let processName = parts[0]
                guard let pid = Int(parts[1]) else { continue }
                let nodeName = parts[8] // e.g. "*:3000" or "127.0.0.1:8080"

                // Extract port number
                if let colonIndex = nodeName.lastIndex(of: ":") {
                    let portStr = String(nodeName[nodeName.index(after: colonIndex)...])
                    if let portNumber = Int(portStr.trimmingCharacters(in: .whitespacesAndNewlines)) {

                        // Query command line args and parent PID
                        let args = Self.runCommand("/bin/ps", arguments: ["-p", String(pid), "-o", "args="])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        let ppidStr = Self.runCommand("/bin/ps", arguments: ["-p", String(pid), "-o", "ppid="])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        let ppid = Int(ppidStr)

                        let activePort = ActivePort(
                            port: portNumber,
                            protocolName: "TCP",
                            processName: processName,
                            pid: pid,
                            commandLineArgs: args.isEmpty ? "No arguments" : args,
                            parentPid: ppid
                        )
                        portsList.append(activePort)
                    }
                }
            }

            // Deduplicate ports
            var uniquePorts: [ActivePort] = []
            for item in portsList {
                if !uniquePorts.contains(where: { $0.port == item.port && $0.pid == item.pid }) {
                    uniquePorts.append(item)
                }
            }

            let sorted = uniquePorts.sorted(by: { $0.port < $1.port })

            await MainActor.run {
                self.activePorts = sorted
                self.isLoading = false
                AppLogger.shared.log("Loaded \(self.activePorts.count) active listening ports.")
            }
        }
    }

    func killProcess(pid: Int, completion: @escaping (Bool) -> Void) {
        // Read kill preference setting
        let forceKill = UserDefaults.standard.bool(forKey: "juicer.settings.killForceful")
        let signal = forceKill ? "-9" : "-15"

        AppLogger.shared.log("Sending signal \(signal) to process PID \(pid)...")

        Task.detached(priority: .userInitiated) {
            let result = CommandExecutor.shared.run(
                executablePath: "/bin/kill",
                arguments: [signal, String(pid)],
                timeout: 5,
                category: .destructiveMutation
            )
            if !result.succeeded {
                AppLogger.shared.log("Failed to signal process PID \(pid) (status: \(result.terminationStatus.map(String.init) ?? "launch error")).")
            }
            await MainActor.run {
                self.loadPorts()
                completion(result.succeeded)
            }
        }
    }

    private static func runCommand(_ executablePath: String, arguments: [String]) -> String {
        let result = CommandExecutor.shared.run(
            executablePath: executablePath,
            arguments: arguments,
            timeout: 5
        )
        return result.succeeded ? result.standardOutput : ""
    }
}
