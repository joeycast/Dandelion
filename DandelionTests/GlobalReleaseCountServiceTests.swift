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

    func testHourKeyUsesUtcDateAndHour() {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 2
        components.day = 6
        components.hour = 14
        components.minute = 30

        let date = components.date!
        XCTAssertEqual(GlobalReleaseCountService.hourKey(for: date), "2026-02-06-14")
    }

    func testIncrementedAddsReleaseAndWordCountsOnSameDay() {
        let now = Date(timeIntervalSince1970: 1_737_000_000)
        let dayKey = GlobalReleaseCountService.dayKey(for: now)
        let counts = GlobalReleaseCounts(
            dayKey: dayKey,
            total: 10,
            today: 4,
            totalWords: 1_000,
            todayWords: 250,
            updatedAt: now
        )

        let updated = counts.incremented(wordCount: 75, now: now)

        XCTAssertEqual(updated.dayKey, dayKey)
        XCTAssertEqual(updated.total, 11)
        XCTAssertEqual(updated.today, 5)
        XCTAssertEqual(updated.totalWords, 1_075)
        XCTAssertEqual(updated.todayWords, 325)
    }

    func testIncrementedRollsDailyCountsWhenLocalDayChanges() {
        // Use a fixed calendar so the test is deterministic
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: -6 * 3600)! // UTC-6

        // Jan 1 11:59 PM local (= Jan 2 05:59 UTC)
        let beforeMidnight = Date(timeIntervalSince1970: 1_735_797_540)
        // Jan 2 12:01 AM local (= Jan 2 06:01 UTC)
        let afterMidnight = Date(timeIntervalSince1970: 1_735_797_660)

        // Sanity check: these should be different local days
        XCTAssertFalse(calendar.isDate(beforeMidnight, inSameDayAs: afterMidnight))

        let counts = GlobalReleaseCounts(
            dayKey: GlobalReleaseCountService.dayKey(for: beforeMidnight),
            total: 10,
            today: 4,
            totalWords: 1_000,
            todayWords: 250,
            updatedAt: beforeMidnight
        )

        let updated = counts.incremented(wordCount: 80, now: afterMidnight, calendar: calendar)

        XCTAssertEqual(updated.total, 11)
        XCTAssertEqual(updated.today, 1)
        XCTAssertEqual(updated.totalWords, 1_080)
        XCTAssertEqual(updated.todayWords, 80)
    }

    func testIncrementedDoesNotRollWhenSameLocalDayDifferentUtcDay() {
        // UTC-6 user: two times on Jan 1 local that cross UTC midnight
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: -6 * 3600)!

        // Jan 1 5 PM local (= Jan 1 23:00 UTC)
        let first = Date(timeIntervalSince1970: 1_735_772_400)
        // Jan 1 7 PM local (= Jan 2 01:00 UTC)
        let second = Date(timeIntervalSince1970: 1_735_779_600)

        // Sanity check: same local day, different UTC day
        XCTAssertTrue(calendar.isDate(first, inSameDayAs: second))

        let counts = GlobalReleaseCounts(
            dayKey: GlobalReleaseCountService.dayKey(for: first),
            total: 10,
            today: 4,
            totalWords: 1_000,
            todayWords: 250,
            updatedAt: first
        )

        let updated = counts.incremented(wordCount: 50, now: second, calendar: calendar)

        XCTAssertEqual(updated.total, 11)
        XCTAssertEqual(updated.today, 5)
        XCTAssertEqual(updated.totalWords, 1_050)
        XCTAssertEqual(updated.todayWords, 300)
    }

    func testHourKeysForLocalTodayGeneratesCorrectKeys() {
        // Simulate 3 PM UTC on Feb 6, with a UTC calendar (so local midnight = 00:00 UTC)
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

        var components = DateComponents()
        components.calendar = utcCalendar
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 2
        components.day = 6
        components.hour = 15
        components.minute = 30

        let now = components.date!
        let keys = GlobalReleaseCountService.hourKeysForLocalToday(now: now, calendar: utcCalendar)

        XCTAssertEqual(keys.count, 16) // hours 0 through 15
        XCTAssertEqual(keys.first, "2026-02-06-00")
        XCTAssertEqual(keys.last, "2026-02-06-15")
    }

    func testHourKeysForLocalTodayRespectsNegativeUtcOffset() {
        // Simulate a user in UTC-6 at 3 PM local (= 21:00 UTC) on Feb 6
        // Their local midnight was 06:00 UTC
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = TimeZone(secondsFromGMT: -6 * 3600)!

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 2
        components.day = 6
        components.hour = 21
        components.minute = 0

        let now = components.date!
        let keys = GlobalReleaseCountService.hourKeysForLocalToday(now: now, calendar: localCalendar)

        XCTAssertEqual(keys.count, 16) // hours 06 through 21
        XCTAssertEqual(keys.first, "2026-02-06-06")
        XCTAssertEqual(keys.last, "2026-02-06-21")
    }

    func testDecodingLegacyCachedCountsDefaultsWordTotalsToZero() async throws {
        let json = """
        {
          "dayKey": "2026-02-06",
          "total": 100,
          "today": 10,
          "updatedAt": "2026-02-06T10:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try await MainActor.run {
            let counts = try decoder.decode(GlobalReleaseCounts.self, from: Data(json.utf8))
            XCTAssertEqual(counts.dayKey, "2026-02-06")
            XCTAssertEqual(counts.total, 100)
            XCTAssertEqual(counts.today, 10)
            XCTAssertEqual(counts.totalWords, 0)
            XCTAssertEqual(counts.todayWords, 0)
        }
    }
}
