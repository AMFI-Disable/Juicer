import Foundation
import SwiftUI
import Combine

/// Category filter for Command Palette items.
enum CommandPaletteCategory: String, CaseIterable, Identifiable, Hashable, Codable {
    case all = "All"
    case studios = "Studios"
    case system = "System"
    case network = "Network"
    case security = "Security"
    case disk = "Disk"
    case developer = "Developer"
    case git = "Git"
    case containers = "Containers"
    case ai = "AI"
    case database = "Database"
    case api = "API"
    case converter = "Converter"
    case configs = "Configs"
    case utilities = "Utilities"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .all: return "sparkles"
        case .studios: return "square.grid.2x2.fill"
        case .system: return "cpu.fill"
        case .network: return "network"
        case .security: return "lock.shield.fill"
        case .disk: return "internaldrive.fill"
        case .developer: return "terminal.fill"
        case .git: return "arrow.triangle.pull"
        case .containers: return "cube.fill"
        case .ai: return "sparkles"
        case .database: return "cylinder.split.1x2.fill"
        case .api: return "paperplane.fill"
        case .converter: return "arrow.triangle.2.circlepath"
        case .configs: return "slider.horizontal.3"
        case .utilities: return "wrench.and.screwdriver.fill"
        }
    }
}

/// Represents the type of command target.
enum CommandItemKind: Hashable, Equatable {
    case studio(JuicerWorkspace)
    case utility(NavigationItem)
}

/// Model representing a single searchable command entry in Juicer.
struct CommandItem: Identifiable, Hashable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let category: CommandPaletteCategory
    let iconName: String
    let workspace: JuicerWorkspace
    let item: NavigationItem?
    let kind: CommandItemKind
    let keywords: [String]
    let shortcut: String?

    init(
        id: String,
        title: String,
        subtitle: String,
        category: CommandPaletteCategory,
        iconName: String,
        workspace: JuicerWorkspace,
        item: NavigationItem? = nil,
        kind: CommandItemKind,
        keywords: [String] = [],
        shortcut: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.iconName = iconName
        self.workspace = workspace
        self.item = item
        self.kind = kind
        self.keywords = keywords
        self.shortcut = shortcut
    }
}

/// CommandPaletteManager indexes all Studios and Utilities, manages multi-field search scoring, category filtering, and recent history.
final class CommandPaletteManager: ObservableObject {
    static let shared = CommandPaletteManager()

    @Published private(set) var allCommands: [CommandItem] = []
    @Published var recentCommandIDs: [String] = []

    private let historyKey = "juicer.commandpalette.recents"
    private let maxHistoryCount = 10

    init() {
        loadRecents()
        indexCommands()
    }

    /// Index all Studios and Utilities in Juicer
    func indexCommands() {
        var indexed: [CommandItem] = []

        // 1. Index all JuicerWorkspace entries (Studios)
        for workspace in JuicerWorkspace.allCases {
            let item = CommandItem(
                id: "workspace_\(workspace.rawValue)",
                title: workspace.title,
                subtitle: workspace.description,
                category: categoryForWorkspace(workspace),
                iconName: workspace.iconName,
                workspace: workspace,
                item: nil,
                kind: .studio(workspace),
                keywords: [workspace.rawValue, workspace.title, "studio", "workspace"],
                shortcut: shortcutForWorkspace(workspace)
            )
            indexed.append(item)
        }

        // 2. Index all NavigationItem entries (Utilities & Tools)
        for navItem in NavigationItem.allCases {
            let category = categoryForWorkspace(navItem.workspace)
            let item = CommandItem(
                id: "utility_\(navItem.rawValue)",
                title: navItem.title,
                subtitle: "\(navItem.workspace.title) • \(navItem.subcategory)",
                category: category,
                iconName: navItem.iconName,
                workspace: navItem.workspace,
                item: navItem,
                kind: .utility(navItem),
                keywords: [
                    navItem.title,
                    navItem.rawValue,
                    navItem.subcategory,
                    navItem.workspace.title,
                    navItem.workspace.rawValue
                ],
                shortcut: shortcutForNavItem(navItem)
            )
            indexed.append(item)
        }

        self.allCommands = indexed
    }

    /// Map a workspace to its primary CommandPaletteCategory
    func categoryForWorkspace(_ workspace: JuicerWorkspace) -> CommandPaletteCategory {
        switch workspace {
        case .hub, .store, .creator:
            return .studios
        case .system:
            return .system
        case .network:
            return .network
        case .security:
            return .security
        case .disk:
            return .disk
        case .developer:
            return .developer
        case .git:
            return .git
        case .containers:
            return .containers
        case .ai:
            return .ai
        case .database:
            return .database
        case .api:
            return .api
        case .converter:
            return .converter
        case .configs:
            return .configs
        case .utilities:
            return .utilities
        }
    }

