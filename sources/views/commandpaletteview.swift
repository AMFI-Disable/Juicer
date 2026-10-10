import SwiftUI

struct commandpaletteview: View {
    var onSelect: ((NavigationItem) -> Void)?
    var onNavigate: ((JuicerWorkspace, NavigationItem?) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = CommandPaletteManager.shared

    @State private var query = ""
    @State private var selectedCategory: CommandPaletteCategory = .all
    @State private var selectedID: String?
    @FocusState private var isSearchFocused: Bool

    init(onSelect: @escaping (NavigationItem) -> Void) {
        self.onSelect = onSelect
        self.onNavigate = { _, item in
            if let item = item {
                onSelect(item)
            }
        }
    }

    init(onNavigate: @escaping (JuicerWorkspace, NavigationItem?) -> Void) {
        self.onSelect = nil
        self.onNavigate = onNavigate
    }

    private var results: [CommandItem] {
        manager.search(query: query, category: selectedCategory)
    }

    private var isViewingRecents: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !manager.getRecentCommands().isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Search Input Bar
            HStack(spacing: 12) {
                Image(systemName: "command")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.tint)

                TextField("Search 15 studios & 100+ utilities (Cmd + K)…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused($isSearchFocused)
                    .onSubmit {
                        executeSelectedCommand()
                    }

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Text("esc")
                    .font(.caption2.monospaced().weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // Category Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(CommandPaletteCategory.allCases) { category in
                        Button {
                            selectedCategory = category
                            updateSelectionForCurrentResults()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: category.iconName)
                                    .font(.caption2)
                                Text(category.rawValue)
                                    .font(.caption.weight(.medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                selectedCategory == category
                                    ? Color.accentColor
                                    : Color.secondary.opacity(0.12),
                                in: Capsule()
                            )
                            .foregroundStyle(
                                selectedCategory == category
                                    ? Color.white
                                    : Color.primary
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(NSColor.windowBackgroundColor).opacity(0.6))

            Divider()

            // Results Content Area
            if results.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No matching tools or studios found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Try searching for terms like 'git', 'docker', 'cleaner', 'ports', or select 'All'.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)

                    if selectedCategory != .all {
                        Button("Clear Category Filter") {
                            selectedCategory = .all
                            updateSelectionForCurrentResults()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .padding(.top, 4)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    // Section header indicator
                    HStack {
                        Text(isViewingRecents ? "RECENTLY USED" : "SEARCH RESULTS (\(results.count))")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        if isViewingRecents {
                            Button("Clear History") {
                                manager.clearHistory()
                                updateSelectionForCurrentResults()
                            }
                            .font(.caption2)
                            .buttonStyle(.plain)
                            .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    List(results, selection: $selectedID) { command in
                        Button {
                            executeCommand(command)
                        } label: {
                            HStack(spacing: 12) {
                                JuicerSymbol(name: command.iconName, fallback: "square.grid.2x2")
                                    .font(.title3)
                                    .frame(width: 28, height: 28)
                                    .foregroundStyle(command.workspace.themeColor)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(command.title)
                                            .font(.body.weight(.medium))

                                        if command.item == nil {
                                            Text("STUDIO")
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(Color.accentColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 3))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                    }

                                    Text(command.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if let shortcut = command.shortcut {
                                    Text(shortcut)
                                        .font(.caption.monospaced().weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                                        .foregroundStyle(.secondary)
                                }

                                Image(systemName: "return")
                                    .font(.caption2)
                                    .foregroundStyle(selectedID == command.id ? .primary : .tertiary)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .tag(command.id)
                    }
                    .listStyle(.inset)
                }
            }

            Divider()

            // Footer Bar
            HStack {
                HStack(spacing: 16) {
                    Label("Navigate: ↑ ↓", systemImage: "arrow.up.and.down")
                    Label("Select: ↵", systemImage: "return")
                    Label("Close: esc", systemImage: "escape")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                Spacer()

                Text("\(manager.allCommands.count) items indexed")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 580, height: 540)
        .onAppear {
            isSearchFocused = true
            updateSelectionForCurrentResults()
        }
        .onChange(of: query) { _ in
            updateSelectionForCurrentResults()
        }
        .onExitCommand {
            dismiss()
        }
        .onMoveCommand { direction in
            navigateSelection(direction: direction)
        }
    }

    private func updateSelectionForCurrentResults() {
        if let current = selectedID, results.contains(where: { $0.id == current }) {
            return
        }
        selectedID = results.first?.id
    }

    private func navigateSelection(direction: MoveCommandDirection) {
        guard !results.isEmpty else { return }
        let currentIndex = results.firstIndex(where: { $0.id == selectedID }) ?? 0
        switch direction {
        case .down:
            let nextIndex = min(currentIndex + 1, results.count - 1)
            selectedID = results[nextIndex].id
        case .up:
            let prevIndex = max(currentIndex - 1, 0)
            selectedID = results[prevIndex].id
        default:
            break
        }
    }

    private func executeSelectedCommand() {
        guard let targetID = selectedID ?? results.first?.id,
              let command = results.first(where: { $0.id == targetID }) else {
            return
        }
        executeCommand(command)
    }

    private func executeCommand(_ command: CommandItem) {
        manager.recordSelection(command)

        if let onNavigate = onNavigate {
            onNavigate(command.workspace, command.item)
        } else if let item = command.item, let onSelect = onSelect {
            onSelect(item)
        }

        dismiss()
    }
}
