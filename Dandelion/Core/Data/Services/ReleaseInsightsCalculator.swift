//
//  ReleaseInsightsCalculator.swift
//  Dandelion
//
//  Calculates premium insights from release history
//

import Foundation

struct ReleaseInsights {
    let totalReleases: Int
    let totalWords: Int
    let currentStreak: Int
    let longestStreak: Int
    let journeyStart: Date?
    let daysOnJourney: Int
    let activeDays: Int
    let releasesLast7Days: Int
    let releasesPerWeekAverage: Double
    let last30DaysReleases: Int
    let prev30DaysReleases: Int
    let last30DaysWords: Int
    let prev30DaysWords: Int
    let averageWordsPerRelease: Double
    let medianWordsPerRelease: Int
    let longestRelease: Int
    let shortestRelease: Int
    let wordsPerActiveDay: Double
    let mostActiveWeekday: String?
    let mostActiveTimeBucket: String?
    let monthlySummaries: [MonthlySummary]
}

struct MonthlySummary: Identifiable {
    let id = UUID()
    let monthStart: Date
    let releaseCount: Int
    let wordCount: Int
}

enum ReleaseInsightsCalculator {
    private static let calendar = Calendar.current
    // Injectable clock for deterministic tests.
    static var nowProvider: () -> Date = Date.init

    static func calculate(releases: [Release]) -> ReleaseInsights {
        let now = nowProvider()
        let sorted = releases.sorted { $0.timestamp < $1.timestamp }
        let totalReleases = releases.count
        let totalWords = releases.reduce(0) { $0 + $1.wordCount }

        let journeyStart = sorted.first?.timestamp
        let daysOnJourney = journeyStart.map { daysBetween(start: $0, end: now) } ?? 0
        let activeDays = Set(releases.map { calendar.startOfDay(for: $0.timestamp) }).count

        let currentStreak = currentStreak(from: releases)
        let longestStreak = longestStreak(from: releases)

        let releasesLast7Days = releasesCount(inLastDays: 7, releases: releases, now: now)
        let releasesPerWeekAverage = averageWeeklyReleases(releases: releases, now: now)

        let last30DaysReleases = releasesCount(inLastDays: 30, releases: releases, now: now)
        let prev30DaysReleases = releasesCount(inDaysRange: 30...59, releases: releases, now: now)

        let last30DaysWords = wordsCount(inLastDays: 30, releases: releases, now: now)
        let prev30DaysWords = wordsCount(inDaysRange: 30...59, releases: releases, now: now)

        let averageWordsPerRelease = totalReleases > 0 ? Double(totalWords) / Double(totalReleases) : 0
        let medianWordsPerRelease = medianWordCount(releases: releases)
        let longestRelease = releases.map { $0.wordCount }.max() ?? 0
        let shortestRelease = releases.map { $0.wordCount }.min() ?? 0
        let wordsPerActiveDay = activeDays > 0 ? Double(totalWords) / Double(activeDays) : 0

        let mostActiveWeekday = mostActiveDay(releases: releases)
        let mostActiveTimeBucket = mostActiveTimeBucket(releases: releases)

        let monthlySummaries = last12MonthsSummaries(releases: releases)

        return ReleaseInsights(
            totalReleases: totalReleases,
            totalWords: totalWords,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            journeyStart: journeyStart,
            daysOnJourney: daysOnJourney,
            activeDays: activeDays,
            releasesLast7Days: releasesLast7Days,
            releasesPerWeekAverage: releasesPerWeekAverage,
            last30DaysReleases: last30DaysReleases,
            prev30DaysReleases: prev30DaysReleases,
            last30DaysWords: last30DaysWords,
            prev30DaysWords: prev30DaysWords,
            averageWordsPerRelease: averageWordsPerRelease,
            medianWordsPerRelease: medianWordsPerRelease,
            longestRelease: longestRelease,
            shortestRelease: shortestRelease,
            wordsPerActiveDay: wordsPerActiveDay,
            mostActiveWeekday: mostActiveWeekday,
            mostActiveTimeBucket: mostActiveTimeBucket,
            monthlySummaries: monthlySummaries
        )
    }

