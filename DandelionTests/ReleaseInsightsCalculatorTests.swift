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

    func testEmptyReleasesReturnZeroedInsights() {
        let insights = ReleaseInsightsCalculator.calculate(releases: [])

        XCTAssertEqual(insights.totalReleases, 0)
        XCTAssertEqual(insights.totalWords, 0)
        XCTAssertEqual(insights.currentStreak, 0)
        XCTAssertEqual(insights.longestStreak, 0)
        XCTAssertNil(insights.journeyStart)
        XCTAssertEqual(insights.daysOnJourney, 0)
        XCTAssertEqual(insights.activeDays, 0)
        XCTAssertEqual(insights.releasesLast7Days, 0)
        XCTAssertEqual(insights.releasesPerWeekAverage, 0, accuracy: 0.001)
        XCTAssertEqual(insights.last30DaysReleases, 0)
        XCTAssertEqual(insights.prev30DaysReleases, 0)
        XCTAssertEqual(insights.last30DaysWords, 0)
        XCTAssertEqual(insights.prev30DaysWords, 0)
        XCTAssertEqual(insights.averageWordsPerRelease, 0, accuracy: 0.001)
        XCTAssertEqual(insights.medianWordsPerRelease, 0)
        XCTAssertEqual(insights.longestRelease, 0)
        XCTAssertEqual(insights.shortestRelease, 0)
        XCTAssertEqual(insights.wordsPerActiveDay, 0, accuracy: 0.001)
        XCTAssertNil(insights.mostActiveWeekday)
        XCTAssertNil(insights.mostActiveTimeBucket)
    }

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

    func testMedianWordCountEvenCounts() {
        let releases = [
            Release(timestamp: Date(), wordCount: 2),
            Release(timestamp: Date(), wordCount: 4),
            Release(timestamp: Date(), wordCount: 6),
            Release(timestamp: Date(), wordCount: 8)
        ]

        let insights = ReleaseInsightsCalculator.calculate(releases: releases)
        XCTAssertEqual(insights.medianWordsPerRelease, 5)
    }

    func testJourneyStartActiveDaysAndWordsPerActiveDay() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 12))!
        ReleaseInsightsCalculator.nowProvider = { now }
        defer { ReleaseInsightsCalculator.nowProvider = Date.init }

        let releases = [
            Release(timestamp: date(daysAgo: 4, from: now), wordCount: 100),
            Release(timestamp: date(daysAgo: 2, from: now), wordCount: 50),
            Release(timestamp: date(daysAgo: 2, from: now), wordCount: 25),
            Release(timestamp: date(daysAgo: 0, from: now), wordCount: 75)
        ]

        let insights = ReleaseInsightsCalculator.calculate(releases: releases)

        XCTAssertEqual(insights.journeyStart, date(daysAgo: 4, from: now))
        XCTAssertEqual(insights.daysOnJourney, 5)
        XCTAssertEqual(insights.activeDays, 3)
        XCTAssertEqual(insights.wordsPerActiveDay, Double(250) / Double(3), accuracy: 0.001)
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

    func testAverageWeeklyReleasesOverLast4Weeks() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 12))!
        ReleaseInsightsCalculator.nowProvider = { now }
        defer { ReleaseInsightsCalculator.nowProvider = Date.init }

        let releases = [
            Release(timestamp: date(daysAgo: 1, from: now), wordCount: 1),
            Release(timestamp: date(daysAgo: 3, from: now), wordCount: 1),
            Release(timestamp: date(daysAgo: 8, from: now), wordCount: 1),
            Release(timestamp: date(daysAgo: 10, from: now), wordCount: 1),
            Release(timestamp: date(daysAgo: 15, from: now), wordCount: 1),
            Release(timestamp: date(daysAgo: 17, from: now), wordCount: 1),
            Release(timestamp: date(daysAgo: 22, from: now), wordCount: 1),
            Release(timestamp: date(daysAgo: 27, from: now), wordCount: 1)
        ]

        let insights = ReleaseInsightsCalculator.calculate(releases: releases)
        XCTAssertEqual(insights.releasesPerWeekAverage, 2, accuracy: 0.001)
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

    func testMostActiveWeekdayAndTimeBucket() {
        let morning = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 9))!
        let morningTwo = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 10))!
        let afternoon = calendar.date(from: DateComponents(year: 2026, month: 2, day: 2, hour: 14))!

        let releases = [
            Release(timestamp: morning, wordCount: 10),
            Release(timestamp: morningTwo, wordCount: 10),
            Release(timestamp: afternoon, wordCount: 10)
        ]

        let insights = ReleaseInsightsCalculator.calculate(releases: releases)

        let weekdayIndex = calendar.component(.weekday, from: morning)
        let expectedWeekday = calendar.weekdaySymbols[weekdayIndex - 1]
        XCTAssertEqual(insights.mostActiveWeekday, expectedWeekday)
        XCTAssertEqual(insights.mostActiveTimeBucket, "Morning")
    }

    func testMonthlySummariesIncludeCountsForLast12Months() {
        let now = Date()
        let startOfThisMonth = startOfMonth(for: now)
        guard let priorMonthStart = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth) else {
            XCTFail("Failed to generate prior month")
            return
        }

        let releases = [
            Release(timestamp: startOfThisMonth, wordCount: 40),
            Release(timestamp: priorMonthStart, wordCount: 10),
            Release(timestamp: priorMonthStart, wordCount: 20)
        ]

        let insights = ReleaseInsightsCalculator.calculate(releases: releases)
        XCTAssertEqual(insights.monthlySummaries.count, 12)

        let currentMonthSummary = insights.monthlySummaries.first { $0.monthStart == startOfThisMonth }
        XCTAssertEqual(currentMonthSummary?.releaseCount, 1)
        XCTAssertEqual(currentMonthSummary?.wordCount, 40)

        let priorMonthSummary = insights.monthlySummaries.first { $0.monthStart == priorMonthStart }
        XCTAssertEqual(priorMonthSummary?.releaseCount, 2)
        XCTAssertEqual(priorMonthSummary?.wordCount, 30)
    }

    private func date(daysAgo: Int, from reference: Date) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: reference))!
    }

    private func startOfMonth(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}
