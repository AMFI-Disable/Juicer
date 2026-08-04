import XCTest
@testable import Juicer

final class gitextrasafetytests: XCTestCase {
    func testSanitizeRefNameValidRefs() {
        XCTAssertEqual(GitExtraManager.sanitizeRefName("main"), "main")
        XCTAssertEqual(GitExtraManager.sanitizeRefName("feature/login-v2"), "feature/login-v2")
        XCTAssertEqual(GitExtraManager.sanitizeRefName("fix_bug_123"), "fix_bug_123")
        XCTAssertEqual(GitExtraManager.sanitizeRefName("v1.0.0"), "v1.0.0")
    }

    func testSanitizeRefNameRejectsOptionInjection() {
        XCTAssertNil(GitExtraManager.sanitizeRefName("-d"))
        XCTAssertNil(GitExtraManager.sanitizeRefName("--help"))
        XCTAssertNil(GitExtraManager.sanitizeRefName("-rf"))
        XCTAssertNil(GitExtraManager.sanitizeRefName("--output=/tmp/hacked"))
    }

    func testSanitizeRefNameRejectsForbiddenCharsAndSequences() {
        XCTAssertNil(GitExtraManager.sanitizeRefName("branch with space"))
        XCTAssertNil(GitExtraManager.sanitizeRefName("branch~1"))
        XCTAssertNil(GitExtraManager.sanitizeRefName("branch^2"))
        XCTAssertNil(GitExtraManager.sanitizeRefName("branch:tag"))
        XCTAssertNil(GitExtraManager.sanitizeRefName("branch?name"))
        XCTAssertNil(GitExtraManager.sanitizeRefName("branch*name"))
        XCTAssertNil(GitExtraManager.sanitizeRefName("branch[0]"))
        XCTAssertNil(GitExtraManager.sanitizeRefName("branch..name"))
        XCTAssertNil(GitExtraManager.sanitizeRefName("branch@{1}"))
        XCTAssertNil(GitExtraManager.sanitizeRefName("branch//name"))
        XCTAssertNil(GitExtraManager.sanitizeRefName("branch.lock"))
        XCTAssertNil(GitExtraManager.sanitizeRefName("branch/"))
        XCTAssertNil(GitExtraManager.sanitizeRefName("branch."))
    }

    func testSanitizeRefNameRejectsReservedRefs() {
        XCTAssertNil(GitExtraManager.sanitizeRefName("HEAD"))
        XCTAssertNil(GitExtraManager.sanitizeRefName("@"))
    }

    func testSanitizeSinceParameter() {
        let manager = GitExtraManager(repoPath: "")
        XCTAssertEqual(manager.sanitizeSinceParameter("7 days ago"), "7 days ago")
        XCTAssertEqual(manager.sanitizeSinceParameter("14 days ago"), "14 days ago")
        XCTAssertEqual(manager.sanitizeSinceParameter("--output=/tmp/hack"), "7 days ago")
        XCTAssertEqual(manager.sanitizeSinceParameter(""), "7 days ago")
    }

    func testInvalidRepositoryPathSetsError() {
        let invalidPath = "/tmp/non_existent_juicer_repo_dir_12345"
        let manager = GitExtraManager(repoPath: invalidPath)
        XCTAssertNotNil(manager.errorMessage)
        XCTAssertTrue(manager.errorMessage?.contains("does not exist") == true)
    }
}
