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

    func testMultiWordSearchQueryScoring() {
        // 1. Exact multi-word title match scores 100
        let exactResults = manager.search(query: "App Uninstaller")
        XCTAssertFalse(exactResults.isEmpty)
        XCTAssertEqual(exactResults.first?.title, "App Uninstaller")
        let exactScore = manager.scoreCommand(exactResults.first!, query: "app uninstaller")
        XCTAssertEqual(exactScore, 100)

        // 2. Multi-word title prefix match scores 80
        let prefixResults = manager.search(query: "App Uninstall")
        XCTAssertFalse(prefixResults.isEmpty)
        XCTAssertEqual(prefixResults.first?.title, "App Uninstaller")
        let prefixScore = manager.scoreCommand(prefixResults.first!, query: "app uninstall")
        XCTAssertEqual(prefixScore, 80)

        // 3. Multi-word query matching subtitle or keyword
        let keywordResults = manager.search(query: "developer tools")
        XCTAssertFalse(keywordResults.isEmpty)

        // 4. Multi-word query with whitespace padding
        let paddedResults = manager.search(query: "   App Uninstaller   ")
        XCTAssertFalse(paddedResults.isEmpty)
        XCTAssertEqual(paddedResults.first?.title, "App Uninstaller")

        // 5. Multi-word workspace title search
        let containerResults = manager.search(query: "containers studio")
        XCTAssertFalse(containerResults.isEmpty)
    }

    func testEmptyResultHandlingAndCategoryMismatch() {
        // 1. Completely non-matching alphanumeric query returns empty list
        let emptyQueryResults = manager.search(query: "xyznonexistent123unmatchable")
        XCTAssertTrue(emptyQueryResults.isEmpty)

        // 2. Special characters with no matches return empty list
        let emptySymbolResults = manager.search(query: "!!!@@@###$$$")
        XCTAssertTrue(emptySymbolResults.isEmpty)

        // 3. Valid search query under mismatched category filter returns empty list
        let categoryMismatchResults = manager.search(query: "App Uninstaller", category: .database)
        XCTAssertTrue(categoryMismatchResults.isEmpty)

        // 4. Searching for Docker under Security category returns empty list
        let dockerSecurityMismatch = manager.search(query: "docker", category: .security)
        XCTAssertTrue(dockerSecurityMismatch.isEmpty)

        // 5. Verify manager operational health after empty searches
        let subsequentValidResults = manager.search(query: "Git")
        XCTAssertFalse(subsequentValidResults.isEmpty)
    }

    func testRecentHistoryPersistenceAndCapacityLimit() {
        // Ensure starting clean
        XCTAssertTrue(manager.getRecentCommands().isEmpty)

        let commands = manager.allCommands
        XCTAssertGreaterThan(commands.count, 12, "Need at least 12 commands to test history limit")

        // 1. Record 12 commands sequentially to test capacity limit (max 10)
        for index in 0..<12 {
            manager.recordSelection(commands[index])
        }

        let recents = manager.getRecentCommands()
        XCTAssertEqual(recents.count, 10, "History should be capped at 10 items")
        XCTAssertEqual(recents[0].id, commands[11].id, "Most recently recorded command should be first")
        XCTAssertEqual(recents[1].id, commands[10].id, "Second most recent command should be second")

        // 2. Re-recording an existing item brings it to the top without increasing count
        let targetRecentID = recents[5].id
        let targetCmd = commands.first(where: { $0.id == targetRecentID })!
        manager.recordSelection(targetCmd)

        let recentsAfterReSelect = manager.getRecentCommands()
        XCTAssertEqual(recentsAfterReSelect.count, 10, "Count should remain capped at 10")
        XCTAssertEqual(recentsAfterReSelect.first?.id, targetRecentID, "Re-selected command should be at index 0")

        // 3. Verify persistence across new manager instances
        let persistentManager = CommandPaletteManager()
        let reloadedRecents = persistentManager.getRecentCommands()
        XCTAssertEqual(reloadedRecents.count, 10)
        XCTAssertEqual(reloadedRecents.first?.id, targetRecentID, "Recents must persist across instances")

        // 4. Verify clearHistory persistence
        persistentManager.clearHistory()
        XCTAssertTrue(persistentManager.getRecentCommands().isEmpty)

        let freshManager = CommandPaletteManager()
        XCTAssertTrue(freshManager.getRecentCommands().isEmpty, "Cleared state must persist to new instances")
    }
}
