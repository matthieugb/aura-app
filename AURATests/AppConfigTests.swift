import XCTest
@testable import AURA

final class AppConfigTests: XCTestCase {
    func testCreditsConstants() {
        XCTAssertEqual(AppConfig.Credits.freePhotosPerDay, 5)
        XCTAssertEqual(AppConfig.Credits.premiumAnimationsPerMonth, 20)
    }

    func testEntitlementsConstants() {
        XCTAssertEqual(AppConfig.Entitlements.premium, "premium")
    }
}
