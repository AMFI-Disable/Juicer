import XCTest
@testable import Juicer

final class commandexecutortests: XCTestCase {
    private let executor = CommandExecutor.shared

    func testCapturesStandardOutputAndStandardErrorSeparately() {
        let result = executor.run(
            executablePath: "/bin/sh",
            arguments: ["-c", "printf output; printf error >&2"]
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.standardOutput, "output")
        XCTAssertEqual(result.standardError, "error")
        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertFalse(result.wasTerminated)
        XCTAssertFalse(result.didTimeOut)
    }

    func testPreservesNonZeroTerminationStatus() {
        let result = executor.run(executablePath: "/usr/bin/false")

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.terminationStatus, 1)
        XCTAssertNil(result.launchError)
    }

    func testReportsLaunchFailure() {
        let result = executor.run(executablePath: "/definitely/not/a/juicer/executable")

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.terminationStatus)
        XCTAssertNotNil(result.launchError)
    }

    func testRejectsRelativeExecutablePath() {
        let result = executor.run(executablePath: "bin/echo", arguments: ["unsafe"])

        XCTAssertFalse(result.succeeded)
        XCTAssertNil(result.terminationStatus)
        XCTAssertEqual(result.launchError?.localizedDescription, "The executable path must be absolute.")
    }

    func testTruncatesCapturedOutputAtConfiguredLimit() {
        let result = executor.run(
            executablePath: "/usr/bin/printf",
            arguments: ["1234567890"],
            maximumOutputBytes: 4
        )

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.standardOutput, "1234")
        XCTAssertTrue(result.standardOutputWasTruncated)
        XCTAssertFalse(result.standardErrorWasTruncated)
        XCTAssertEqual(result.category, .readOnly)
    }

    func testTerminatesTimedOutCommand() {
        let result = executor.run(
            executablePath: "/bin/sleep",
            arguments: ["1"],
            timeout: 0.05
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertTrue(result.wasTerminated)
        XCTAssertTrue(result.didTimeOut)
    }

    func testCancelsLongRunningCommand() {
        var checks = 0
        let result = executor.run(
            executablePath: "/bin/sleep",
            arguments: ["1"],
            timeout: 5,
            cancellationCheck: {
                checks += 1
                return checks >= 3
            }
        )

        XCTAssertFalse(result.succeeded)
        XCTAssertTrue(result.wasTerminated)
        XCTAssertTrue(result.wasCancelled)
        XCTAssertFalse(result.didTimeOut)
    }
}
