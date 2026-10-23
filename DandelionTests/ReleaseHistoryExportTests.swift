//
//  ReleaseHistoryExportTests.swift
//  DandelionTests
//
//  Tests for CSV and summary export of release history
//

import XCTest
import UniformTypeIdentifiers
@testable import Dandelion

@MainActor
final class ReleaseHistoryExportTests: XCTestCase {
    private let calendar = Calendar.current

    // MARK: - CSV

    func testCSVHasThreeSectionsWithHeaders() {
        let csv = ReleaseHistoryExport.csvString(for: [], insights: makeInsights())
        let sections = csv.components(separatedBy: "\n\n")

        XCTAssertEqual(sections.count, 3, "CSV should have metrics, monthly, and release sections")
        XCTAssertTrue(sections[0].hasPrefix("section,metric,value"))
        XCTAssertTrue(sections[1].hasPrefix("month_start,release_count,word_count"))
        XCTAssertTrue(sections[2].hasPrefix("timestamp_iso8601,local_date,local_time,word_count"))
    }

    func testCSVIncludesMetricValues() {
        let csv = ReleaseHistoryExport.csvString(
            for: [],
            insights: makeInsights(totalReleases: 7, totalWords: 420, currentStreak: 3, longestStreak: 9)
        )
        let lines = csv.components(separatedBy: "\n")

        XCTAssertTrue(lines.contains("journey,Total releases,7"))
        XCTAssertTrue(lines.contains("journey,Words released,420"))
        XCTAssertTrue(lines.contains("streaks,Current streak (days),3"))
        XCTAssertTrue(lines.contains("streaks,Longest streak (days),9"))
    }

    func testCSVRoundsAverages() {
        let csv = ReleaseHistoryExport.csvString(
            for: [],
            insights: makeInsights(releasesPerWeekAverage: 2.6, averageWordsPerRelease: 10.4, wordsPerActiveDay: 99.5)
        )
        let lines = csv.components(separatedBy: "\n")

        XCTAssertTrue(lines.contains("activity,Weekly average releases,3"))
        XCTAssertTrue(lines.contains("patterns,Average words per release,10"))
        XCTAssertTrue(lines.contains("activity,Words per active day,100"))
    }

    func testCSVUsesDashForMissingValues() {
        let csv = ReleaseHistoryExport.csvString(for: [], insights: makeInsights())
        let lines = csv.components(separatedBy: "\n")

        XCTAssertTrue(lines.contains("journey,Started,—"))
        XCTAssertTrue(lines.contains("patterns,Most active day,—"))
        XCTAssertTrue(lines.contains("patterns,Most active time,—"))
    }

    func testCSVEscapesCommasAndQuotes() {
        let csv = ReleaseHistoryExport.csvString(
            for: [],
            insights: makeInsights(mostActiveWeekday: "Mon, Tue", mostActiveTimeBucket: "Late \"night\"")
        )
        let lines = csv.components(separatedBy: "\n")

        XCTAssertTrue(lines.contains("patterns,Most active day,\"Mon, Tue\""))
        XCTAssertTrue(lines.contains("patterns,Most active time,\"Late \"\"night\"\"\""))
    }

