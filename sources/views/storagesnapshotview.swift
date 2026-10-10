import SwiftUI

struct storagesnapshotview: View {
    @StateObject private var manager = StorageSnapshotManager()
    @State private var pendingAction: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            JuicerFeatureHeader(title: "Storage Snapshot Manager", subtitle: "Create, inspect, compare, and roll back APFS snapshots.", icon: "clock.arrow.circlepath", refreshing: manager.working, action: manager.refresh)
            HStack {
                TextField("APFS volume", text: $manager.volume).frame(width: 180)
                Button("Refresh") { manager.refresh() }
                Button("Create Snapshot") { manager.create() }.buttonStyle(.borderedProminent)
                Spacer()
                Button("Delete") { pendingAction = "delete" }.disabled(manager.selectedID.isEmpty || manager.working)
                Button("Rollback…") { pendingAction = "rollback" }.disabled(manager.selectedID.isEmpty || manager.working)
            }
            Text("Read-only by default. Deletion is permanent for the selected snapshot; rollback changes the selected volume and may require administrator approval.").font(.caption).foregroundStyle(.orange)
            if let selected = manager.snapshots.first(where: { $0.id == manager.selectedID }) {
                Toggle("Confirm exact snapshot UUID (selected.id)", isOn: Binding(get: { manager.confirmedSnapshotID == selected.id }, set: { manager.confirmedSnapshotID = $0 ? selected.id : "" })).font(.caption)
            }
            if !manager.lastActionMessage.isEmpty { Text(manager.lastActionMessage).font(.caption).foregroundStyle(.secondary) }
            List(manager.snapshots, selection: $manager.selectedID) { snapshot in HStack { Image(systemName: "camera"); VStack(alignment: .leading) { Text(snapshot.id).font(.system(.body, design: .monospaced)); Text(snapshot.detail).font(.caption).foregroundStyle(.secondary) } } }.listStyle(.inset)
            if !manager.output.isEmpty { ScrollView { Text(manager.output).font(.system(.caption, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }.frame(maxHeight: 140).padding(10).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8)) }
        }.padding(24).onAppear { manager.refresh() }.alert("Confirm APFS action", isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } })) {
            Button("Cancel", role: .cancel) { pendingAction = nil }
            Button(pendingAction == "delete" ? "Delete Snapshot" : "Rollback Volume", role: .destructive) { if pendingAction == "delete" { manager.delete() } else { manager.rollback() }; pendingAction = nil }
        } message: { Text("Volume: \(manager.volume)\nSnapshot UUID: \(manager.selectedID)\nThis action is scoped only to the exact confirmed snapshot above.") }
    }
}
