import SwiftUI
import Foundation

private struct pathauditentry: Identifiable {
    let id = UUID()
    let path: String
    let issue: String?
}

struct PathSecurityAuditorView: View {
    @State private var pathStatus = "Run an audit to inspect your PATH."
    @State private var entries: [pathauditentry] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            JuicerFeatureHeader(title: "PATH Security Auditor", subtitle: "Review executable directories for missing paths and world-writable locations.", icon: "lock.shield", refreshing: false, action: audit)
            Text(pathStatus).font(.subheadline).foregroundStyle(.secondary)
            List(entries) { entry in
                HStack(spacing: 10) {
                    Image(systemName: entry.issue == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(entry.issue == nil ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.path).font(.system(.body, design: .monospaced))
                        if let issue = entry.issue { Text(issue).font(.caption).foregroundStyle(.orange) }
                    }
                }
            }
            .listStyle(.inset)
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView("No audit results", systemImage: "lock.shield", description: Text("Run the audit to inspect PATH entries."))
                }
            }
        }
        .padding(24)
        .onAppear(perform: audit)
    }

    private func audit() {
        let paths = ProcessInfo.processInfo.environment["PATH", default: ""]
            .split(separator: ":")
            .map(String.init)
        entries = paths.map { path in
            var issue: String?
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
                return pathauditentry(path: path, issue: "Directory does not exist")
            }
            if !isDirectory.boolValue { issue = "Path is not a directory" }
            if let permissions = try? FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? NSNumber,
               permissions.intValue & 0o002 != 0 {
                issue = "Directory is writable by other users"
            }
            return pathauditentry(path: path, issue: issue)
        }
        let issues = entries.compactMap(\.issue).count
        pathStatus = issues == 0 ? "Audit complete: no obvious PATH issues found." : "Audit complete: \(issues) issue(s) need review."
    }
}
