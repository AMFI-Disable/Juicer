import SwiftUI
import AppKit

private struct clipboardrecord: Codable, Identifiable, Hashable {
    let id: UUID
    let value: String
    var pinned: Bool
    let createdAt: Date
}

@MainActor
struct clipboardmanagerview: View {
    @AppStorage("juicer.clipboard.records") private var storedRecords = Data()
    @State private var records: [clipboardrecord] = []
    @State private var searchText = ""
    @State private var lastCount = NSPasteboard.general.changeCount
    @State private var timer: Timer?
    @State private var message = ""

    private let maxTotalRecords = 100
    private let maxPinnedRecords = 50
    private let maxItemCharacterCount = 10_000

    private var filteredRecords: [clipboardrecord] {
        records.filter { searchText.isEmpty || $0.value.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            JuicerFeatureHeader(title: "Clipboard Manager", subtitle: "Keep a private local history with pins, search, and keyboard-friendly paste actions.", icon: "doc.on.clipboard.fill", refreshing: false, action: poll)

            HStack(spacing: 10) {
                TextField("Search clipboard history", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Search clipboard history")
                    .accessibilityHint("Filters recorded pasteboard items matching the search query")

                Button("Clear Unpinned", role: .destructive) {
                    records.removeAll { !$0.pinned }
                    save()
                    message = "Cleared unpinned clipboard items."
                }
                .disabled(records.allSatisfy(\.pinned))
                .accessibilityLabel("Clear unpinned items")
                .accessibilityHint("Deletes all unpinned clipboard records from history")

                Button("Clear All", role: .destructive) {
                    records.removeAll()
                    save()
                    message = "Cleared all clipboard items."
                }
                .disabled(records.isEmpty)
                .accessibilityLabel("Clear all items")
                .accessibilityHint("Deletes all clipboard records including pinned items")
            }

            HStack {
                Label("\(records.count) items", systemImage: "number")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(records.count) clipboard items stored, maximum \(maxTotalRecords)")

                if records.contains(where: \.pinned) {
                    Label("\(records.filter(\.pinned).count) pinned", systemImage: "pin.fill")
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(records.filter(\.pinned).count) pinned items, maximum \(maxPinnedRecords)")
                }
                Spacer()
                Text("Sensitive pasteboard types are ignored")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityLabel("Privacy protection: Sensitive pasteboard types like passwords or concealed data are ignored")
            }

            if filteredRecords.isEmpty {
                ContentUnavailableView("Clipboard Empty", systemImage: "doc.on.clipboard", description: Text("Copy text in another app to build a local history."))
                    .accessibilityLabel("Clipboard history empty. Copy text in another application to build local history.")
            } else {
                List(filteredRecords) { record in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: record.pinned ? "pin.fill" : "doc.on.clipboard")
                            .foregroundStyle(record.pinned ? .orange : .secondary)
                            .frame(width: 18)
                            .accessibilityHidden(true)

                        Text(record.value)
                            .lineLimit(3)
                            .textSelection(.enabled)
                            .accessibilityLabel(record.pinned ? "Pinned item: \(record.value)" : "Clipboard item: \(record.value)")
                            .accessibilityHint("Created on \(record.createdAt.formatted(date: .numeric, time: .shortened))")

                        Spacer()

                        Button { copy(record) } label: { Image(systemName: "doc.on.doc") }
                            .buttonStyle(.borderless)
                            .help("Copy")
                            .accessibilityLabel("Copy item")
                            .accessibilityHint("Copies this item content to system clipboard")

                        Button { paste(record) } label: { Image(systemName: "arrow.right.doc.on.clipboard") }
                            .buttonStyle(.borderless)
                            .help("Copy and paste")
                            .accessibilityLabel("Paste item")
                            .accessibilityHint("Copies content and sends Command-V paste keystroke")

                        Button { togglePin(record) } label: { Image(systemName: record.pinned ? "pin.slash" : "pin") }
                            .buttonStyle(.borderless)
                            .help(record.pinned ? "Unpin" : "Pin")
                            .accessibilityLabel(record.pinned ? "Unpin item" : "Pin item")
                            .accessibilityHint(record.pinned ? "Unpins item so it can rotate out when full" : "Pins item to prevent automatic removal")
                    }
                    .padding(.vertical, 4)
                    .contextMenu {
                        Button(record.pinned ? "Unpin" : "Pin") { togglePin(record) }
                        Button("Copy") { copy(record) }
                        Button("Copy Without Formatting") { copy(record, removeFormatting: true) }
                        Button("Delete", role: .destructive) { delete(record) }
                    }
                }
                .listStyle(.inset)
                .accessibilityLabel("Clipboard history list")
            }

            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Status message: \(message)")
            }
        }
        .padding(24)
        .onAppear {
            load()
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                Task { @MainActor in
                    poll()
                }
            }
        }
        .onDisappear { timer?.invalidate() }
    }

    private func load() {
        let decoded = (try? JSONDecoder().decode([clipboardrecord].self, from: storedRecords)) ?? []
        records = decoded
        enforceCaps()
        save()
    }

    private func save() {
        storedRecords = (try? JSONEncoder().encode(records)) ?? Data()
    }

    private func enforceCaps() {
        records = records.map { record in
            if record.value.count > maxItemCharacterCount {
                return clipboardrecord(
                    id: record.id,
                    value: String(record.value.prefix(maxItemCharacterCount)),
                    pinned: record.pinned,
                    createdAt: record.createdAt
                )
            }
            return record
        }

        var pinned = records.filter(\.pinned)
        if pinned.count > maxPinnedRecords {
            pinned = Array(pinned.prefix(maxPinnedRecords))
        }

        let remainingCapacity = max(0, maxTotalRecords - pinned.count)
        var unpinned = records.filter { !$0.pinned }
        if unpinned.count > remainingCapacity {
            unpinned = Array(unpinned.prefix(remainingCapacity))
        }

        records = pinned + unpinned
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastCount else { return }
        lastCount = pasteboard.changeCount
        let types = Set(pasteboard.types ?? [])
        let ignoredTypes: Set<NSPasteboard.PasteboardType> = [
            NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
            NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
            NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")
        ]
        guard types.isDisjoint(with: ignoredTypes), let rawValue = pasteboard.string(forType: .string), !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let value = rawValue.count > maxItemCharacterCount ? String(rawValue.prefix(maxItemCharacterCount)) : rawValue
        guard records.first?.value != value else { return }

        records.insert(clipboardrecord(id: UUID(), value: value, pinned: false, createdAt: Date()), at: 0)
        enforceCaps()
        save()
    }

    private func togglePin(_ record: clipboardrecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        let isCurrentlyPinned = records[index].pinned
        if !isCurrentlyPinned {
            let currentPinnedCount = records.filter(\.pinned).count
            guard currentPinnedCount < maxPinnedRecords else {
                message = "Maximum pinned items limit (\(maxPinnedRecords)) reached."
                return
            }
        }
        records[index].pinned.toggle()
        records.sort { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned && !rhs.pinned }
            return lhs.createdAt > rhs.createdAt
        }
        enforceCaps()
        save()
    }

    private func delete(_ record: clipboardrecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    private func copy(_ record: clipboardrecord, removeFormatting: Bool = false) {
        NSPasteboard.general.clearContents()
        let textToCopy = removeFormatting ? record.value.trimmingCharacters(in: .whitespacesAndNewlines) : record.value
        NSPasteboard.general.setString(textToCopy, forType: .string)
        lastCount = NSPasteboard.general.changeCount
        message = "Copied clipboard item."
    }

    private func paste(_ record: clipboardrecord) {
        copy(record)
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
        message = "Pasted clipboard item. Accessibility permission may be required."
    }
}
