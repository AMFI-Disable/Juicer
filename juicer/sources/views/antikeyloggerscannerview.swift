import SwiftUI

struct antikeyloggerscannerview: View {
    @State private var findings: [String] = []
    @State private var message = "No scan has run."
    @State private var scanning = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            JuicerFeatureHeader(title: "Anti-Keylogger Scanner", subtitle: "Review launch agents and daemons for suspicious keylogger-like names.", icon: "keyboard.badge.ellipsis", refreshing: scanning, action: scan)
            HStack { Button(scanning ? "Scanning…" : "Scan Launch Locations") { scan() }.buttonStyle(.borderedProminent).disabled(scanning); Spacer(); Text(message).font(.caption).foregroundStyle(.secondary) }
            Text("Heuristic only: a filename match is not a malware verdict. Review the full path, code signature, notarization, and launch configuration before taking action.").font(.caption).foregroundStyle(.orange)
            if !scanning && findings.isEmpty { ContentUnavailableView("No heuristic matches", systemImage: "checkmark.shield", description: Text("No launch item matched the current filename rules.")) }
            else { List(findings, id: \.self) { finding in VStack(alignment: .leading) { Text(finding).font(.system(.body, design: .monospaced)); Text("Rule: filename contains keylog, input, or hook • Confidence: low • Verify in System Settings before removal").font(.caption2).foregroundStyle(.secondary) } }.listStyle(.inset) }
        }.padding(24).onAppear(perform: scan)
    }
    private func scan() {
        guard !scanning else { return }
        scanning = true
        DispatchQueue.global(qos: .userInitiated).async {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let roots = ["/Library/LaunchAgents", "/Library/LaunchDaemons", "\(home)/Library/LaunchAgents"]
            let paths = roots.flatMap { root in
                ((try? FileManager.default.contentsOfDirectory(atPath: root)) ?? []).map { "\(root)/\($0)" }
            }
            let candidates = paths.filter { path in
                let name = (path as NSString).lastPathComponent.lowercased()
                return name.contains("keylog") || name.contains("input") || name.contains("hook")
            }
            DispatchQueue.main.async {
                findings = candidates
                message = "Reviewed \(roots.count) launch locations; \(candidates.count) heuristic match(es)."
                scanning = false
            }
        }
    }
}
