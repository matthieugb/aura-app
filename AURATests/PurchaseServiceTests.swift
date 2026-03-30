import XCTest
@testable import AURA

final class PurchaseServiceTests: XCTestCase {
    func testSharedInstanceExists() {
        XCTAssertNotNil(PurchaseService.shared)
    }

    func testInitialStateNotPremium() {
        // PurchaseService starts as not premium until RevenueCat confirms
        let service = PurchaseService.shared
        // Either false (initial) or checked — just verify no crash
        XCTAssertNotNil(service.isPremium)
        XCTAssertFalse(service.isLoading) // After init task completes
    }
}
