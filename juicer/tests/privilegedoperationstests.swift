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

    @MainActor
    func testPrivilegedOperationManagerDaemonStatusTransitions() async {
        let manager = PrivilegedOperationManager.shared

        // 1. DaemonStatus enum case equality
        XCTAssertEqual(DaemonStatus.notInstalled, DaemonStatus.notInstalled)
        XCTAssertEqual(DaemonStatus.enabled, DaemonStatus.enabled)
        XCTAssertEqual(DaemonStatus.requiresApproval, DaemonStatus.requiresApproval)
        XCTAssertEqual(DaemonStatus.failed("err"), DaemonStatus.failed("err"))
        XCTAssertNotEqual(DaemonStatus.notInstalled, DaemonStatus.enabled)
        XCTAssertNotEqual(DaemonStatus.failed("err1"), DaemonStatus.failed("err2"))

        // 2. Initial checkStatus execution
        manager.checkStatus()
        let status = manager.daemonStatus
        let isValidStatus = status == .notInstalled || status == .enabled || status == .requiresApproval || isFailedStatus(status)
        XCTAssertTrue(isValidStatus)

        // 3. Register daemon transition behavior
        let registered = await manager.registerDaemon()
        let postRegister = manager.daemonStatus
        if registered {
            XCTAssertTrue(postRegister == .enabled || postRegister == .requiresApproval)
        } else {
            if case .failed(let errStr) = postRegister {
                XCTAssertEqual(manager.lastError, errStr)
            }
        }

        // 4. Unregister daemon transition behavior
        let unregistered = await manager.unregisterDaemon()
        let postUnregister = manager.daemonStatus
        if unregistered {
            XCTAssertEqual(postUnregister, .notInstalled)
            XCTAssertFalse(manager.isConnected)
        } else {
            if case .failed(let errStr) = postUnregister {
                XCTAssertFalse(errStr.isEmpty)
            }
        }

        // 5. Re-check status consistency
        manager.checkStatus()
        XCTAssertNotNil(manager.daemonStatus)
    }

    private func isFailedStatus(_ status: DaemonStatus) -> Bool {
        if case .failed = status { return true }
        return false
    }
}

