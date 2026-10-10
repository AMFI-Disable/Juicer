import XCTest
@testable import Juicer

final class studiocontextbridgetests: XCTestCase {

    override func setUp() {
        super.setUp()
        StudioContextBridgeManager.shared.clearPayload()
    }

    override func tearDown() {
        StudioContextBridgeManager.shared.clearPayload()
        super.tearDown()
    }

    func testContextPayloadInitialization() {
        let payload = ContextPayload(
            pid: 1234,
            processName: "node",
            urlString: "http://localhost:8080",
            folderURL: URL(fileURLWithPath: "/tmp/myrepo"),
            port: 8080,
            searchQuery: "1234",
            sourceStudio: .network
        )

        XCTAssertEqual(payload.pid, 1234)
        XCTAssertEqual(payload.processName, "node")
        XCTAssertEqual(payload.urlString, "http://localhost:8080")
        XCTAssertEqual(payload.folderURL?.path, "/tmp/myrepo")
        XCTAssertEqual(payload.port, 8080)
        XCTAssertEqual(payload.searchQuery, "1234")
        XCTAssertEqual(payload.sourceStudio, .network)
    }

    func testInspectPIDInSystemStudio() {
        let expectation = expectation(description: "Bridge notification posted for Inspect PID")

        let token = NotificationCenter.default.addObserver(
            forName: StudioContextBridgeManager.bridgeNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let target = notification.object as? NavigationItem else {
                XCTFail("Missing target NavigationItem")
                return
            }
            XCTAssertEqual(target, .portListener)
            XCTAssertEqual(target.workspace, .network)

            if let payload = notification.userInfo?["payload"] as? ContextPayload {
                XCTAssertEqual(payload.pid, 999)
                XCTAssertEqual(payload.processName, "python3")
                XCTAssertEqual(payload.sourceStudio, .network)
            } else {
                XCTFail("Missing ContextPayload in userInfo")
            }
            expectation.fulfill()
        }

        StudioContextBridgeManager.shared.inspectPIDInSystemStudio(pid: 999, processName: "python3", sourceStudio: .network)

        waitForExpectations(timeout: 2.0)
        NotificationCenter.default.removeObserver(token)
    }

    func testTestEndpointInAPIStudio() {
        let expectation = expectation(description: "Bridge notification posted for Test Endpoint")

        let token = NotificationCenter.default.addObserver(
            forName: StudioContextBridgeManager.bridgeNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let target = notification.object as? NavigationItem else {
                XCTFail("Missing target NavigationItem")
                return
            }
            XCTAssertEqual(target, .apiWorkbench)
            XCTAssertEqual(target.workspace, .api)

            if let payload = notification.userInfo?["payload"] as? ContextPayload {
                XCTAssertEqual(payload.urlString, "http://127.0.0.1:8080")
                XCTAssertEqual(payload.sourceStudio, .containers)
            } else {
                XCTFail("Missing ContextPayload in userInfo")
            }
            expectation.fulfill()
        }

        StudioContextBridgeManager.shared.testEndpointInAPIStudio(urlString: "http://127.0.0.1:8080", sourceStudio: .containers)

        waitForExpectations(timeout: 2.0)
        NotificationCenter.default.removeObserver(token)
    }

    func testServeFolderInDeveloperStudio() {
        let expectation = expectation(description: "Bridge notification posted for Serve Folder")
        let repoURL = URL(fileURLWithPath: "/Users/test/project")

        let token = NotificationCenter.default.addObserver(
            forName: StudioContextBridgeManager.bridgeNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let target = notification.object as? NavigationItem else {
                XCTFail("Missing target NavigationItem")
                return
            }
            XCTAssertEqual(target, .localWebServer)
            XCTAssertEqual(target.workspace, .developer)

            if let payload = notification.userInfo?["payload"] as? ContextPayload {
                XCTAssertEqual(payload.folderURL, repoURL)
                XCTAssertEqual(payload.sourceStudio, .git)
            } else {
                XCTFail("Missing ContextPayload in userInfo")
            }
            expectation.fulfill()
        }

        StudioContextBridgeManager.shared.serveFolderInDeveloperStudio(url: repoURL, sourceStudio: .git)

        waitForExpectations(timeout: 2.0)
        NotificationCenter.default.removeObserver(token)
    }
}
