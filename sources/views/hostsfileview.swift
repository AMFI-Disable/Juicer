import SwiftUI
import AppKit

typealias hostsfileview = HostsFileView

struct HostsFileView: View {
    @State private var contents: String = ""
    @State private var originalContents: String = ""
    @State private var message: String = ""
    @State private var isSaving: Bool = false
    @State private var showDiffPreview: Bool = false

    var isModified: Bool { contents != originalContents }
    var lineCount: Int { contents.components(separatedBy: "\n").count }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            JuicerFeatureHeader(
                title: "Hosts File Studio",
                subtitle: "Safely inspect, validate, and edit /etc/hosts with administrator authorization & backup snapshots.",
                icon: "list.bullet.rectangle",
                refreshing: isSaving,
                action: loadHostsFile
            )

            HStack {
                Button(action: loadHostsFile) {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Button(action: { createBackup() }) {
                    Label("Create Snapshot", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)

                Spacer()

                if isModified {
                    Button(action: { showDiffPreview.toggle() }) {
                        Label(showDiffPreview ? "Hide Diff" : "Preview Diff", systemImage: "eye")
                    }
                    .buttonStyle(.bordered)
                }

                Button(action: saveHostsFileWithAdmin) {
                    Label(isSaving ? "Saving..." : "Save with Admin Privileges", systemImage: "lock.shield")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isModified || isSaving)
            }

            if !message.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: message.contains("failed") || message.contains("Error") || message.contains("Unable") ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(message.contains("failed") || message.contains("Error") || message.contains("Unable") ? Color.red : Color.green)
                    Text(message)
                        .font(.caption.bold())
                        .foregroundStyle(message.contains("failed") || message.contains("Error") || message.contains("Unable") ? Color.red : Color.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
            }

            if showDiffPreview {
                diffPreviewSection
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("/etc/hosts Editor").font(.caption).bold().foregroundStyle(.secondary)
                    Spacer()
                    Text("\(lineCount) lines • \(contents.count) chars").font(.caption).foregroundStyle(.secondary)
                }

                TextEditor(text: $contents)
                    .font(.system(.body, design: .monospaced))
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.15)))
            }

            Spacer()
        }
        .padding(24)
        .onAppear(perform: loadHostsFile)
    }

    @ViewBuilder
    private var diffPreviewSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Line Diff Preview:").font(.caption.bold()).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    let oldLines = originalContents.components(separatedBy: "\n")
                    let newLines = contents.components(separatedBy: "\n")

                    ForEach(Array(newLines.enumerated()), id: \.offset) { idx, line in
                        if idx >= oldLines.count || oldLines[idx] != line {
                            Text("+ \(line)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.green.opacity(0.1))
                        }
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: 120)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
        }
    }

    private func loadHostsFile() {
        do {
            let str = try String(contentsOfFile: "/etc/hosts", encoding: .utf8)
            contents = str
            originalContents = str
            message = ""
        } catch {
            message = "Unable to read /etc/hosts: \(error.localizedDescription)"
        }
    }

    private func saveHostsFileWithAdmin() {
        isSaving = true
        message = "Authorizing admin save..."

        guard createBackup() else {
            isSaving = false
            return
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("hosts_temp_\(UUID().uuidString)")
        do {
            try contents.write(to: tempURL, atomically: true, encoding: .utf8)
            let script = "do shell script \"cp '\(tempURL.path)' /etc/hosts\" with administrator privileges"

            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(&error)

                    DispatchQueue.main.async {
                        self.isSaving = false
                        try? FileManager.default.removeItem(at: tempURL)
                        if let err = error {
                            let errMsg = (err[NSAppleScript.errorMessage] as? String) ?? "Authorization cancelled or privilege error."
                            self.message = "Save failed: \(errMsg)"
                        } else {
                            self.originalContents = self.contents
                            self.showDiffPreview = false
                            self.message = "Successfully saved /etc/hosts with administrator authorization."
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isSaving = false
                        try? FileManager.default.removeItem(at: tempURL)
                        self.message = "Failed to construct authorization script."
                    }
                }
            }
        } catch {
            isSaving = false
            message = "Save failed: \(error.localizedDescription)"
        }
    }

    @discardableResult
    private func createBackup() -> Bool {
        guard !originalContents.isEmpty else {
            message = "Backup skipped: Original /etc/hosts content is empty."
            return false
        }
        let backupPath = "/tmp/hosts_backup_\(Int(Date().timeIntervalSince1970)).bak"
        do {
            try originalContents.write(toFile: backupPath, atomically: true, encoding: .utf8)
            let attributes = try FileManager.default.attributesOfItem(atPath: backupPath)
            guard let fileSize = attributes[.size] as? UInt64, fileSize > 0 || originalContents.isEmpty else {
                message = "Backup verification failed: Snapshot file is empty or unreadable."
                return false
            }
            message = "Snapshot created successfully at \(backupPath)."
            return true
        } catch {
            message = "Backup creation failed: \(error.localizedDescription)"
            return false
        }
    }
}
