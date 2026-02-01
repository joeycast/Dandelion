//
//  ReleaseHistoryService.swift
//  Dandelion
//
//  Service for recording and querying release history
//

import Foundation
import SwiftData

@MainActor
final class ReleaseHistoryService {
    private let modelContext: ModelContext
    private let calendar: Calendar

    init(modelContext: ModelContext, calendar: Calendar = .current) {
        self.modelContext = modelContext
        self.calendar = calendar
    }

    // MARK: - Recording

    /// Record a release with the given word count
    func recordRelease(wordCount: Int) {
        let release = Release(wordCount: wordCount)
        modelContext.insert(release)

        do {
            try modelContext.save()
        } catch {
            debugLog("Failed to record release: \(error)")
        }
    }

    // MARK: - Querying

    /// Get all unique dates with releases for a specific year
    func releaseDates(for year: Int, from releases: [Release]) -> Set<Date> {
        Self.releaseDates(for: year, from: releases, calendar: calendar)
    }

    /// Total number of releases for a year
    func totalReleases(for year: Int, from releases: [Release]) -> Int {
        Self.totalReleases(for: year, from: releases, calendar: calendar)
    }

    /// Total words released in a year
    func totalWords(for year: Int, from releases: [Release]) -> Int {
        Self.totalWords(for: year, from: releases, calendar: calendar)
    }

    /// Calculate current streak (consecutive days ending today or yesterday)
    func currentStreak(from releases: [Release]) -> Int {
        Self.currentStreak(from: releases, calendar: calendar, now: Date())
    }

    /// Longest streak ever achieved
    func longestStreak(from releases: [Release]) -> Int {
        Self.longestStreak(from: releases, calendar: calendar)
    }

    // MARK: - Private Helpers

    private static func isDate(_ date: Date, in year: Int, calendar: Calendar) -> Bool {
        calendar.component(.year, from: date) == year
    }

    // MARK: - Static Helpers (testable without SwiftData)

    static func releaseDates(for year: Int, from releases: [Release], calendar: Calendar = .current) -> Set<Date> {
        let releasesInYear = releases.filter { isDate($0.timestamp, in: year, calendar: calendar) }
        return Set(releasesInYear.map { calendar.startOfDay(for: $0.timestamp) })
    }

    static func totalReleases(for year: Int, from releases: [Release], calendar: Calendar = .current) -> Int {
        releases.filter { isDate($0.timestamp, in: year, calendar: calendar) }.count
    }

    static func totalWords(for year: Int, from releases: [Release], calendar: Calendar = .current) -> Int {
        releases
            .filter { isDate($0.timestamp, in: year, calendar: calendar) }
            .reduce(0) { $0 + $1.wordCount }
    }

    static func currentStreak(from releases: [Release], calendar: Calendar = .current, now: Date = Date()) -> Int {
        guard !releases.isEmpty else { return 0 }

        let uniqueDays = Set(releases.map { calendar.startOfDay(for: $0.timestamp) })
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        guard let startDate = uniqueDays.contains(today) ? today :
              (uniqueDays.contains(yesterday) ? yesterday : nil) else {
            return 0
        }

        var streak = 0
        var checkDate = startDate

        while uniqueDays.contains(checkDate) {
            streak += 1
            guard let prevDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prevDay
        }

        return streak
    }

    static func longestStreak(from releases: [Release], calendar: Calendar = .current) -> Int {
        let sortedDays = Set(releases.map { calendar.startOfDay(for: $0.timestamp) })
            .sorted()

        guard sortedDays.count > 0 else { return 0 }

        var longest = 1
        var current = 1

        for i in 1..<sortedDays.count {
            let daysBetween = calendar.dateComponents([.day], from: sortedDays[i-1], to: sortedDays[i]).day ?? 0

            if daysBetween == 1 {
                current += 1
                longest = max(longest, current)
            } else if daysBetween > 1 {
                current = 1
            }
        }

        return longest
    }
}
