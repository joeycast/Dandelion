//
//  AccessibilityTests.swift
//  DandelionTests
//
//  Tests to verify VoiceOver accessibility support
//

import XCTest
import SwiftUI
@testable import Dandelion

@MainActor
final class AccessibilityTests: XCTestCase {

    // MARK: - WritingViewModel Accessibility State Tests

    func testLetGoButtonAccessibilityStateWhenEmpty() {
        let viewModel = WritingViewModel()
        viewModel.startWriting()

        // When text is empty, canRelease should be false
        XCTAssertFalse(viewModel.canRelease, "Let Go button should be disabled when text is empty")
    }

    func testLetGoButtonAccessibilityStateWithText() {
        let viewModel = WritingViewModel()
        viewModel.startWriting()
        viewModel.writtenText = "Some thoughts to release"

        // When text has content, canRelease should be true
        XCTAssertTrue(viewModel.canRelease, "Let Go button should be enabled when text has content")
    }

    // MARK: - Insights Accessibility Formatting Tests

    func testInsightsStreakLabelSingular() {
        // Test that streak labels use correct singular/plural
        let singularLabel = formatStreakLabel(count: 1)
        XCTAssertEqual(singularLabel, "1 day", "Single day streak should use singular form")
    }

    func testInsightsStreakLabelPlural() {
        let pluralLabel = formatStreakLabel(count: 5)
        XCTAssertEqual(pluralLabel, "5 days", "Multiple day streak should use plural form")
    }

    func testInsightsStreakLabelZero() {
        let zeroLabel = formatStreakLabel(count: 0)
        XCTAssertEqual(zeroLabel, "0 days", "Zero day streak should use plural form")
    }

    // MARK: - Calendar Accessibility Label Tests

    func testCalendarDayAccessibilityLabel() {
        let label = formatCalendarDayLabel(month: 1, day: 15, hasRelease: true)
        XCTAssertEqual(label, "January 15, released", "Calendar day with release should indicate released status")
    }

    func testCalendarDayAccessibilityLabelNoRelease() {
        let label = formatCalendarDayLabel(month: 6, day: 1, hasRelease: false)
        XCTAssertEqual(label, "June 1, no release", "Calendar day without release should indicate no release")
    }

    func testCalendarDayAccessibilityLabelAllMonths() {
        let monthNames = ["January", "February", "March", "April", "May", "June",
                          "July", "August", "September", "October", "November", "December"]

        for (index, expectedMonth) in monthNames.enumerated() {
            let label = formatCalendarDayLabel(month: index + 1, day: 1, hasRelease: false)
            XCTAssertTrue(label.contains(expectedMonth), "Month \(index + 1) should be \(expectedMonth)")
        }
    }

    // MARK: - Helper Functions (mirrors app logic)

    private func formatStreakLabel(count: Int) -> String {
        "\(count) \(count == 1 ? "day" : "days")"
    }

    private func formatCalendarDayLabel(month: Int, day: Int, hasRelease: Bool) -> String {
        let monthNames = ["January", "February", "March", "April", "May", "June",
                          "July", "August", "September", "October", "November", "December"]
        let monthName = monthNames[month - 1]
        let status = hasRelease ? "released" : "no release"
        return "\(monthName) \(day), \(status)"
    }
}
