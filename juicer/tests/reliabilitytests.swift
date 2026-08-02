import XCTest
@testable import Juicer

final class reliabilitytests: XCTestCase {
    func testOperationRejectsDuplicateStartAndKeepsProgressMonotonic() {
        var operation = ReliabilityOperation(total: 3)
        XCTAssertTrue(operation.start(at: Date(timeIntervalSince1970: 1)))
        XCTAssertFalse(operation.start())
        operation.update(completed: 2, message: "Two")
        operation.update(completed: 1, message: "Older")
        XCTAssertEqual(operation.snapshot.progress.completed, 2)
        operation.succeed()
        XCTAssertEqual(operation.snapshot.state, .succeeded)
        XCTAssertEqual(operation.snapshot.progress.completed, 3)
    }

    func testOperationTimeoutAndCancellationAreTerminal() {
        var timedOut = ReliabilityOperation(total: 1)
        _ = timedOut.start()
        timedOut.timeOut()
        timedOut.succeed()
        XCTAssertEqual(timedOut.snapshot.state, .timedOut)

        var cancelled = ReliabilityOperation(total: 1)
        _ = cancelled.start()
        cancelled.cancel()
        XCTAssertEqual(cancelled.snapshot.state, .cancelled)
    }

    func testPackageSourcesAreNotMixed() {
        XCTAssertEqual(PackageStatusMapping.resolve(isInstalled: true, isHomebrewManaged: true).state, .installed)
        XCTAssertEqual(PackageStatusMapping.resolve(isInstalled: true, isHomebrewManaged: false).state, .external)
        XCTAssertEqual(PackageStatusMapping.resolve(isInstalled: false, isHomebrewManaged: false).state, .available)
        XCTAssertEqual(PackageStatusMapping.resolve(isInstalled: true, isHomebrewManaged: true, isUpdating: true).state, .updating)
        XCTAssertEqual(PackageStatusMapping.resolve(isInstalled: true, isHomebrewManaged: true, failed: true).state, .failed)
    }

    func testFormulaOutdatedParserUsesInstalledAndLatestVersions() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "formulae": [["name": "jq", "installed_versions": ["1.6"], "current_version": "1.7"]],
            "casks": [["name": "demo", "version": "2.0", "installed_version": "1.0"]]
        ])
        let records = FormulaUpdateParser.parse(json: data)
        XCTAssertEqual(records.first(where: { $0.name == "jq" }), FormulaUpdateRecord(name: "jq", installedVersion: "1.6", latestVersion: "1.7"))
        XCTAssertTrue(records.first(where: { $0.name == "demo" })?.hasUpdate == true)
    }

    func testLaunchctlParserExplainsStatusCodes() {
        let output = "PID Status Label\n-  -9 com.example.killed\n-  -1 com.example.failed\n-  78 com.example.invalid\n42 0 com.example.running\n"
        let services = ServiceStatusParser.parseLaunchctlList(output)
        XCTAssertEqual(services.map(\.status), ["Killed (-9)", "Failed (-1)", "Configuration error (78)", "Running"])
    }

    func testProtectedProcessPolicy() {
        XCTAssertTrue(ProtectedProcessPolicy.isProtected(pid: 1, name: "anything"))
        XCTAssertTrue(ProtectedProcessPolicy.isProtected(pid: 42, name: "launchd"))
        XCTAssertFalse(ProtectedProcessPolicy.isProtected(pid: 42, name: "sample-worker"))
    }

    func testNetworkValidationAndDNSParsing() {
        XCTAssertEqual(NetworkInputValidation.hostname("example.com"), "example.com")
        XCTAssertNil(NetworkInputValidation.hostname("bad host"))
        XCTAssertEqual(NetworkInputValidation.ports("443, 80, 443, 0, 70000"), [80, 443])
        let output = ";; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 1\n;; ANSWER SECTION:\nexample.com. 60 IN A 93.184.216.34\n;; Query time: 12 msec\n;; SERVER: 1.1.1.1#53\n"
        let parsed = DNSDiagnosticParser.parse(output, resolver: "1.1.1.1")
        XCTAssertEqual(parsed.status, "NOERROR")
        XCTAssertEqual(parsed.queryTimeMilliseconds, 12)
        XCTAssertEqual(parsed.answers.first?.value, "93.184.216.34")
    }

    func testNetworkParsersAndOperationIDs() {
        XCTAssertEqual(NetworkInputValidation.bonjourService("_http._tcp"), "_http._tcp")
        XCTAssertNil(NetworkInputValidation.bonjourService("http"))
        let discovery = LANDiscoveryParser.parse("Browsing _http._tcp\nDATE: now\nInstance._http._tcp.local.\n", service: "_http._tcp")
        XCTAssertEqual(discovery.instances, ["Instance._http._tcp.local."])
        var operation = ReliabilityOperation(total: 1)
        XCTAssertTrue(operation.start())
        let firstID = operation.snapshot.id
        operation.succeed()
        XCTAssertTrue(operation.start())
        XCTAssertNotEqual(firstID, operation.snapshot.id)
    }
}
