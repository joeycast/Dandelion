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
    private let calendar = Calendar.current

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
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
        let releasesInYear = releases.filter { isDate($0.timestamp, in: year) }
        return Set(releasesInYear.map { calendar.startOfDay(for: $0.timestamp) })
    }

    /// Total number of releases for a year
    func totalReleases(for year: Int, from releases: [Release]) -> Int {
        releases.filter { isDate($0.timestamp, in: year) }.count
    }

    /// Total words released in a year
    func totalWords(for year: Int, from releases: [Release]) -> Int {
        releases
            .filter { isDate($0.timestamp, in: year) }
            .reduce(0) { $0 + $1.wordCount }
    }

    /// Calculate current streak (consecutive days ending today or yesterday)
    func currentStreak(from releases: [Release]) -> Int {
        guard !releases.isEmpty else { return 0 }

        let uniqueDays = Set(releases.map { calendar.startOfDay(for: $0.timestamp) })
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Start from today or yesterday
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

    /// Longest streak ever achieved
    func longestStreak(from releases: [Release]) -> Int {
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

    // MARK: - Private Helpers

    private func isDate(_ date: Date, in year: Int) -> Bool {
        calendar.component(.year, from: date) == year
    }
}
