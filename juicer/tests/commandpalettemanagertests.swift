import XCTest
@testable import Juicer

final class commandpalettemanagertests: XCTestCase {
    var manager: CommandPaletteManager!

    override func setUp() {
        super.setUp()
        manager = CommandPaletteManager()
        manager.clearHistory()
    }

    override func tearDown() {
        manager.clearHistory()
        manager = nil
        super.tearDown()
    }

    func testIndexingCoversAllStudiosAndUtilities() {
        let allWorkspaces = JuicerWorkspace.allCases
        let allItems = NavigationItem.allCases

        XCTAssertGreaterThanOrEqual(
            manager.allCommands.count,
            allWorkspaces.count + allItems.count,
            "CommandPaletteManager should index all studios and utilities"
        )

        // Verify all 16 Studios are indexed as commands
        let studioCommands = manager.allCommands.filter { $0.item == nil }
        XCTAssertEqual(studioCommands.count, allWorkspaces.count)
        for workspace in allWorkspaces {
            XCTAssertTrue(
                studioCommands.contains(where: { $0.workspace == workspace }),
                "Missing index entry for workspace: \(workspace.rawValue)"
            )
        }

        // Verify all NavigationItems are indexed
        let utilityCommands = manager.allCommands.compactMap(\.item)
        XCTAssertEqual(utilityCommands.count, allItems.count)
        for navItem in allItems {
            XCTAssertTrue(
                utilityCommands.contains(navItem),
                "Missing index entry for utility item: \(navItem.rawValue)"
            )
        }
    }

    func testInstantSearchScoringAndFiltering() {
        // 1. Exact match search
        let exactResults = manager.search(query: "App Uninstaller")
        XCTAssertFalse(exactResults.isEmpty)
        XCTAssertEqual(exactResults.first?.item, .appUninstaller)

        // 2. Keyword / substring search for Docker
        let dockerResults = manager.search(query: "docker")
        XCTAssertFalse(dockerResults.isEmpty)
        XCTAssertTrue(dockerResults.contains(where: { $0.workspace == .containers }))

        // 3. Substring search for Git
        let gitResults = manager.search(query: "git")
        XCTAssertFalse(gitResults.isEmpty)
        XCTAssertTrue(gitResults.contains(where: { $0.workspace == .git }))

        // 4. Non-matching query returns empty list
        let emptyResults = manager.search(query: "xyznonexistent123")
        XCTAssertTrue(emptyResults.isEmpty)
    }

    func testCategoryFiltering() {
        // Filter by System category
        let systemResults = manager.search(query: "", category: .system)
        XCTAssertFalse(systemResults.isEmpty)
        for item in systemResults {
            XCTAssertTrue(
                item.category == .system || manager.categoryForWorkspace(item.workspace) == .system,
                "Item \(item.title) should belong to system category or workspace"
            )
        }

        // Filter by Studios category
        let studioResults = manager.search(query: "", category: .studios)
        XCTAssertFalse(studioResults.isEmpty)
        XCTAssertEqual(studioResults.count, JuicerWorkspace.allCases.count)

        // Filter by AI category
        let aiResults = manager.search(query: "", category: .ai)
        XCTAssertFalse(aiResults.isEmpty)
        for item in aiResults {
            XCTAssertTrue(
                item.category == .ai || manager.categoryForWorkspace(item.workspace) == .ai,
                "Item \(item.title) should belong to AI category or workspace"
            )
        }
    }

    func testRecentHistoryAndScoringBonus() {
        guard let firstCmd = manager.allCommands.first,
              let secondCmd = manager.allCommands.dropFirst().first else {
            XCTFail("Manager commands should not be empty")
            return
        }

        // Initially recents empty
        XCTAssertTrue(manager.getRecentCommands().isEmpty)

        // Record selection
        manager.recordSelection(firstCmd)
        XCTAssertEqual(manager.getRecentCommands().first?.id, firstCmd.id)

        manager.recordSelection(secondCmd)
        XCTAssertEqual(manager.getRecentCommands().first?.id, secondCmd.id)

        // Empty query search should return recent commands first
        let defaultResults = manager.search(query: "")
        XCTAssertEqual(defaultResults.first?.id, secondCmd.id)
        XCTAssertEqual(defaultResults.dropFirst().first?.id, firstCmd.id)

        // Clear history
        manager.clearHistory()
        XCTAssertTrue(manager.getRecentCommands().isEmpty)
    }

    func testCommandItemMetadataIntegrity() {
        for command in manager.allCommands {
            XCTAssertFalse(command.id.isEmpty)
            XCTAssertFalse(command.title.isEmpty)
            XCTAssertFalse(command.subtitle.isEmpty)
            XCTAssertFalse(command.iconName.isEmpty)
            XCTAssertFalse(command.keywords.isEmpty)
        }
    }
}
