import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct archiveutilityview: View {
    @StateObject private var manager = ArchiveUtilityManager()
    @State private var targeted = false

    var body: some View {
        VStack(spacing: 18) {
            JuicerFeatureHeader(
                title: "Archive Extractor / Creator",
                subtitle: "Extract common archives or create portable ZIP files.",
                icon: "archivebox",
                refreshing: manager.working,
                action: {
                    manager.inputURL = nil
                    manager.message = "Drop an archive or folder here."
                }
            )

            VStack(spacing: 8) {
                Image(systemName: "archivebox")
                    .font(.system(size: 44))
                    .accessibilityHidden(true)
                Text(manager.inputURL?.lastPathComponent ?? "Drop an archive or folder here")
                    .font(.headline)
                Text(manager.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(Color.accentColor.opacity(targeted ? 0.18 : 0.07), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(manager.inputURL != nil ? "Selected input: \(manager.inputURL!.lastPathComponent)" : "Archive or folder drop zone")
            .accessibilityHint("Drop an archive file or folder here to select it as input")
            .onDrop(of: [UTType.fileURL], isTargeted: $targeted) { providers in
                guard let provider = providers.first else { return false }
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let url = item as? URL {
                        Task { @MainActor in
                            manager.setInput(url)
                        }
                    }
                }
                return true
            }

            HStack {
                Button("Choose Input") {
                    chooseInput()
                }
                .accessibilityLabel("Choose input file or directory")
                .accessibilityHint("Opens a panel to select an archive or folder")

                Button("Extract…") {
                    chooseDestination(extracting: true)
                }
                .disabled(manager.inputURL == nil || manager.working)
                .accessibilityLabel("Extract archive")
                .accessibilityHint("Opens a panel to choose destination directory for extraction")

                Button("Create ZIP…") {
                    chooseZipDestination()
                }
                .disabled(manager.inputURL == nil || manager.working)
                .accessibilityLabel("Create ZIP archive")
                .accessibilityHint("Opens a panel to save the input as a ZIP archive")
            }

            Spacer()
        }
        .padding(24)
    }

    private func chooseInput() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            manager.setInput(url)
        }
    }

    private func chooseDestination(extracting: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Extract Here"
        if panel.runModal() == .OK, let url = panel.url {
            manager.extract(to: url)
        }
    }

    private func chooseZipDestination() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "archive.zip"
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            manager.createZip(at: url)
        }
    }
}
