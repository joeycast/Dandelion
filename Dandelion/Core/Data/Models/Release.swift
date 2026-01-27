//
//  Release.swift
//  Dandelion
//
//  SwiftData model for tracking release activity
//

import Foundation
import SwiftData

/// Represents a single release event (when user lets go of their writing)
/// Note: We store only metadata (timestamp, word count), never the actual content
@Model
final class Release {
    /// When the release occurred
    var timestamp: Date = Date()

    /// Number of words in the released writing
    var wordCount: Int = 0

    init(timestamp: Date = Date(), wordCount: Int = 0) {
        self.timestamp = timestamp
        self.wordCount = wordCount
    }

    /// The calendar day of this release (normalized to start of day)
    var calendarDay: Date {
        Calendar.current.startOfDay(for: timestamp)
    }
}
