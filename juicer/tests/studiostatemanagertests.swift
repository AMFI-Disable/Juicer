import XCTest
@testable import Juicer

final class studiostatemanagertests: XCTestCase {
    override func setUp() {
        super.setUp()
        StudioStateManager.shared.reset()
    }

    override func tearDown() {
        StudioStateManager.shared.reset()
        super.tearDown()
    }

    func testLazyLoadingInitialState() {
        let manager = StudioStateManager.shared
        XCTAssertNil(manager.activeWorkspace)
    }

    func testWorkspaceOnDemandInitialization() {
        let manager = StudioStateManager.shared

        manager.activateWorkspace(.ai)
        XCTAssertEqual(manager.activeWorkspace, .ai)
        XCTAssertTrue(manager.activeStudioManagerNames.contains("AIManager"))

        manager.activateWorkspace(.database)
        XCTAssertEqual(manager.activeWorkspace, .database)
        XCTAssertTrue(manager.activeStudioManagerNames.contains("DatabaseManager"))

        manager.activateWorkspace(.containers)
        XCTAssertEqual(manager.activeWorkspace, .containers)
        XCTAssertTrue(manager.activeStudioManagerNames.contains("DockerManager"))

        manager.activateWorkspace(.api)
        XCTAssertEqual(manager.activeWorkspace, .api)
        XCTAssertTrue(manager.activeStudioManagerNames.contains("APIManager"))

        manager.activateWorkspace(.converter)
        XCTAssertEqual(manager.activeWorkspace, .converter)
        XCTAssertTrue(manager.activeStudioManagerNames.contains("ConverterManager"))
    }

    func testMemoryFootprintPurgeOnWorkspaceSwitch() {
        let manager = StudioStateManager.shared
        manager.activateWorkspace(.database)

        let expectation = expectation(description: "Purge inactive workspace memory")
        manager.activateWorkspace(.ai)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            XCTAssertFalse(manager.activeStudioManagerNames.contains("DatabaseManager"))
            XCTAssertTrue(manager.activeStudioManagerNames.contains("AIManager"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
