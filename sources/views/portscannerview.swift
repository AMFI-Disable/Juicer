import SwiftUI

struct portscannerview: View {
    @State private var host = "127.0.0.1"
    @State private var range = "22,80,443,3000,8000"
    @State private var results: [PortScanResult] = []
    @State private var scanning = false
    @State private var message = "Use localhost or another host you are authorized to inspect."

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            JuicerFeatureHeader(title: "Port Scanner", subtitle: "Check selected TCP ports with bounded per-port timeouts.", icon: "dot.radiowaves.left.and.right", refreshing: scanning, action: scan)
            HStack { TextField("Host", text: $host); TextField("Ports (comma separated)", text: $range); Button("Scan") { scan() }.buttonStyle(.borderedProminent).disabled(scanning) }
            Text(message).font(.caption).foregroundStyle(.secondary)
            List(results) { item in
                HStack { Text("\(host):\(item.port)").font(.system(.body, design: .monospaced)); Spacer(); Text(item.state.rawValue.capitalized).foregroundStyle(color(for: item.state)); Text(item.detail).font(.caption).foregroundStyle(.secondary) }
            }.listStyle(.inset)
            Spacer()
        }.padding(24)
    }

    private func color(for state: PortScanState) -> Color { state == .open ? .green : state == .error ? .red : .secondary }

    private func scan() {
        guard !scanning else { return }
        let ports = NetworkInputValidation.ports(range)
        guard !ports.isEmpty else { message = "Enter ports from 1 to 65535, separated by commas."; results = []; return }
        let target = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard NetworkInputValidation.hostname(target) != nil || target == "localhost" || target == "::1" else { message = "Enter a valid hostname or IP address."; return }
        scanning = true; message = "Scanning (target) — (ports.count) port(s), 2-second maximum per port…"
        results = ports.map { PortScanResult(port: $0, state: .pending, detail: "Waiting") }
        DispatchQueue.global(qos: .userInitiated).async {
            var scanned: [PortScanResult] = []
            for port in ports {
                let command = CommandExecutor.shared.run(executablePath: "/usr/bin/nc", arguments: ["-z", "-G", "2", target, String(port)], timeout: 3)
                let state: PortScanState = command.succeeded ? .open : (command.didTimeOut ? .timedOut : .closed)
                scanned.append(PortScanResult(port: port, state: state, detail: command.succeeded ? "TCP connection accepted" : command.didTimeOut ? "Timed out" : "No listener detected"))
                DispatchQueue.main.async { results = scanned }
            }
            DispatchQueue.main.async { scanning = false; message = "Scan complete. (scanned.filter { $0.state == .open }.count) open port(s); no connection was made beyond the requested checks." }
        }
    }
}
