//
//  ReminderMessageLibrary.swift
//  Dandelion
//
//  Curated notification copy for daily release reminders.
//

import Foundation

struct ReminderMessageLibrary {
    static let encouragingMessages: [String] = [
        "Take a moment to write and let go.",
        "A few minutes of release awaits.",
        "Your dandelion is waiting.",
        "Give your thoughts a place to land.",
        "A quiet moment, just for you.",
        "Ready to let something go?"
    ]

    static let curatedPromptMessages: [String] = WritingPrompt.defaults.map(\.text)

    static func body(forDayOffset dayOffset: Int) -> String {
        // Alternate message categories so notifications vary between prompts and nudges.
        if dayOffset.isMultiple(of: 2) {
            return pick(from: curatedPromptMessages, seed: dayOffset)
        }
        return pick(from: encouragingMessages, seed: dayOffset)
    }

    private static func pick(from values: [String], seed: Int) -> String {
        guard !values.isEmpty else { return "Take a moment to write and let go." }
        let index = abs(seed) % values.count
        return values[index]
    }
}
