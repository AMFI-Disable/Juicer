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

    func testTCCViewerManagerSampleDataHandling() {
        let manager = TCCViewerManager.shared
        let mockItems = manager.getMockPermissions()
        XCTAssertFalse(mockItems.isEmpty)
        XCTAssertTrue(mockItems.allSatisfy(\.isSampleData))

        let expectation = expectation(description: "Sample revocation rejected")
        manager.resetPermission(for: mockItems[0]) { success, message in
            XCTAssertFalse(success)
            XCTAssertTrue(message.contains("Cannot revoke permissions for sample data"))
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    @MainActor
    func testPrivacyScannerManagerScanningCancellationAndFiltering() async {
        let manager = PrivacyScannerManager()
        XCTAssertEqual(manager.state, .idle)

        let fallback = PrivacyScannerEngine.getFallbackSampleRecords()
        XCTAssertFalse(fallback.isEmpty)
        XCTAssertTrue(fallback.allSatisfy { $0.confidence == .low })

        let mappedCat = PrivacyScannerEngine.mapTCCServiceToCategory("kTCCServiceMicrophone")
        XCTAssertEqual(mappedCat, .microphone)

        manager.startScan()
        manager.cancelScan()
        XCTAssertEqual(manager.state, .cancelled)
    }

    func testNetworkExposureParserLoopbackAndWildcardHandling() {
        let sampleLsofOutput = """
COMMAND     PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
ControlCe   735 even   11u  IPv4 0x3e416a4255974d00      0t0  TCP *:7000 (LISTEN)
Ollama     1047 even    4u  IPv4 0x48828274edca2946      0t0  TCP 127.0.0.1:49183 (LISTEN)
custom_app 2048 even    5u  IPv4 0x1234567890abcdef      0t0  TCP 192.168.1.50:8080 (LISTEN)
"""
        let parsed = NetworkExposureParser.parseLsofOutput(sampleLsofOutput)
        XCTAssertEqual(parsed.count, 3)

        let controlCenter = parsed.first { $0.processName == "ControlCe" }
        XCTAssertNotNil(controlCenter)
        XCTAssertEqual(controlCenter?.classification, .wildcardPublic)
        XCTAssertEqual(controlCenter?.port, 7000)

        let ollama = parsed.first { $0.processName == "Ollama" }
        XCTAssertNotNil(ollama)
        XCTAssertEqual(ollama?.classification, .localLoopback)
        XCTAssertEqual(ollama?.port, 49183)

        let customApp = parsed.first { $0.processName == "custom_app" }
        XCTAssertNotNil(customApp)
        XCTAssertEqual(customApp?.classification, .specificIP)
        XCTAssertEqual(customApp?.bindAddress, "192.168.1.50")
    }

    func testAPIEnvironmentInterpolator() {
        let template = "{{baseUrl}}/v1/{{endpoint}}?token={{token}}"
        let variables = ["baseUrl": "https://api.example.com", "endpoint": "users", "token": "secret123"]
        let interpolated = APIEnvironmentInterpolator.interpolate(template, variables: variables)
        XCTAssertEqual(interpolated, "https://api.example.com/v1/users?token=secret123")
    }

    @MainActor
    func testPrivilegedOperationManagerStatusCheck() {
        let manager = PrivilegedOperationManager.shared
        manager.checkStatus()
        XCTAssertNotNil(manager.daemonStatus)
    }

    func testCommandExecutorTimeoutHandling() {
        let executor = CommandExecutor.shared

        // 1. Command exceeding timeout
        let timeoutResult = executor.run(
            executablePath: "/bin/sleep",
            arguments: ["2"],
            timeout: 0.05
        )
        XCTAssertFalse(timeoutResult.succeeded)
        XCTAssertTrue(timeoutResult.didTimeOut)
        XCTAssertTrue(timeoutResult.wasTerminated)
        XCTAssertFalse(timeoutResult.wasCancelled)
        XCTAssertNil(timeoutResult.launchError)

        // 2. Command completing within timeout
        let successResult = executor.run(
            executablePath: "/bin/echo",
            arguments: ["timeout-test"],
            timeout: 5.0
        )
        XCTAssertTrue(successResult.succeeded)
        XCTAssertFalse(successResult.didTimeOut)
        XCTAssertFalse(successResult.wasTerminated)
        XCTAssertFalse(successResult.wasCancelled)
        XCTAssertEqual(successResult.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines), "timeout-test")

        // 3. Cancellation taking precedence during execution
        let cancelledResult = executor.run(
            executablePath: "/bin/sleep",
            arguments: ["2"],
            timeout: 5.0,
            cancellationCheck: { true }
        )
        XCTAssertFalse(cancelledResult.succeeded)
        XCTAssertFalse(cancelledResult.didTimeOut)
        XCTAssertTrue(cancelledResult.wasCancelled)
        XCTAssertTrue(cancelledResult.wasTerminated)
    }

    func testDestructivePathValidatorProtectedPathBounds() throws {
        try withTemporaryDirectory { directory in
            let home = directory.appendingPathComponent("user_home")
            let workspace = directory.appendingPathComponent("workspace_root")
            let allowedFolder = directory.appendingPathComponent("allowed_cache")
            let explicitlyAuthFile = directory.appendingPathComponent("authorized_special.log")

            try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: allowedFolder, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: explicitlyAuthFile.path, contents: nil)

            let validator = DestructivePathValidator(
                homeDirectory: home,
                workspaceRoot: workspace,
                allowedRoots: [allowedFolder],
                explicitlyAuthorizedPaths: [explicitlyAuthFile.path]
            )

            // Protected root bounds
            XCTAssertThrowsError(try validator.validate("/")) { error in
                XCTAssertEqual(error as? DestructivePathValidationError, .unsafeProtectedPath("/"))
            }
            XCTAssertThrowsError(try validator.validate("//")) { error in
                XCTAssertEqual(error as? DestructivePathValidationError, .unsafeProtectedPath("/"))
            }
            XCTAssertThrowsError(try validator.validate(home.path)) { error in
                XCTAssertEqual(error as? DestructivePathValidationError, .unsafeProtectedPath(home.resolvingSymlinksInPath().path))
            }
            XCTAssertThrowsError(try validator.validate(home.path + "/")) { error in
                XCTAssertEqual(error as? DestructivePathValidationError, .unsafeProtectedPath(home.resolvingSymlinksInPath().path))
            }
            XCTAssertThrowsError(try validator.validate(workspace.path)) { error in
                XCTAssertEqual(error as? DestructivePathValidationError, .unsafeProtectedPath(workspace.resolvingSymlinksInPath().path))
            }

            // Explicitly authorized override
            XCTAssertEqual(try validator.validate(explicitlyAuthFile.path).path, explicitlyAuthFile.resolvingSymlinksInPath().path)

            // Allowed roots scope bounds
            let insideAllowed = allowedFolder.appendingPathComponent("sub/data.tmp")
            XCTAssertEqual(try validator.validate(insideAllowed.path).path, insideAllowed.resolvingSymlinksInPath().path)

            let siblingFolder = directory.appendingPathComponent("allowed_cache_sibling")
            XCTAssertThrowsError(try validator.validate(siblingFolder.path)) { error in
                guard case .outsideAllowedScope = error as? DestructivePathValidationError else {
                    return XCTFail("Expected outsideAllowedScope, got \(error)")
                }
            }

            // Invalid format bounds
            XCTAssertThrowsError(try validator.validate("")) { error in
                XCTAssertEqual(error as? DestructivePathValidationError, .emptyPath)
            }
            XCTAssertThrowsError(try validator.validate("   \n")) { error in
                XCTAssertEqual(error as? DestructivePathValidationError, .emptyPath)
            }
            XCTAssertThrowsError(try validator.validate("relative/path")) { error in
                XCTAssertEqual(error as? DestructivePathValidationError, .pathMustBeAbsolute("relative/path"))
            }
        }
    }

    func testNetworkExposureParserSocketAddressNormalization() {
        let lsofOutput = """
COMMAND     PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
app1       1001 user   10u  IPv6 0x1111111111111111      0t0  TCP [::1]:8080 (LISTEN)
app2       1002 user   11u  IPv6 0x2222222222222222      0t0  TCP [::]:443 (LISTEN)
app3       1003 user   12u  IPv6 0x3333333333333333      0t0  TCP [fe80::1]:2222 (LISTEN)
app4       1004 user   14u  IPv4 0x4444444444444444      0t0  TCP 0.0.0.0:80 (LISTEN)
app5       1005 user   15u  IPv4 0x5555555555555555      0t0  TCP localhost:3000 (LISTEN)
invalid1   1006 user   16u  IPv4 0x6666666666666666      0t0  TCP 127.0.0.1:invalid (LISTEN)
invalid2   1007 user   17u  IPv4 0x7777777777777777      0t0  TCP 127.0.0.1:70000 (LISTEN)
invalid3   -10  user   18u  IPv4 0x8888888888888888      0t0  TCP 127.0.0.1:8000 (LISTEN)
"""
        let parsed = NetworkExposureParser.parseLsofOutput(lsofOutput)

        // Should parse the 5 valid records and filter out invalid ones
        XCTAssertEqual(parsed.count, 5)

        // Records should be sorted by port (80, 443, 2222, 3000, 8080)
        XCTAssertEqual(parsed.map(\.port), [80, 443, 2222, 3000, 8080])

        // Bracketed IPv6 loopback [::1]:8080
        let app1 = parsed.first { $0.processName == "app1" }
        XCTAssertNotNil(app1)
        XCTAssertEqual(app1?.classification, .localLoopback)
        XCTAssertEqual(app1?.interface, "Loopback (lo0)")
        XCTAssertEqual(app1?.bindAddress, "[::1]")

        // Bracketed IPv6 wildcard [::]:443
        let app2 = parsed.first { $0.processName == "app2" }
        XCTAssertNotNil(app2)
        XCTAssertEqual(app2?.classification, .wildcardPublic)
        XCTAssertEqual(app2?.interface, "All Interfaces (*)")

        // Bracketed IPv6 specific IP [fe80::1]:2222
        let app3 = parsed.first { $0.processName == "app3" }
        XCTAssertNotNil(app3)
        XCTAssertEqual(app3?.classification, .specificIP)
        XCTAssertEqual(app3?.interface, "[fe80::1]")

        // IPv4 wildcard 0.0.0.0:80
        let app4 = parsed.first { $0.processName == "app4" }
        XCTAssertNotNil(app4)
        XCTAssertEqual(app4?.classification, .wildcardPublic)
        XCTAssertEqual(app4?.interface, "All Interfaces (*)")

        // Localhost name localhost:3000
        let app5 = parsed.first { $0.processName == "app5" }
        XCTAssertNotNil(app5)
        XCTAssertEqual(app5?.classification, .localLoopback)
        XCTAssertEqual(app5?.interface, "Loopback (lo0)")
    }

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("juicer-rel-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }
}

