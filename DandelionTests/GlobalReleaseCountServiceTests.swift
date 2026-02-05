import XCTest
@testable import Dandelion

final class GlobalReleaseCountServiceTests: XCTestCase {
    func testDayKeyUsesUtcDate() {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2025
        components.month = 12
        components.day = 31
        components.hour = 23
        components.minute = 59
        components.second = 59

        let date = components.date!
        XCTAssertEqual(GlobalReleaseCountService.dayKey(for: date), "2025-12-31")
    }
}
