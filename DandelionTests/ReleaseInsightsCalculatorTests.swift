//
//  ReleaseInsightsCalculatorTests.swift
//  DandelionTests
//
//  Unit tests for premium insights calculations
//

import XCTest
@testable import Dandelion

final class ReleaseInsightsCalculatorTests: XCTestCase {
    private let calendar = Calendar.current

    func testCalculatesTotals() {
        let releases = [
            Release(timestamp: Date(), wordCount: 10),
            Release(timestamp: Date(), wordCount: 20)
        ]

        let insights = ReleaseInsightsCalculator.calculate(releases: releases)

        XCTAssertEqual(insights.totalReleases, 2)
        XCTAssertEqual(insights.totalWords, 30)
        XCTAssertEqual(insights.longestRelease, 20)
        XCTAssertEqual(insights.shortestRelease, 10)
        XCTAssertEqual(insights.averageWordsPerRelease, 15, accuracy: 0.001)
    }

    func testMedianWordCount() {
        let releases = [
            Release(timestamp: Date(), wordCount: 5),
            Release(timestamp: Date(), wordCount: 15),
            Release(timestamp: Date(), wordCount: 25)
        ]

        let insights = ReleaseInsightsCalculator.calculate(releases: releases)
        XCTAssertEqual(insights.medianWordsPerRelease, 15)
    }

    func testLast7DaysCountsInclusiveWindow() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 12))!
        ReleaseInsightsCalculator.nowProvider = { now }
        defer { ReleaseInsightsCalculator.nowProvider = Date.init }

        let releases = [
            Release(timestamp: date(daysAgo: 0, from: now), wordCount: 1),
            Release(timestamp: date(daysAgo: 3, from: now), wordCount: 1),
            Release(timestamp: date(daysAgo: 6, from: now), wordCount: 1),
            Release(timestamp: date(daysAgo: 7, from: now), wordCount: 1) // outside last 7 days
        ]

        let insights = ReleaseInsightsCalculator.calculate(releases: releases)
        XCTAssertEqual(insights.releasesLast7Days, 3)
    }

    func testPrevious30DaysWindow() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 12))!
        ReleaseInsightsCalculator.nowProvider = { now }
        defer { ReleaseInsightsCalculator.nowProvider = Date.init }

        let releases = [
            Release(timestamp: date(daysAgo: 30, from: now), wordCount: 10),
            Release(timestamp: date(daysAgo: 59, from: now), wordCount: 20),
            Release(timestamp: date(daysAgo: 29, from: now), wordCount: 30), // in last 30 days, exclude
            Release(timestamp: date(daysAgo: 60, from: now), wordCount: 40)  // outside window
        ]

        let insights = ReleaseInsightsCalculator.calculate(releases: releases)
        XCTAssertEqual(insights.prev30DaysReleases, 2)
        XCTAssertEqual(insights.prev30DaysWords, 30)
    }

    private func date(daysAgo: Int, from reference: Date) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: reference))!
    }
}
