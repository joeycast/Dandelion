import XCTest
@testable import Dandelion

final class ICloudAvailabilityTests: XCTestCase {
    func testStatusSymbolNameForChecking() {
        XCTAssertEqual(ICloudAvailability.checking.statusSymbolName, "icloud.dashed")
    }

    func testStatusSymbolNameForAvailable() {
        XCTAssertEqual(ICloudAvailability.available.statusSymbolName, "checkmark.icloud")
    }

    func testStatusSymbolNameForUnavailable() {
        XCTAssertEqual(ICloudAvailability.unavailable.statusSymbolName, "xmark.icloud")
    }
}
