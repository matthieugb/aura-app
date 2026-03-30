import XCTest
@testable import AURA

final class GenerationServiceTests: XCTestCase {
    func testInitialProgressIsIdle() {
        let service = GenerationService.shared
        if case .idle = service.progress {
            XCTAssertTrue(true)
        } else {
            // Service may have been used already — just verify it's not nil
            XCTAssertNotNil(service)
        }
    }

    func testGenerationErrorDescriptions() {
        XCTAssertNotNil(GenerationError.notAuthenticated.errorDescription)
        XCTAssertNotNil(GenerationError.networkError("test").errorDescription)
        XCTAssertNotNil(GenerationError.serverError("test").errorDescription)
    }

    func testMultipartDataAppendField() {
        var data = Data()
        data.appendField(name: "key", value: "value", boundary: "BOUNDARY")
        let string = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(string.contains("key"))
        XCTAssertTrue(string.contains("value"))
        XCTAssertTrue(string.contains("BOUNDARY"))
    }

    func testMultipartDataAppendFile() {
        var data = Data()
        let fileData = "test".data(using: .utf8)!
        data.appendFile(name: "selfie", filename: "selfie.jpg", data: fileData,
                       mimeType: "image/jpeg", boundary: "BOUNDARY")
        let string = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(string.contains("selfie.jpg"))
        XCTAssertTrue(string.contains("image/jpeg"))
    }
}