    private static func daysBetween(start: Date, end: Date) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let days = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        return max(0, days + 1)
    }

    private static func releasesCount(inLastDays days: Int, releases: [Release], now: Date) -> Int {
        guard let startDate = calendar.date(byAdding: .day, value: -days + 1, to: calendar.startOfDay(for: now)) else {
            return 0
        }
        return releases.filter { $0.timestamp >= startDate }.count
    }

    private static func releasesCount(inDaysRange range: ClosedRange<Int>, releases: [Release], now: Date) -> Int {
        let todayStart = calendar.startOfDay(for: now)
        // Inclusive window: N days ago through M days ago.
        guard let startDate = calendar.date(byAdding: .day, value: -range.upperBound, to: todayStart),
              let endDate = calendar.date(byAdding: .day, value: -range.lowerBound + 1, to: todayStart) else {
            return 0
        }
        return releases.filter { $0.timestamp >= startDate && $0.timestamp < endDate }.count
    }

    private static func wordsCount(inLastDays days: Int, releases: [Release], now: Date) -> Int {
        guard let startDate = calendar.date(byAdding: .day, value: -days + 1, to: calendar.startOfDay(for: now)) else {
            return 0
        }
        return releases.filter { $0.timestamp >= startDate }.reduce(0) { $0 + $1.wordCount }
    }

    private static func wordsCount(inDaysRange range: ClosedRange<Int>, releases: [Release], now: Date) -> Int {
        let todayStart = calendar.startOfDay(for: now)
        // Inclusive window: N days ago through M days ago.
        guard let startDate = calendar.date(byAdding: .day, value: -range.upperBound, to: todayStart),
              let endDate = calendar.date(byAdding: .day, value: -range.lowerBound + 1, to: todayStart) else {
            return 0
        }
        return releases.filter { $0.timestamp >= startDate && $0.timestamp < endDate }.reduce(0) { $0 + $1.wordCount }
    }

    private static func averageWeeklyReleases(releases: [Release], now: Date) -> Double {
        guard !releases.isEmpty else { return 0 }
        let weeks = 4
        let total = releasesCount(inLastDays: weeks * 7, releases: releases, now: now)
        return Double(total) / Double(weeks)
    }

    private static func medianWordCount(releases: [Release]) -> Int {
        let counts = releases.map { $0.wordCount }.sorted()
        guard !counts.isEmpty else { return 0 }
        let mid = counts.count / 2
        if counts.count % 2 == 0 {
            return (counts[mid - 1] + counts[mid]) / 2
        }
        return counts[mid]
    }

    private static func currentStreak(from releases: [Release]) -> Int {
        guard !releases.isEmpty else { return 0 }

        let uniqueDays = Set(releases.map { calendar.startOfDay(for: $0.timestamp) })
        let today = calendar.startOfDay(for: Date())
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

    private static func longestStreak(from releases: [Release]) -> Int {
        let sortedDays = Set(releases.map { calendar.startOfDay(for: $0.timestamp) }).sorted()
        guard !sortedDays.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for i in 1..<sortedDays.count {
            let daysBetween = calendar.dateComponents([.day], from: sortedDays[i - 1], to: sortedDays[i]).day ?? 0
            if daysBetween == 1 {
                current += 1
                longest = max(longest, current)
            } else if daysBetween > 1 {
                current = 1
            }
        }

        return longest
    }

    private static func mostActiveDay(releases: [Release]) -> String? {
        guard !releases.isEmpty else { return nil }
        var counts: [Int: Int] = [:]

        for release in releases {
            let weekday = calendar.component(.weekday, from: release.timestamp)
            counts[weekday, default: 0] += 1
        }

        guard let best = counts.max(by: { $0.value < $1.value })?.key else { return nil }
        return calendar.weekdaySymbols[safe: best - 1]
    }

    private static func mostActiveTimeBucket(releases: [Release]) -> String? {
        guard !releases.isEmpty else { return nil }
        var counts: [String: Int] = [:]

        for release in releases {
            let hour = calendar.component(.hour, from: release.timestamp)
            let bucket = timeBucket(for: hour)
            counts[bucket, default: 0] += 1
        }

        return counts.max(by: { $0.value < $1.value })?.key
    }

    private static func timeBucket(for hour: Int) -> String {
        switch hour {
        case 5..<12:
            return "Morning"
        case 12..<17:
            return "Afternoon"
        case 17..<22:
            return "Evening"
        default:
            return "Night"
        }
    }

    private static func last12MonthsSummaries(releases: [Release]) -> [MonthlySummary] {
        let now = Date()
        guard let startMonth = calendar.date(byAdding: .month, value: -11, to: calendar.startOfMonth(for: now)) else {
            return []
        }

        var summaries: [MonthlySummary] = []
        for offset in 0..<12 {
            guard let monthStart = calendar.date(byAdding: .month, value: offset, to: startMonth),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { continue }

            let monthReleases = releases.filter { $0.timestamp >= monthStart && $0.timestamp < monthEnd }
            summaries.append(MonthlySummary(
                monthStart: monthStart,
                releaseCount: monthReleases.count,
                wordCount: monthReleases.reduce(0) { $0 + $1.wordCount }
            ))
        }
        return summaries
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
