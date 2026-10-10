import SwiftUI

@MainActor
struct duplicatefileview: View {
    @StateObject private var manager = DuplicateFileManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            JuicerFeatureHeader(
                title: "Duplicate File Finder",
                subtitle: "Match files by size and SHA-256 content hash.",
                icon: "doc.on.doc",
                refreshing: manager.isScanning,
                action: manager.scan
            )
            .accessibilityElement(children: .combine)

            HStack {
                Text(manager.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Scan status: \(manager.message)")

                Spacer()

                Button("Move Selected to Trash", role: .destructive) {
                    manager.trashSelected()
                }
                .disabled(!manager.files.contains(where: \.selected) || manager.isScanning)
                .accessibilityLabel("Move Selected to Trash")
                .accessibilityHint("Moves all selected duplicate files to the macOS Trash.")
            }

            if !manager.isScanning && manager.files.isEmpty {
                ContentUnavailableView(
                    "No Duplicate Files Found",
                    systemImage: "doc.on.doc",
                    description: Text("No duplicate files matching size and SHA-256 content hash were detected in user folders.")
                )
                .accessibilityLabel("No duplicate files found.")
            } else {
                List(manager.files) { file in
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { file.selected },
                            set: { value in
                                if let index = manager.files.firstIndex(where: { $0.id == file.id }) {
                                    manager.files[index].selected = value
                                }
                            }
                        ))
                        .labelsHidden()
                        .accessibilityLabel("Select \(file.url.lastPathComponent)")
                        .accessibilityValue(file.selected ? "Selected" : "Not selected")
                        .accessibilityHint("Toggles selection for trash removal.")

                        Image(systemName: "doc.fill")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading) {
                            Text(file.url.lastPathComponent)
                                .font(.body)

                            Text(file.url.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(file.url.lastPathComponent), path \(file.url.path)")

                        Spacer()

                        Text(SystemMetricsSupport.bytes(UInt64(file.size)))
                            .monospacedDigit()
                            .accessibilityLabel("Size: \(SystemMetricsSupport.bytes(UInt64(file.size)))")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("\(file.url.lastPathComponent), size \(SystemMetricsSupport.bytes(UInt64(file.size)))")
                    .accessibilityValue(file.selected ? "Selected" : "Not selected")
                }
                .listStyle(.inset)
                .accessibilityLabel("Duplicate Files List")
            }
        }
        .padding(24)
        .onAppear { manager.scan() }
    }
}
