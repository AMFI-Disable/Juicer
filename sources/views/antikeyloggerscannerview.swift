import SwiftUI

@MainActor
struct antikeyloggerscannerview: View {
    @State private var findings: [String] = []
    @State private var message = "No scan has run."
    @State private var scanning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            JuicerFeatureHeader(
                title: "Anti-Keylogger Scanner",
                subtitle: "Review launch agents and daemons for suspicious keylogger-like names.",
                icon: "keyboard.badge.ellipsis",
                refreshing: scanning,
                action: scan
            )
            .accessibilityElement(children: .combine)

            HStack {
                Button(scanning ? "Scanning…" : "Scan Launch Locations") {
                    scan()
                }
                .buttonStyle(.borderedProminent)
                .disabled(scanning)
                .accessibilityLabel(scanning ? "Scanning launch locations" : "Scan Launch Locations")
                .accessibilityHint("Scans launch agents and daemons for suspicious process names.")

                Spacer()

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Scan status: \(message)")
            }

            Text("Heuristic only: a filename match is not a malware verdict. Review the full path, code signature, notarization, and launch configuration before taking action.")
                .font(.caption)
                .foregroundStyle(.orange)
                .accessibilityLabel("Warning: Heuristic only. A filename match is not a malware verdict. Review full path, code signature, notarization, and launch configuration before taking action.")

            if !scanning && findings.isEmpty {
                ContentUnavailableView("No heuristic matches", systemImage: "checkmark.shield", description: Text("No launch item matched the current filename rules."))
                    .accessibilityLabel("No heuristic matches found. No launch item matched the current filename rules.")
            } else {
                List(findings, id: \.self) { finding in
                    VStack(alignment: .leading) {
                        Text(finding)
                            .font(.system(.body, design: .monospaced))
                        Text("Rule: filename contains keylog, input, or hook • Confidence: low • Verify in System Settings before removal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Suspicious item: \(finding)")
                    .accessibilityHint("Rule match: filename contains keylog, input, or hook. Confidence: low.")
                }
                .listStyle(.inset)
                .accessibilityLabel("Suspicious launch item findings")
            }
        }
        .padding(24)
        .onAppear(perform: scan)
    }

    private func scan() {
        guard !scanning else { return }
        scanning = true
        message = "Scanning launch locations…"

        Task {
            let maxItemsPerDirectory = 1000
            let maxCandidates = 500

            let (candidates, rootsCount) = await Task.detached(priority: .userInitiated) { () -> ([String], Int) in
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                let roots = [
                    "/Library/LaunchAgents",
                    "/Library/LaunchDaemons",
                    "\(home)/Library/LaunchAgents",
                    "\(home)/Library/LaunchDaemons"
                ]
                let fm = FileManager.default
                var matches: [String] = []
                var validRoots = 0

                for root in roots {
                    var isDir: ObjCBool = false
                    guard fm.fileExists(atPath: root, isDirectory: &isDir), isDir.boolValue else { continue }
                    validRoots += 1

                    guard let contents = try? fm.contentsOfDirectory(atPath: root) else { continue }
                    let boundedContents = contents.prefix(maxItemsPerDirectory)

                    for item in boundedContents {
                        guard matches.count < maxCandidates else { break }
                        let fullPath = "\(root)/\(item)"
                        guard fullPath.count <= 1024 else { continue }

                        let name = (item as NSString).lastPathComponent.lowercased()
                        if name.contains("keylog") || name.contains("input") || name.contains("hook") {
                            matches.append(fullPath)
                        }
                    }
                }
                return (matches, validRoots)
            }.value

            self.findings = candidates
            self.message = "Reviewed \(rootsCount) launch location(s); \(candidates.count) heuristic match(es)."
            self.scanning = false
        }
    }
}
