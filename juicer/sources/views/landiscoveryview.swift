import SwiftUI

struct landiscoveryview: View {
    @State private var service = "_http._tcp"
    @State private var result: LANDiscoveryResult?
    @State private var running = false
    @State private var message = "Enter a Bonjour service type such as _http._tcp."

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            JuicerFeatureHeader(title: "LAN Device Discovery", subtitle: "Browse Bonjour services advertised on the local network.", icon: "network", refreshing: running, action: discover)
            HStack { TextField("Bonjour service", text: $service); Button("Discover") { discover() }.buttonStyle(.borderedProminent).disabled(running) }
            if running { ProgressView("Browsing for up to 8 seconds…") }
            if let result {
                Text(result.timedOut ? "Discovery timed out; showing results collected before the deadline." : "Found (result.instances.count) service result(s).").font(.caption).foregroundStyle(result.timedOut ? .orange : .secondary)
                if result.instances.isEmpty { Text("No matching services were advertised. Check Local Network permission and the service type.").foregroundStyle(.secondary) }
                List(result.instances, id: \.self) { Text($0).font(.system(.caption, design: .monospaced)) }.listStyle(.inset)
            } else { Text(message).foregroundStyle(.secondary) }
            Spacer()
        }.padding(24)
    }

    private func discover() {
        guard let validService = NetworkInputValidation.bonjourService(service) else { message = "Use a valid service type such as _http._tcp or _ssh._udp."; result = nil; return }
        guard !running else { return }
        running = true; message = "Browsing (validService) on the local network…"
        DispatchQueue.global(qos: .userInitiated).async {
            let output = SystemMetricsSupport.run("/usr/bin/dns-sd", ["-B", validService, "local"], timeout: 8) ?? "Bonjour browsing failed or timed out."
            let parsed = LANDiscoveryParser.parse(output, service: validService, timedOut: output.contains("timed out") || output.contains("failed"))
            DispatchQueue.main.async { result = parsed; message = parsed.instances.isEmpty ? "No matching services found." : "Discovery complete."; running = false }
        }
    }
}
