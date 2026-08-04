import SwiftUI
import AppKit

@MainActor
struct diskimageview: View {
    @StateObject private var manager = DiskImageManager()
    @State private var showMountConfirm = false
    @State private var showUnmountConfirm = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            JuicerFeatureHeader(
                title: "Disk Image Manager",
                subtitle: "Mount, verify, convert, and create DMG/ISO-style images.",
                icon: "externaldrive.badge.timemachine",
                refreshing: manager.working,
                action: manager.scan
            )

            HStack {
                Button("Choose Image") {
                    chooseImage()
                }
                .accessibilityLabel("Choose Disk Image")
                .accessibilityHint("Opens a panel to select a DMG, ISO, or sparsebundle file")

                Button("Create from Folder…") {
                    createImage()
                }
                .accessibilityLabel("Create Disk Image from Folder")
                .accessibilityHint("Opens a panel to select a source folder and create a DMG archive")

                Spacer()
            }

            if let selected = manager.selectedURL {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selected.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityLabel("Selected disk image: \(selected.lastPathComponent)")
                        .accessibilityValue(selected.path)

                    HStack {
                        Button("Mount") {
                            requestMount(for: selected)
                        }
                        .disabled(manager.working)
                        .accessibilityLabel("Mount \(selected.lastPathComponent)")
                        .accessibilityHint("Opens confirmation dialog to mount the selected disk image")

                        Button("Unmount") {
                            requestUnmount(for: selected)
                        }
                        .disabled(manager.working)
                        .accessibilityLabel("Unmount \(selected.lastPathComponent)")
                        .accessibilityHint("Opens confirmation dialog to unmount the selected disk image")

                        Button("Verify") {
                            manager.verify()
                        }
                        .disabled(manager.working)
                        .accessibilityLabel("Verify \(selected.lastPathComponent)")
                        .accessibilityHint("Verifies the checksum and structure of the selected disk image")

                        Button("Convert to UDZO…") {
                            convertImage()
                        }
                        .disabled(manager.working)
                        .accessibilityLabel("Convert \(selected.lastPathComponent) to UDZO")
                        .accessibilityHint("Opens save panel to convert disk image to compressed UDZO format")
                    }
                }
            }

            if !manager.message.isEmpty {
                Text(manager.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Status message: \(manager.message)")
            }

            List(manager.images) { image in
                Button {
                    manager.selectedURL = image.url
                } label: {
                    HStack {
                        Image(systemName: "externaldrive")
                            .accessibilityHidden(true)
                        Text(image.url.lastPathComponent)
                        Spacer()
                        Text(image.url.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Select \(image.url.lastPathComponent)")
                .accessibilityHint("Path: \(image.url.path)")
                .accessibilityValue(image.url.path)
            }
            .listStyle(.inset)
            .accessibilityLabel("Discovered Disk Images")
        }
        .padding(24)
        .onAppear {
            manager.scan()
        }
        .alert("Mount Disk Image?", isPresented: $showMountConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Mount") {
                manager.mount()
            }
        } message: {
            if let selected = manager.selectedURL {
                Text("Are you sure you want to mount '\(selected.lastPathComponent)'?")
            } else {
                Text("Are you sure you want to mount this disk image?")
            }
        }
        .alert("Unmount Disk Image?", isPresented: $showUnmountConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Unmount", role: .destructive) {
                manager.unmount()
            }
        } message: {
            if let selected = manager.selectedURL {
                Text("Are you sure you want to unmount '\(selected.lastPathComponent)'?")
            } else {
                Text("Are you sure you want to unmount this disk image?")
            }
        }
        .alert("Disk Image Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func requestMount(for url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "Disk image file does not exist at path: \(url.path)"
            showErrorAlert = true
            return
        }
        showMountConfirm = true
    }

    private func requestUnmount(for url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "Disk image file does not exist at path: \(url.path)"
            showErrorAlert = true
            return
        }
        showUnmountConfirm = true
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.diskImage]
        if panel.runModal() == .OK, let url = panel.url {
            manager.selectedURL = url
        }
    }

    private func createImage() {
        let open = NSOpenPanel()
        open.canChooseDirectories = true
        open.canChooseFiles = false
        guard open.runModal() == .OK, let folder = open.url else { return }
        let save = NSSavePanel()
        save.nameFieldStringValue = "image.dmg"
        if save.runModal() == .OK, let url = save.url {
            manager.create(from: folder, destination: url)
        }
    }

    private func convertImage() {
        let save = NSSavePanel()
        save.nameFieldStringValue = "converted.dmg"
        if save.runModal() == .OK, let url = save.url {
            manager.convert(to: "UDZO", destination: url)
        }
    }
}
