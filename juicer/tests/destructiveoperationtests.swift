import XCTest
@testable import Juicer

final class destructiveoperationtests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    func testAggregatesSelectedKnownAndUnknownImpact() {
        let items = [
            item("a", bytes: 10),
            item("b", bytes: nil),
            item("c", bytes: 50, selected: false)
        ]
        XCTAssertEqual(DestructiveOperationImpact.aggregate(items), .init(itemCount: 2, knownByteCount: 10, unknownByteCountItems: 1))
    }

    func testRequiresSelection() {
        XCTAssertThrowsError(try DestructiveOperationFlow(
            identity: .init(title: "Cleanup"),
            items: [item("a", bytes: 1, selected: false)]
        )) { XCTAssertEqual($0 as? DestructiveOperationFlowError, .noSelectedTargets) }
    }

    func testExplicitConfirmationAndSuccessfulStateTransitions() throws {
        var flow = try flow(itemCount: 2)
        try flow.requestConfirmation(now: epoch)
        XCTAssertEqual(flow.manifest.state, .awaitingConfirmation)
        try flow.confirm(phrase: flow.requiredConfirmationText, now: epoch)
        try flow.start(now: epoch)
        try flow.recordProgress(completedItems: 2, now: epoch)
        try flow.finish(now: epoch)
        XCTAssertEqual(flow.manifest.state, .succeeded)
        XCTAssertEqual(flow.manifest.progress.completedItems, 2)
    }

    func testRejectsIncorrectConfirmationPhrase() throws {
        var flow = try flow(itemCount: 1)
        try flow.requestConfirmation()
        XCTAssertThrowsError(try flow.confirm(phrase: "yes")) {
            XCTAssertEqual($0 as? DestructiveOperationFlowError, .confirmationPhraseMismatch)
        }
        XCTAssertEqual(flow.manifest.state, .awaitingConfirmation)
    }

    func testPartialFailureIsNeverReportedAsSuccess() throws {
        var flow = try flow(itemCount: 2)
        try makeRunning(&flow)
        try flow.recordProgress(completedItems: 1)
        try flow.finish(failures: [.init(targetID: nil, targetDisplayName: "target-2", message: "Permission denied")])
        XCTAssertEqual(flow.manifest.state, .partiallyFailed)
        XCTAssertEqual(flow.manifest.failures.count, 1)
    }

    func testCancellationPreservesManifestAndRecovery() throws {
        var flow = try flow(itemCount: 1)
        let originalItems = flow.manifest.previewItems
        try makeRunning(&flow)
        try flow.cancel(reason: "User cancelled", recovery: .init(summary: "No changes made", recoveryPath: nil))
        XCTAssertEqual(flow.manifest.state, .cancelled)
        XCTAssertEqual(flow.manifest.previewItems, originalItems)
        XCTAssertEqual(flow.manifest.recovery?.summary, "No changes made")
    }

    func testManifestSerializationRoundTrip() throws {
        let flow = try flow(itemCount: 2)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(flow.manifest)
        XCTAssertEqual(try JSONDecoder().decode(DestructiveOperationManifest.self, from: data), flow.manifest)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("file contents"))
    }

    func testPathValidatorRejectsEmptyRelativeAndProtectedTargets() throws {
        try withTemporaryDirectory { directory in
            let home = directory.appendingPathComponent("home")
            let workspace = directory.appendingPathComponent("workspace")
            let validator = DestructivePathValidator(homeDirectory: home, workspaceRoot: workspace)
            XCTAssertThrowsError(try validator.validate(""))
            XCTAssertThrowsError(try validator.validate("relative/cache"))
            XCTAssertThrowsError(try validator.validate("/"))
            XCTAssertThrowsError(try validator.validate(home.path))
            XCTAssertThrowsError(try validator.validate(workspace.path))
        }
    }

    func testPathValidatorEnforcesAllowedScopeAndAllowsChild() throws {
        try withTemporaryDirectory { directory in
            let allowed = directory.appendingPathComponent("cache")
            let outside = directory.appendingPathComponent("documents/file")
            let child = allowed.appendingPathComponent("tool/data")
            let validator = DestructivePathValidator(homeDirectory: directory.appendingPathComponent("home"), allowedRoots: [allowed])
            XCTAssertEqual(try validator.validate(child.path).path, child.path)
            XCTAssertThrowsError(try validator.validate(outside.path)) {
                guard case .outsideAllowedScope = $0 as? DestructivePathValidationError else {
                    return XCTFail("Expected outsideAllowedScope, got \($0)")
                }
            }
        }
    }

    func testProgressCannotMoveBackwards() throws {
        var flow = try flow(itemCount: 2)
        try makeRunning(&flow)
        try flow.recordProgress(completedItems: 1)
        XCTAssertThrowsError(try flow.recordProgress(completedItems: 0)) {
            XCTAssertEqual($0 as? DestructiveOperationFlowError, .invalidProgress)
        }
    }

    private func item(_ name: String, bytes: Int64?, selected: Bool = true) -> DestructiveOperationPreviewItem {
        .init(displayName: name, path: "/tmp/juicer-tests/\(name)", kind: .cache, byteCount: bytes, isSelected: selected)
    }

    private func flow(itemCount: Int) throws -> DestructiveOperationFlow {
        try DestructiveOperationFlow(
            identity: .init(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, title: "Cleanup"),
            items: (1...itemCount).map { item("target-\($0)", bytes: Int64($0 * 100)) },
            now: epoch
        )
    }

    private func makeRunning(_ flow: inout DestructiveOperationFlow) throws {
        try flow.requestConfirmation()
        try flow.confirm(phrase: flow.requiredConfirmationText)
        try flow.start()
    }

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("juicer-safety-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }
}