    func testCSVListsReleasesOldestFirst() throws {
        let newer = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 21, minute: 7)))
        let older = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 8, minute: 30)))
        let releases = [
            Release(timestamp: newer, wordCount: 50),
            Release(timestamp: older, wordCount: 12)
        ]

        let csv = ReleaseHistoryExport.csvString(for: releases, insights: makeInsights())
        let releaseRows = csv.components(separatedBy: "\n\n")[2]
            .components(separatedBy: "\n")
            .dropFirst()
            .map { $0.components(separatedBy: ",") }

        XCTAssertEqual(releaseRows.count, 2)
        XCTAssertEqual(releaseRows[0][1], "2026-01-02")
        XCTAssertEqual(releaseRows[0][2], "08:30")
        XCTAssertEqual(releaseRows[0][3], "12")
        XCTAssertEqual(releaseRows[1][1], "2026-03-05")
        XCTAssertEqual(releaseRows[1][2], "21:07")
        XCTAssertEqual(releaseRows[1][3], "50")
    }

    func testCSVNeverContainsWrittenContent() {
        // Releases only carry metadata, so each release row is exactly four numeric/date columns.
        let releases = (0..<5).map { Release(timestamp: Date().addingTimeInterval(Double(-$0) * 3600), wordCount: $0 * 10) }
        let csv = ReleaseHistoryExport.csvString(for: releases, insights: makeInsights())
        let releaseRows = csv.components(separatedBy: "\n\n")[2].components(separatedBy: "\n").dropFirst()

        XCTAssertEqual(releaseRows.count, 5)
        for row in releaseRows {
            XCTAssertEqual(row.components(separatedBy: ",").count, 4, "Unexpected release row: \(row)")
        }
    }

    func testCSVListsMonthlySummaries() throws {
        let january = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let february = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 2, day: 1)))
        let insights = makeInsights(monthlySummaries: [
            MonthlySummary(monthStart: january, releaseCount: 4, wordCount: 400),
            MonthlySummary(monthStart: february, releaseCount: 0, wordCount: 0)
        ])

        let csv = ReleaseHistoryExport.csvString(for: [], insights: insights)
        let monthlyLines = csv.components(separatedBy: "\n\n")[1].components(separatedBy: "\n")

        XCTAssertEqual(Array(monthlyLines.dropFirst()), ["2026-01,4,400", "2026-02,0,0"])
    }

    // MARK: - Summary Text

    func testSummaryUsesSingularDayForStreakOfOne() {
        let summary = ReleaseHistoryExport.summaryText(
            for: [],
            insights: makeInsights(currentStreak: 1, longestStreak: 1)
        )

        XCTAssertTrue(summary.contains("Current Streak: 1 day\n"))
        XCTAssertTrue(summary.contains("Longest Streak: 1 day\n"))
    }

    func testSummaryUsesPluralDaysOtherwise() {
        let summary = ReleaseHistoryExport.summaryText(
            for: [],
            insights: makeInsights(currentStreak: 0, longestStreak: 5)
        )

        XCTAssertTrue(summary.contains("Current Streak: 0 days"))
        XCTAssertTrue(summary.contains("Longest Streak: 5 days"))
    }

    func testSummaryIncludesHeaderAndClosingLine() {
        let summary = ReleaseHistoryExport.summaryText(for: [], insights: makeInsights(totalReleases: 12))

        XCTAssertTrue(summary.hasPrefix("My Dandelion Journey"))
        XCTAssertTrue(summary.contains("Started: —"))
        XCTAssertTrue(summary.hasSuffix("\"12 moments of letting go.\""))
    }

    // MARK: - CSV Document

    func testCSVDocumentKeepsContent() {
        let document = ReleaseHistoryCSVDocument(csv: "a,b\n1,2")
        XCTAssertEqual(document.csv, "a,b\n1,2")
        XCTAssertEqual(ReleaseHistoryCSVDocument.readableContentTypes, [.commaSeparatedText])
    }

    // MARK: - Helpers

    private func makeInsights(
        totalReleases: Int = 0,
        totalWords: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        journeyStart: Date? = nil,
        releasesPerWeekAverage: Double = 0,
        averageWordsPerRelease: Double = 0,
        wordsPerActiveDay: Double = 0,
        mostActiveWeekday: String? = nil,
        mostActiveTimeBucket: String? = nil,
        monthlySummaries: [MonthlySummary] = []
    ) -> ReleaseInsights {
        ReleaseInsights(
            totalReleases: totalReleases,
            totalWords: totalWords,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            journeyStart: journeyStart,
            daysOnJourney: 0,
            activeDays: 0,
            releasesLast7Days: 0,
            releasesPerWeekAverage: releasesPerWeekAverage,
            last30DaysReleases: 0,
            prev30DaysReleases: 0,
            last30DaysWords: 0,
            prev30DaysWords: 0,
            averageWordsPerRelease: averageWordsPerRelease,
            medianWordsPerRelease: 0,
            longestRelease: 0,
            shortestRelease: 0,
            wordsPerActiveDay: wordsPerActiveDay,
            mostActiveWeekday: mostActiveWeekday,
            mostActiveTimeBucket: mostActiveTimeBucket,
            monthlySummaries: monthlySummaries
        )
    }
}
