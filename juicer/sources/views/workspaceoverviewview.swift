import SwiftUI
import AppKit

struct workspaceoverviewview: View {
    let workspace: JuicerWorkspace
    let items: [NavigationItem]
    let favorites: [NavigationItem]
    let recent: [NavigationItem]
    let onSelect: (NavigationItem) -> Void

    private var groupedItems: [(String, [NavigationItem])] {
        Dictionary(grouping: items, by: \.subcategory)
            .map { ($0.key, $0.value.sorted { $0.title < $1.title }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if !favorites.isEmpty {
                    overviewSection("Favorites", icon: "star.fill") {
                        toolRow(items: favorites)
                    }
                }

                if !recent.isEmpty {
                    overviewSection("Continue where you left off", icon: "clock.arrow.circlepath") {
                        toolRow(items: recent)
                    }
                }

                ForEach(groupedItems, id: \.0) { group in
                    overviewSection(group.0, icon: icon(for: group.1)) {
                        toolRow(items: group.1)
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(workspace.title, systemImage: workspace.iconName)
                .font(.largeTitle.bold())
                .foregroundStyle(workspace.themeColor)
            Text(workspace.description)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Choose an area to get started. Tools share this workspace so results and follow-up actions stay close together.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func overviewSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
            content()
        }
    }

    private func toolRow(items: [NavigationItem]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
            ForEach(items) { item in
                Button { onSelect(item) } label: {
                    HStack(spacing: 10) {
                        JuicerSymbol(name: item.iconName, fallback: "square.grid.2x2")
                            .frame(width: 22)
                            .foregroundStyle(workspace.themeColor)
                        Text(item.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
            }
        }
    }

    private func icon(for items: [NavigationItem]) -> String {
        items.first?.iconName ?? "square.grid.2x2"
    }
}
