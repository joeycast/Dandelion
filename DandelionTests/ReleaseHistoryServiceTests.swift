//
//  ReleaseHistoryServiceTests.swift
//  DandelionTests
//
//  Tests for release history service calculations
//

import XCTest
@testable import Dandelion

@MainActor
final class ReleaseHistoryServiceTests: XCTestCase {
    private let calendar = Calendar.current

    func testReleaseDatesAndTotalsForYear() throws {
        let releaseDates = [
            calendar.date(from: DateComponents(year: 2025, month: 12, day: 31, hour: 12))!,
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 9))!,
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 18))!,
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 8))!
        ]

        let releases = [
            Release(timestamp: releaseDates[0], wordCount: 10),
            Release(timestamp: releaseDates[1], wordCount: 20),
            Release(timestamp: releaseDates[2], wordCount: 30),
            Release(timestamp: releaseDates[3], wordCount: 40)
        ]

        let dates = ReleaseHistoryService.releaseDates(for: 2026, from: releases, calendar: calendar)
        XCTAssertEqual(dates.count, 2)
        XCTAssertTrue(dates.contains(calendar.startOfDay(for: releaseDates[1])))
        XCTAssertTrue(dates.contains(calendar.startOfDay(for: releaseDates[3])))

        XCTAssertEqual(ReleaseHistoryService.totalReleases(for: 2026, from: releases, calendar: calendar), 3)
        XCTAssertEqual(ReleaseHistoryService.totalWords(for: 2026, from: releases, calendar: calendar), 90)
    }

    func testCurrentStreakUsesTodayOrYesterday() throws {
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let releases = [
            Release(timestamp: today, wordCount: 10),
            Release(timestamp: yesterday, wordCount: 10),
            Release(timestamp: twoDaysAgo, wordCount: 10)
        ]

        XCTAssertEqual(ReleaseHistoryService.currentStreak(from: releases, calendar: calendar, now: today), 3)
    }

    func testCurrentStreakIsZeroWhenMissingTodayAndYesterday() throws {
        let today = calendar.startOfDay(for: Date())
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let releases = [Release(timestamp: twoDaysAgo, wordCount: 10)]

        XCTAssertEqual(ReleaseHistoryService.currentStreak(from: releases, calendar: calendar, now: today), 0)
    }

    func testLongestStreakFindsMaxConsecutiveDays() throws {
        let base = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 10))!
        let dates = [
            base,
            calendar.date(byAdding: .day, value: 1, to: base)!,
            calendar.date(byAdding: .day, value: 3, to: base)!,
            calendar.date(byAdding: .day, value: 4, to: base)!,
            calendar.date(byAdding: .day, value: 5, to: base)!
        ]

        let releases = dates.map { Release(timestamp: $0, wordCount: 5) }
        XCTAssertEqual(ReleaseHistoryService.longestStreak(from: releases, calendar: calendar), 3)
    }
}
