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
    static func csvString(for releases: [Release]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.timeZone = .current
        timeFormatter.dateFormat = "HH:mm"

        var lines: [String] = ["timestamp_iso8601,local_date,local_time,word_count"]
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

        let startDate = insights.journeyStart.map { formatter.string(from: $0) } ?? "—"

        return """
        My Dandelion Journey

        Started: \(startDate)
        Total Releases: \(insights.totalReleases)
        Words Released: \(insights.totalWords)
        Longest Streak: \(insights.longestStreak) days

        \"\(insights.totalReleases) moments of letting go.\"
        """
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
