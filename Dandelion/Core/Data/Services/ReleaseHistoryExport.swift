//
//  ReleaseHistoryExport.swift
//  Dandelion
//
//  On-device export helpers for release history
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI

struct ReleaseHistoryExport {
    static func csvString(for releases: [Release], insights: ReleaseInsights) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let journeyDateFormatter = DateFormatter()
        journeyDateFormatter.timeZone = .current
        journeyDateFormatter.dateStyle = .long

        let timeFormatter = DateFormatter()
        timeFormatter.timeZone = .current
        timeFormatter.dateFormat = "HH:mm"

        let monthFormatter = DateFormatter()
        monthFormatter.timeZone = .current
        monthFormatter.dateFormat = "yyyy-MM"

        let journeyStart = insights.journeyStart.map { journeyDateFormatter.string(from: $0) } ?? "—"

        var lines: [String] = ["section,metric,value"]
        lines.append("journey,Started,\(csvEscape(journeyStart))")
        lines.append("journey,Total releases,\(insights.totalReleases)")
        lines.append("journey,Words released,\(insights.totalWords)")
        lines.append("journey,Days on journey,\(insights.daysOnJourney)")
        lines.append("journey,Active days,\(insights.activeDays)")
        lines.append("streaks,Current streak (days),\(insights.currentStreak)")
        lines.append("streaks,Longest streak (days),\(insights.longestStreak)")
        lines.append("recent activity,Releases last 30 days,\(insights.last30DaysReleases)")
        lines.append("recent activity,Releases previous 30 days,\(insights.prev30DaysReleases)")
        lines.append("recent activity,Words last 30 days,\(insights.last30DaysWords)")
        lines.append("recent activity,Words previous 30 days,\(insights.prev30DaysWords)")
        lines.append("activity,Releases last 7 days,\(insights.releasesLast7Days)")
        lines.append("activity,Weekly average releases,\(Int(round(insights.releasesPerWeekAverage)))")
        lines.append("activity,Words per active day,\(Int(round(insights.wordsPerActiveDay)))")
        lines.append("patterns,Most active day,\(csvEscape(insights.mostActiveWeekday ?? "—"))")
        lines.append("patterns,Most active time,\(csvEscape(insights.mostActiveTimeBucket ?? "—"))")
        lines.append("patterns,Average words per release,\(Int(round(insights.averageWordsPerRelease)))")
        lines.append("patterns,Median words per release,\(insights.medianWordsPerRelease)")
        lines.append("patterns,Longest release (words),\(insights.longestRelease)")
        lines.append("patterns,Shortest release (words),\(insights.shortestRelease)")
        lines.append("")
        lines.append("month_start,release_count,word_count")
        for summary in insights.monthlySummaries {
            let month = monthFormatter.string(from: summary.monthStart)
            lines.append("\(month),\(summary.releaseCount),\(summary.wordCount)")
        }
        lines.append("")
        lines.append("timestamp_iso8601,local_date,local_time,word_count")
        for release in releases.sorted(by: { $0.timestamp < $1.timestamp }) {
            let iso = formatter.string(from: release.timestamp)
            let date = dateFormatter.string(from: release.timestamp)
            let time = timeFormatter.string(from: release.timestamp)
            lines.append("\(iso),\(date),\(time),\(release.wordCount)")
        }

        return lines.joined(separator: "\n")
    }

    static func summaryText(for releases: [Release], insights: ReleaseInsights) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeZone = .current

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "LLLL yyyy"
        monthFormatter.timeZone = .current

        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal

        let startDate = insights.journeyStart.map { formatter.string(from: $0) } ?? "—"
        let weeklyAverage = Int(round(insights.releasesPerWeekAverage))
        let averageWords = Int(round(insights.averageWordsPerRelease))
        let wordsPerActiveDay = Int(round(insights.wordsPerActiveDay))
        let activeDayLabel = insights.currentStreak == 1 ? "day" : "days"
        let longestDayLabel = insights.longestStreak == 1 ? "day" : "days"
        let monthlyLines = insights.monthlySummaries.map { summary in
            let month = monthFormatter.string(from: summary.monthStart)
            return "\(month): \(formatNumber(summary.releaseCount, formatter: numberFormatter)) releases, \(formatNumber(summary.wordCount, formatter: numberFormatter)) words"
        }
        .joined(separator: "\n")

        return """
        My Dandelion Journey

        Journey
        Started: \(startDate)
        Total Releases: \(formatNumber(insights.totalReleases, formatter: numberFormatter))
        Words Released: \(formatNumber(insights.totalWords, formatter: numberFormatter))
        Days on Journey: \(formatNumber(insights.daysOnJourney, formatter: numberFormatter))
        Active Days: \(formatNumber(insights.activeDays, formatter: numberFormatter))

        Streaks
        Current Streak: \(formatNumber(insights.currentStreak, formatter: numberFormatter)) \(activeDayLabel)
        Longest Streak: \(formatNumber(insights.longestStreak, formatter: numberFormatter)) \(longestDayLabel)

        Recent Activity (Last 30 Days)
        Releases: \(formatNumber(insights.last30DaysReleases, formatter: numberFormatter))
        Words: \(formatNumber(insights.last30DaysWords, formatter: numberFormatter))
        Previous 30 Days Releases: \(formatNumber(insights.prev30DaysReleases, formatter: numberFormatter))
        Previous 30 Days Words: \(formatNumber(insights.prev30DaysWords, formatter: numberFormatter))

        Activity
        Releases (7 days): \(formatNumber(insights.releasesLast7Days, formatter: numberFormatter))
        Weekly average: \(formatNumber(weeklyAverage, formatter: numberFormatter))
        Words per active day: \(formatNumber(wordsPerActiveDay, formatter: numberFormatter))

        Patterns
        Most active day: \(insights.mostActiveWeekday ?? "—")
        Most active time: \(insights.mostActiveTimeBucket ?? "—")
        Average words/release: \(formatNumber(averageWords, formatter: numberFormatter))
        Median words/release: \(formatNumber(insights.medianWordsPerRelease, formatter: numberFormatter))
        Longest release: \(formatNumber(insights.longestRelease, formatter: numberFormatter)) words
        Shortest release: \(formatNumber(insights.shortestRelease, formatter: numberFormatter)) words

        Monthly Trends (Last 12 Months)
        \(monthlyLines)

        \"\(formatNumber(insights.totalReleases, formatter: numberFormatter)) moments of letting go.\"
        """
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains("\"") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        if value.contains(",") || value.contains("\n") {
            return "\"\(value)\""
        }
        return value
    }

    private static func formatNumber(_ number: Int, formatter: NumberFormatter) -> String {
        formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

struct ReleaseHistoryCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var csv: String

    init(csv: String) {
        self.csv = csv
    }

    init(configuration: ReadConfiguration) throws {
        csv = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = csv.data(using: .utf8) ?? Data()
        return .init(regularFileWithContents: data)
    }
}
