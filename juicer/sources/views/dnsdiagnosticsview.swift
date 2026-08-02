import SwiftUI

struct dnsdiagnosticsview: View {
    @State private var host = "example.com"
    @State private var server = "1.1.1.1"
    @State private var result: DNSDiagnosticResult?
    @State private var rawOutput = ""
    @State private var message = "Enter a hostname and resolver to begin."
    @State private var running = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            JuicerFeatureHeader(title: "DNS Resolver Diagnostics", subtitle: "Query a hostname against a selected DNS resolver and inspect timing.", icon: "network.badge.shield.half.filled", refreshing: running, action: resolve)
            HStack {
                TextField("Hostname", text: $host)
                TextField("DNS server", text: $server)
                Button("Resolve") { resolve() }.buttonStyle(.borderedProminent).disabled(running)
            }
            if let result {
                HStack { Label(result.status, systemImage: result.error == nil ? "checkmark.circle" : "xmark.circle"); Text("Resolver: (result.resolver)"); Text("DNSSEC: (result.dnssec)"); if let queryTimeMilliseconds = result.queryTimeMilliseconds { Text("Query: (queryTimeMilliseconds) ms") } }.font(.caption)
                if let error = result.error { Text(error).foregroundStyle(.orange).font(.caption) }
                if result.answers.isEmpty { Text("No answer records returned.").foregroundStyle(.secondary) }
                ForEach(result.answers) { answer in Text("(answer.name)  (answer.recordType)  (answer.value)").font(.system(.caption, design: .monospaced)) }
            } else { Text(message).foregroundStyle(.secondary) }
            DisclosureGroup("Raw dig output") { ScrollView { Text(rawOutput.isEmpty ? "No raw output yet." : rawOutput).font(.system(.caption, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) } }.disabled(rawOutput.isEmpty)
            Spacer()
        }.padding(24)
    }

    private func resolve() {
        guard let validHost = NetworkInputValidation.hostname(host) else { message = "Enter a valid hostname, such as example.com."; result = nil; return }
        guard let validServer = NetworkInputValidation.resolver(server) else { message = "Enter a valid DNS resolver address or hostname."; result = nil; return }
        guard !running else { return }
        running = true; message = "Resolving (validHost) through (validServer)…"
        DispatchQueue.global(qos: .userInitiated).async {
            let output = SystemMetricsSupport.run("/usr/bin/dig", ["@\(validServer)", validHost, "+stats", "+dnssec"], timeout: 10) ?? "dig failed or timed out."
            let parsed = DNSDiagnosticParser.parse(output, resolver: validServer)
            DispatchQueue.main.async { rawOutput = output; result = parsed; message = parsed.error ?? "Resolution complete."; running = false }
        }
    }
}
