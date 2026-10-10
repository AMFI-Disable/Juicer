import SwiftUI
import AppKit

@MainActor
struct deletionhistoryview: View {
    @StateObject private var undoManager = DeletionUndoManager.shared
    @State private var selectedBackup: DeletionBackup?
    @State private var showConfirmDelete = false
    @State private var resultMessage: String = ""
    @State private var showResult = false

    /// Safe selected backup lookup ensuring selection bounds integrity against backing model updates.
    private var safeSelectedBackup: DeletionBackup? {
        guard let backup = selectedBackup,
              undoManager.backups.contains(where: { $0.id == backup.id }) else {
            return nil
        }
        return backup
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection()
            Divider()

            if undoManager.backups.isEmpty {
                emptyStatePlaceholder()
            } else {
                manifestTableSummaryBar()
                Divider()
                backupsList()
            }

            Divider()
            footerDetailsBar()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            undoManager.loadBackups()
            validateSelectionBounds()
        }
        .onReceive(undoManager.$backups) { backups in
            if let current = selectedBackup, !backups.contains(where: { $0.id == current.id }) {
                selectedBackup = nil
            }
        }
        .alert("Confirm Permanent Deletion", isPresented: $showConfirmDelete) {
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("confirm_delete_cancel_button")
            Button("Delete", role: .destructive) {
                if let backup = safeSelectedBackup {
                    undoManager.deleteBackupPermanently(backup)
                    selectedBackup = nil
                }
            }
            .accessibilityIdentifier("confirm_delete_button")
        } message: {
            if let backup = safeSelectedBackup {
                Text("Are you sure you want to permanently delete '\(backup.name)'? This action cannot be undone.\nSize: \(formatBytes(backup.sizeBytes))")
            }
        }
        .alert("Done", isPresented: $showResult) {
            Button("OK") {}
                .accessibilityIdentifier("result_ok_button")
        } message: {
            Text(resultMessage)
        }
    }

    private func validateSelectionBounds() {
        if let current = selectedBackup, !undoManager.backups.contains(where: { $0.id == current.id }) {
            selectedBackup = nil
        }
    }

    // MARK: - Header
    @ViewBuilder
    private func headerSection() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Deletion Undo History")
                    .font(.title2).bold()
                    .accessibilityAddTraits(.isHeader)
                Text("Review and roll back files trashed by Juicer. Items are kept for 3 days before auto-purging.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Deletion Undo History header. Review and roll back files trashed by Juicer. Items are kept for 3 days before auto-purging.")

            Spacer()

            if !undoManager.backups.isEmpty {
                Button("Clear Cabinet Safely") {
                    let itemsToPurge = undoManager.backups
                    for backup in itemsToPurge {
                        undoManager.deleteBackupPermanently(backup)
                    }
                    selectedBackup = nil
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Clear Cabinet Safely")
                .accessibilityHint("Permanently deletes all backed up items from the history cabinet")
                .accessibilityIdentifier("clear_cabinet_button")
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
    }

    // MARK: - Manifest Summary Bar
    @ViewBuilder
    private func manifestTableSummaryBar() -> some View {
        let totalCount = undoManager.backups.count
        let totalBytes = undoManager.backups.reduce(Int64(0)) { $0 + max(0, $1.sizeBytes) }

        HStack(spacing: 12) {
            Label("\(totalCount) \(totalCount == 1 ? "Item" : "Items")", systemImage: "square.stack.3d.up.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("•")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Label("Total Size: \(formatBytes(totalBytes))", systemImage: "internaldrive")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Manifest summary: \(totalCount) \(totalCount == 1 ? "item" : "items"), total size \(formatBytes(totalBytes))")
    }

    // MARK: - Empty State
    @ViewBuilder
    private func emptyStatePlaceholder() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48)).foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No Deletion History").font(.headline).foregroundStyle(.secondary)
            Text("When you delete application caches, large files, or directories, they are temporarily held here in case you need to undo.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No Deletion History. When you delete application caches, large files, or directories, they are temporarily held here in case you need to undo.")
    }

    // MARK: - List / Manifest Table
    @ViewBuilder
    private func backupsList() -> some View {
        List(undoManager.backups) { backup in
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "folder.badge.gearshape")
                        .font(.caption).foregroundColor(.orange)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(backup.name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("Original: \(backup.originalPath)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("Trashed: \(formatDate(backup.timestamp))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Item: \(backup.name), Original path: \(backup.originalPath), Trashed on: \(formatDate(backup.timestamp))")

                Spacer()

                Text(formatBytes(backup.sizeBytes))
                    .font(.subheadline).bold().foregroundColor(.secondary)
                    .accessibilityLabel("Size: \(formatBytes(backup.sizeBytes))")

                HStack(spacing: 8) {
                    Button("Undo") {
                        undoManager.restoreBackup(backup) { success, msg in
                            Task { @MainActor in
                                resultMessage = msg
                                showResult = true
                                if success {
                                    if selectedBackup?.id == backup.id {
                                        selectedBackup = nil
                                    }
                                }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .accessibilityLabel("Undo deletion for \(backup.name)")
                    .accessibilityHint("Restores this item to its original location: \(backup.originalPath)")
                    .accessibilityIdentifier("undo_button_\(backup.id.uuidString)")

                    Button(action: {
                        selectedBackup = backup
                        showConfirmDelete = true
                    }) {
                        Image(systemName: "trash.fill").foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Permanently delete \(backup.name)")
                    .accessibilityHint("Permanently deletes this backup from storage")
                    .accessibilityIdentifier("delete_button_\(backup.id.uuidString)")
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedBackup = backup
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Backup item \(backup.name)")
        }
        .listStyle(.inset)
    }

    // MARK: - Footer Details Bar
    @ViewBuilder
    private func footerDetailsBar() -> some View {
        HStack {
            if let backup = safeSelectedBackup {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Selected: \(backup.name)")
                        .bold()
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("Backup path: \(backup.backupPath)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Selected item: \(backup.name), Backup path: \(backup.backupPath)")

                Spacer()

                Button("Reveal in Finder") {
                    let sourceURL = URL(fileURLWithPath: backup.backupPath)
                    if FileManager.default.fileExists(atPath: backup.backupPath) {
                        NSWorkspace.shared.activateFileViewerSelecting([sourceURL])
                    } else {
                        NSWorkspace.shared.selectFile(backup.backupPath, inFileViewerRootedAtPath: "")
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Reveal \(backup.name) in Finder")
                .accessibilityHint("Opens Finder to show the backup file location")
                .accessibilityIdentifier("reveal_in_finder_button")
            } else {
                Text("Select an item to view backup storage coordinates.")
                    .font(.caption).foregroundColor(.secondary)
                    .accessibilityLabel("Select an item to view backup storage coordinates.")
                Spacer()
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .frame(height: 48)
    }

    // MARK: - Helpers
    private func formatBytes(_ bytes: Int64) -> String {
        guard bytes >= 0 else { return "—" }
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
