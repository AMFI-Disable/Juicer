import XCTest
@testable import Juicer

final class PrivilegedOperationsTests: XCTestCase {

    func testHelperServiceVersionCheck() {
        let service = JuicerHelperService()
        let expectation = expectation(description: "Version check reply")

        service.checkDaemonVersion { version in
            XCTAssertEqual(version, JuicerHelperConstants.version)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testHelperServiceRejectsProtectedPIDTermination() {
        let service = JuicerHelperService()
        let expectation = expectation(description: "Protected PID termination check")

        service.terminateProcess(pid: 1, signal: 9) { success, message in
            XCTAssertFalse(success)
            XCTAssertTrue(message.contains("protected"))
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testHelperServiceRejectsUnallowedCachePurgeScope() {
        let service = JuicerHelperService()
        let expectation = expectation(description: "Unallowed cache purge scope check")

        service.purgeSystemCache(path: "/System/Library/CoreServices") { success, message in
            XCTAssertFalse(success)
            XCTAssertTrue(message.contains("outside allowed cache purge boundaries") || message.contains("does not exist"))
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testHelperServiceRejectsEmptyTCCParameters() {
        let service = JuicerHelperService()
        let expectation = expectation(description: "Empty TCC parameters check")

        service.modifyTCCPermission(client: "", service: "Camera", allow: true) { success, message in
            XCTAssertFalse(success)
            XCTAssertTrue(message.contains("Invalid client"))
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    @MainActor
    func testPrivilegedOperationManagerProtectedPIDRejection() async {
        let manager = PrivilegedOperationManager.shared
        let (success, message) = await manager.executeTerminateProcess(pid: 1)

        XCTAssertFalse(success)
        XCTAssertTrue(message.contains("protected"))
    }

    @MainActor
    func testPrivilegedOperationManagerUnallowedCachePurgeRejection() async {
        let manager = PrivilegedOperationManager.shared
        let (success, message) = await manager.executePurgeSystemCache(targetPath: "/Applications")

        XCTAssertFalse(success)
        XCTAssertTrue(message.contains("outside safe cache purge scope"))
    }
}
