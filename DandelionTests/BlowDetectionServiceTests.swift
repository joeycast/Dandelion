import XCTest
@testable import Dandelion

final class BlowDetectionServiceTests: XCTestCase {
    func testBlowProgressAdvancesAndResets() {
        let service = BlowDetectionService()
        var now = Date(timeIntervalSinceReferenceDate: 0)
        service.nowProvider = { now }

        service.debugUpdateBlowState(isBlowDetected: true, level: 0.5)
        XCTAssertGreaterThan(service.blowProgress, 0)

        now = Date(timeIntervalSinceReferenceDate: 0.2)
        service.debugUpdateBlowState(isBlowDetected: true, level: 0.5)
        XCTAssertEqual(service.blowProgress, 1)

        service.debugUpdateBlowState(isBlowDetected: false, level: 0.1)
        XCTAssertEqual(service.blowProgress, 0)
    }
}
