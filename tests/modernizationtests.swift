import XCTest
@testable import Juicer

final class JuicerModernizationTests: XCTestCase {

    @MainActor
    func testRiskyOptimizationTasksDefaultToUnselected() {
        let manager = SystemOptimizerManager()
        let resetAccessibility = manager.tasks.first { $0.name == "Rebuild Accessibility Database" }
        let tempCleanup = manager.tasks.first { $0.name == "Remove Stale Juicer Temp Files" }
        XCTAssertNotNil(resetAccessibility)
        XCTAssertFalse(resetAccessibility?.isSelected ?? true)
        XCTAssertNotNil(tempCleanup)
        XCTAssertFalse(tempCleanup?.isSelected ?? true)
    }

    @MainActor
    func testCacheCleanerExcludesPhotosMastersAndTmpRoot() {
        let manager = CacheCleanerManager()
        XCTAssertFalse(manager.insights.contains { $0.path == "/tmp" })
        XCTAssertFalse(manager.insights.contains { $0.path.contains("Photos Library.photoslibrary/Masters") })
    }

    func testVPNProfileDecodesWithoutImmutablePropertyWarning() throws {
        let json = #"{"name":"Work VPN","connected":true}"#.data(using: .utf8)!
        let profile = try JSONDecoder().decode(VPNProfile.self, from: json)
        XCTAssertEqual(profile.name, "Work VPN")
        XCTAssertTrue(profile.connected)
    }
}
