import SwiftUI

@MainActor
struct brewfilesyncview: View {
    @StateObject private var manager = BrewManager.shared
    @State private var importConsoleLog = ""
    @State private var isProcessing = false
    @State private var statusMessage = ""
    @State private var showStatusAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header panel
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Brewfile Backup & Restore")
                        .font(.title2)
                        .bold()
                        .accessibilityAddTraits(.isHeader)
                    Text("Share your package configuration lists or restore your developer setup on a new Mac.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

            Divider()

            // Layout Panels split
            HStack(spacing: 20) {
                // Export card
                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)
                    Text("Export Setup (Backup)")
                        .font(.headline)
                        .bold()
                    Text("Dumps all registered Homebrew Taps, Formulae, and Casks into a text 'Brewfile' bundle list.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Spacer()

                    Button("Export Brewfile...") {
                        exportBrewfile()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing)
                    .accessibilityLabel("Export Brewfile")
                    .accessibilityHint("Opens a save panel to export your current Homebrew setup into a Brewfile backup.")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Import card
                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                        .accessibilityHidden(true)
                    Text("Import Setup (Restore)")
                        .font(.headline)
                        .bold()
                    Text("Reads a 'Brewfile' from disk and installs all specified casks and formulae in a single batch.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Spacer()

                    Button("Import Brewfile...") {
                        importBrewfile()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing)
                    .accessibilityLabel("Import Brewfile")
                    .accessibilityHint("Opens a file panel to choose a Brewfile and restore packages.")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding()

            Divider()

            // Console logger drawer for bundle imports
            VStack(alignment: .leading, spacing: 6) {
                Text("Restore Logs Console")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
                    .accessibilityAddTraits(.isHeader)

                ScrollView {
                    Text(importConsoleLog.isEmpty ? "System idle. Ready to restore..." : importConsoleLog)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(importConsoleLog.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .background(Color.black.opacity(0.08))
                .cornerRadius(6)
                .frame(maxHeight: .infinity)
                .accessibilityLabel("Restore Logs Console")
                .accessibilityValue(importConsoleLog.isEmpty ? "System idle. Ready to restore..." : importConsoleLog)
            }
            .padding()
        }
        .alert("Operation Finished", isPresented: $showStatusAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(statusMessage)
        }
    }

    // Save panel dump
    private func exportBrewfile() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.text]
        savePanel.nameFieldStringValue = "Brewfile"
        savePanel.title = "Save Brewfile Backup"

        savePanel.begin { response in
            Task { @MainActor in
                guard response == .OK, let rawURL = savePanel.url else { return }
                guard self.validateExportURL(rawURL) else {
                    self.statusMessage = "Export failed: Invalid or restricted destination path."
                    self.showStatusAlert = true
                    return
                }

                let safeURL = rawURL.standardizedFileURL
                self.isProcessing = true
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .drawCompleted)

                self.manager.exportBrewfile(to: safeURL) { success in
                    Task { @MainActor in
                        self.isProcessing = false
                        if success {
                            self.statusMessage = "Brewfile successfully exported!"
                        } else {
                            self.statusMessage = "Failed to export Brewfile. Check log console."
                        }
                        self.showStatusAlert = true
                    }
                }
            }
        }
    }

    // Open panel restore
    private func importBrewfile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.text, .data]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Choose Brewfile to Import"

        openPanel.begin { response in
            Task { @MainActor in
                guard response == .OK, let rawURL = openPanel.url else { return }
                guard self.validateImportURL(rawURL) else {
                    self.statusMessage = "Import failed: Invalid, unreadable, or restricted file path."
                    self.showStatusAlert = true
                    return
                }

                let safeURL = rawURL.standardizedFileURL
                self.isProcessing = true
                self.importConsoleLog = "Beginning bundle restore from \(safeURL.lastPathComponent)...\n"
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .drawCompleted)

                self.manager.importBrewfile(from: safeURL) { success, log in
                    Task { @MainActor in
                        self.isProcessing = false
                        self.importConsoleLog += log
                        if success {
                            self.statusMessage = "Brewfile successfully imported and restored!"
                        } else {
                            self.statusMessage = "Import execution encountered errors. View console logs."
                        }
                        self.showStatusAlert = true
                    }
                }
            }
        }
    }

    // MARK: - Path Bounds & Safety Validation

    private func validateExportURL(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        let safeURL = url.standardizedFileURL
        let path = safeURL.path

        guard !path.isEmpty && path != "/" else { return false }

        let forbiddenPrefixes = ["/System", "/bin", "/sbin", "/usr", "/etc", "/var", "/private"]
        for prefix in forbiddenPrefixes {
            if path.hasPrefix(prefix) {
                return false
            }
        }

        let parentDir = safeURL.deletingLastPathComponent().path
        guard FileManager.default.fileExists(atPath: parentDir) && FileManager.default.isWritableFile(atPath: parentDir) else {
            return false
        }

        return true
    }

    private func validateImportURL(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        let safeURL = url.standardizedFileURL
        let path = safeURL.path

        guard !path.isEmpty && path != "/" else { return false }

        let forbiddenPrefixes = ["/System", "/bin", "/sbin", "/usr", "/etc", "/var", "/private"]
        for prefix in forbiddenPrefixes {
            if path.hasPrefix(prefix) {
                return false
            }
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              !isDirectory.boolValue,
              FileManager.default.isReadableFile(atPath: path) else {
            return false
        }

        return true
    }
}

