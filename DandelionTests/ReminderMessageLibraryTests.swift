//
//  ReminderMessageLibraryTests.swift
//  DandelionTests
//
//  Tests for daily reminder notification copy
//

import XCTest
@testable import Dandelion

@MainActor
final class ReminderMessageLibraryTests: XCTestCase {
    private let calendar = Calendar.current

    func testMessagePoolsAreNotEmpty() {
        XCTAssertFalse(ReminderMessageLibrary.encouragingMessages.isEmpty)
        XCTAssertFalse(ReminderMessageLibrary.curatedPromptMessages.isEmpty)
        XCTAssertEqual(ReminderMessageLibrary.curatedPromptMessages, WritingPrompt.defaults.map(\.text))
    }

    func testBodyIsStableForTheSameDay() throws {
        let morning = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 7)))
        let evening = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 22)))

        XCTAssertEqual(
            ReminderMessageLibrary.body(for: morning, calendar: calendar),
            ReminderMessageLibrary.body(for: evening, calendar: calendar),
            "The same calendar day should always produce the same reminder"
        )
    }

    func testConsecutiveDaysAlternateBetweenPromptsAndNudges() throws {
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 9)))
        let prompts = Set(ReminderMessageLibrary.curatedPromptMessages)
        let nudges = Set(ReminderMessageLibrary.encouragingMessages)

        var previousWasPrompt: Bool?
        for offset in 0..<30 {
            let day = try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: start))
            let body = ReminderMessageLibrary.body(for: day, calendar: calendar)
            let isPrompt = prompts.contains(body)

            XCTAssertTrue(isPrompt || nudges.contains(body), "Unexpected reminder body: \(body)")
            if let previousWasPrompt {
                XCTAssertNotEqual(isPrompt, previousWasPrompt, "Day \(offset) should switch message category")
            }
            previousWasPrompt = isPrompt
        }
    }

    func testBodyVariesAcrossAWeek() throws {
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9)))
        let bodies = try (0..<14).map { offset in
            ReminderMessageLibrary.body(
                for: try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: start)),
                calendar: calendar
            )
        }

        XCTAssertGreaterThan(Set(bodies).count, 4, "Two weeks of reminders should not repeat a handful of messages")
    }

    func testBodyHandlesDatesBeforeReferenceDate() throws {
        let past = try XCTUnwrap(calendar.date(from: DateComponents(year: 1995, month: 3, day: 14, hour: 12)))
        let body = ReminderMessageLibrary.body(for: past, calendar: calendar)
        XCTAssertFalse(body.isEmpty)
    }
}
