//
//  YearGridView.swift
//  Dandelion
//
//  Year calendar grid showing 12 months × 31 days
//

import SwiftUI

struct YearGridView: View {
    let year: Int
    let releaseDates: Set<Date>

    @Environment(AppearanceManager.self) private var appearance
    private let calendar = Calendar.current
    private let monthLabels = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
    var body: some View {
        GeometryReader { proxy in
            let theme = appearance.theme
            let labelHeight = PlatformFont.dandelionCaption.lineHeight
            let rowSpacing: CGFloat = 0
            let availableHeight = max(0, proxy.size.height - labelHeight - DandelionSpacing.xs)
            let cellWidth = proxy.size.width / 12
            let cellHeight = max(0, (availableHeight - rowSpacing * 30) / 31)
            let iconSize = min(cellWidth, cellHeight)

            VStack(spacing: 0) {
                // Month labels at top
                HStack(spacing: 0) {
                    ForEach(0..<12, id: \.self) { month in
                        Text(monthLabels[month])
                            .font(.dandelionCaption)
                            .foregroundColor(theme.secondary)
                            .frame(width: cellWidth, height: labelHeight)
                    }
                }
                .padding(.bottom, DandelionSpacing.xs)

                // Days grid (rows = days 1-31, columns = months)
                ForEach(1...31, id: \.self) { day in
                    HStack(spacing: 0) {
                        ForEach(1...12, id: \.self) { month in
                            let date = dateFor(year: year, month: month, day: day)
                            DayCell(
                                date: date,
                                hasRelease: date.map { releaseDates.contains($0) } ?? false,
                                isValidDay: date != nil,
                                cellSize: iconSize
                            )
                            .frame(width: cellWidth, height: cellHeight)
                        }
                    }
                    .frame(height: cellHeight)
                }
            }
        }
    }

    private func dateFor(year: Int, month: Int, day: Int) -> Date? {
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components),
              calendar.component(.month, from: date) == month // Validate day exists in month
        else { return nil }
        return calendar.startOfDay(for: date)
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let date: Date?
    let hasRelease: Bool
    let isValidDay: Bool
    let cellSize: CGFloat

    private var isFuture: Bool {
        guard let date else { return false }
        return date > Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        if isValidDay {
            DandelionDayIcon(
                isFullBloom: hasRelease,
                isFuture: isFuture,
                size: cellSize
            )
        } else {
            Color.clear
                .frame(width: cellSize, height: cellSize)
        }
    }
}

#Preview {
    ScrollView {
        YearGridView(
            year: 2024,
            releaseDates: Set([
                Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 5))!,
                Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 6))!,
                Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 7))!,
                Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 15))!,
                Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 20))!
            ])
        )
        .padding()
    }
    .background(AppearanceManager().theme.background)
    .environment(AppearanceManager())
}