    private func shortcutForWorkspace(_ workspace: JuicerWorkspace) -> String? {
        switch workspace {
        case .hub: return "⌘1"
        default: return nil
        }
    }

    private func shortcutForNavItem(_ item: NavigationItem) -> String? {
        switch item {
        case .dashboard: return "⌘1"
        case .appUninstaller: return "⌘2"
        case .orphanScanner: return "⌘3"
        case .devCaches: return "⌘4"
        case .largeFiles: return "⌘5"
        case .hiddenFiles: return "⌘6"
        case .brewExplorer: return "⌘7"
        case .brewGhost: return "⌘8"
        case .serviceManager: return "⌘9"
        case .systemTweaks: return "⌘0"
        default: return nil
        }
    }

    /// Instant Search with multi-field scoring and category filtering
    func search(query: String, category: CommandPaletteCategory = .all) -> [CommandItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Filter by category first if specified
        let categoryFiltered: [CommandItem]
        if category == .all {
            categoryFiltered = allCommands
        } else if category == .studios {
            categoryFiltered = allCommands.filter { $0.item == nil }
        } else {
            categoryFiltered = allCommands.filter { $0.category == category || categoryForWorkspace($0.workspace) == category }
        }

        // Empty query returns recent items first, then remaining indexed items
        if trimmed.isEmpty {
            let recents = getRecentCommands()
            let remaining = categoryFiltered.filter { cmd in !recents.contains(where: { $0.id == cmd.id }) }
            return recents.filter { cmd in categoryFiltered.contains(where: { $0.id == cmd.id }) } + remaining
        }

        // Search scoring
        var scoredItems: [(item: CommandItem, score: Int)] = []

        for command in categoryFiltered {
            let score = scoreCommand(command, query: trimmed)
            if score > 0 {
                let recentBonus = recentCommandIDs.contains(command.id) ? 5 : 0
                scoredItems.append((command, score + recentBonus))
            }
        }

        // Sort by score descending, then title ascending
        scoredItems.sort { a, b in
            if a.score != b.score {
                return a.score > b.score
            }
            return a.item.title.localizedCaseInsensitiveCompare(b.item.title) == .orderedAscending
        }

        return scoredItems.map { $0.item }
    }

    /// Score a command item against search query
    func scoreCommand(_ command: CommandItem, query: String) -> Int {
        let titleLower = command.title.lowercased()
        let subtitleLower = command.subtitle.lowercased()

        // 1. Exact title match
        if titleLower == query {
            return 100
        }

        // 2. Title starts with query
        if titleLower.hasPrefix(query) {
            return 80
        }

        // 3. Any word in title starts with query
        let titleWords = titleLower.split(separator: " ")
        if titleWords.contains(where: { $0.hasPrefix(query) }) {
            return 70
        }

        // 4. Title contains query substring
        if titleLower.contains(query) {
            return 60
        }

        // 5. Keywords match
        for kw in command.keywords {
            let kwLower = kw.lowercased()
            if kwLower == query {
                return 50
            }
            if kwLower.hasPrefix(query) || kwLower.contains(query) {
                return 40
            }
        }

        // 6. Subtitle contains query
        if subtitleLower.contains(query) {
            return 30
        }

        // 7. Workspace title contains query
        if command.workspace.title.lowercased().contains(query) {
            return 20
        }

        return 0
    }

    /// Record selected command in history
    func recordSelection(_ command: CommandItem) {
        var current = recentCommandIDs
        current.removeAll { $0 == command.id }
        current.insert(command.id, at: 0)
        if current.count > maxHistoryCount {
            current = Array(current.prefix(maxHistoryCount))
        }
        recentCommandIDs = current
        saveRecents()
    }

    /// Record selected NavigationItem in history
    func recordSelection(_ item: NavigationItem) {
        if let command = allCommands.first(where: { $0.item == item }) {
            recordSelection(command)
        }
    }

    /// Get list of recent CommandItems
    func getRecentCommands() -> [CommandItem] {
        return recentCommandIDs.compactMap { id in
            allCommands.first(where: { $0.id == id })
        }
    }

    /// Clear search history
    func clearHistory() {
        recentCommandIDs = []
        saveRecents()
    }

    private func loadRecents() {
        if let data = UserDefaults.standard.stringArray(forKey: historyKey) {
            recentCommandIDs = data
        }
    }

    private func saveRecents() {
        UserDefaults.standard.set(recentCommandIDs, forKey: historyKey)
    }
}
