import SwiftUI

struct systemservicesview: View {
    @State private var services: [ParsedServiceStatus] = []
    @State private var query = ""
    @State private var lastUpdated: Date?

    private var filtered: [ParsedServiceStatus] { services.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.status.localizedCaseInsensitiveContains(query) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            JuicerFeatureHeader(title: "System Service Status", subtitle: "Read-only launchd inspection with structured status explanations.", icon: "gearshape.2", refreshing: false, action: refresh)
            HStack { TextField("Search services", text: $query).textFieldStyle(.roundedBorder); Spacer(); if let lastUpdated { Text("Updated \(SystemMetricsSupport.time(lastUpdated))").font(.caption).foregroundStyle(.secondary) } }
            Table(filtered) { TableColumn("Service") { Text($0.name) }; TableColumn("Status") { Text($0.status) }; TableColumn("Code") { Text($0.rawStatusCode.map(String.init) ?? "—") } }
            .frame(minHeight: 260)
        }.padding(24).onAppear(perform: refresh)
    }
    private func refresh() { services = ServiceStatusParser.parseLaunchctlList(SystemMetricsSupport.run("/bin/launchctl", ["list"]) ?? ""); lastUpdated = Date() }
}
