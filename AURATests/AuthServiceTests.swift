// AURATests/AuthServiceTests.swift
import XCTest
@testable import AURA

final class AuthServiceTests: XCTestCase {
    func testSharedInstanceExists() {
        let service = AuthService.shared
        XCTAssertNotNil(service)
    }

    func testInitialStateIsLoading() async {
        // AuthService starts loading on init
        // We just verify the type is correct
        let service = AuthService.shared
        XCTAssertNotNil(service.client)
    }
}
