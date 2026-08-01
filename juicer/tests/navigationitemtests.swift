import XCTest
@testable import Juicer

final class navigationitemtests: XCTestCase {
    func testWorkspaceMetadataIsStable() {
        XCTAssertEqual(JuicerWorkspace.hub.id, "Juicer Hub Studio")
        XCTAssertEqual(JuicerWorkspace.containers.title, "Juicer Docker Studio")
        XCTAssertEqual(JuicerWorkspace.creator.description, "Explore open-source software, clone repositories, and copy brew formulas by amfi-disable.")

        for workspace in JuicerWorkspace.allCases {
            XCTAssertFalse(workspace.id.isEmpty)
            XCTAssertEqual(workspace.id, workspace.rawValue)
            XCTAssertEqual(workspace.title, workspace.rawValue)
            XCTAssertFalse(workspace.iconName.isEmpty)
            XCTAssertFalse(workspace.description.isEmpty)
        }
    }

    func testNavigationItemIdentifiersAndTitlesAreStable() {
        let identifiers = NavigationItem.allCases.map(\.rawValue)

        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        XCTAssertEqual(NavigationItem.dashboard.id, .dashboard)
        XCTAssertEqual(NavigationItem.juicerGit.title, "Git Studio & Workbench")

        for item in NavigationItem.allCases {
            XCTAssertEqual(item.id, item)
            XCTAssertFalse(item.title.isEmpty)
            XCTAssertFalse(item.iconName.isEmpty)
        }
    }

    func testNavigationItemsMapToExpectedWorkspaces() {
        let expectedMappings: [(NavigationItem, JuicerWorkspace)] = [
            (.juicerGit, .git),
            (.dockerDashboard, .containers),
            (.aiWorkbench, .ai),
            (.sqliteInspector, .database),
            (.apiWorkbench, .api),
            (.docConverter, .converter),
            (.appStore, .store),
            (.creatorRepos, .creator),
            (.systemOptimizer, .configs),
            (.speedTest, .network),
            (.fileVault, .security),
            (.diskExplorer, .disk),
            (.sdkSwitcher, .developer),
            (.clipboardManager, .utilities)
        ]

        for (item, workspace) in expectedMappings {
            XCTAssertEqual(item.workspace, workspace, "Unexpected workspace for \\(item.rawValue)")
        }
    }
}
