//
//  InsightsView.swift
//  Dandelion
//
//  Premium insights and export for release history
//

import SwiftUI
import UniformTypeIdentifiers

struct InsightsView: View {
    let releases: [Release]

    @Environment(PremiumManager.self) private var premium
    @Environment(AppearanceManager.self) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var insights: ReleaseInsights
    @State private var showPaywall: Bool = false
    @State private var showCSVExporter: Bool = false
    @State private var csvDocument = ReleaseHistoryCSVDocument(csv: "")
    @State private var selectedReleaseMonthIndex: Int?
    @State private var selectedWordsMonthIndex: Int?
    @State private var hoveredReleaseMonthIndex: Int?
    @State private var hoveredWordsMonthIndex: Int?

    init(releases: [Release]) {
        self.releases = releases
        _insights = State(initialValue: ReleaseInsightsCalculator.calculate(releases: releases))
    }

    var body: some View {
        let theme = appearance.theme

        ScrollView {
            VStack(spacing: DandelionSpacing.lg) {
#if os(macOS)
                // On macOS, place share button inline at top right of content
                HStack {
                    Spacer()
                    exportMenu(insights: insights)
                }
#endif
                if releases.isEmpty {
                    emptyState
                } else if premium.isBloomUnlocked {
                    journeyHero(insights: insights)
                    streaksSection(insights: insights)
                    recentActivitySection(insights: insights)
                    monthlyTrendsSection(summaries: insights.monthlySummaries)
                    activityStatsSection(insights: insights)
                    patternsSection(insights: insights)
                    privacyNote
                } else {
                    journeyHeroLocked(insights: insights)
                    lockedInsightsPreview(insights: insights)
                }
            }
            .padding(.horizontal, DandelionSpacing.lg)
            .padding(.top, DandelionSpacing.md)
            .padding(.bottom, DandelionSpacing.xxl)
        }
        .background(theme.background.ignoresSafeArea())
#if os(iOS)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                exportMenu(insights: insights)
            }
        }
#endif
        .sheet(isPresented: $showPaywall) {
            BloomPaywallView(onClose: { showPaywall = false })
        }
        .fileExporter(
            isPresented: $showCSVExporter,
            document: csvDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "dandelion-release-history"
        ) { _ in }
        .onChange(of: releases) { _, _ in
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                insights = ReleaseInsightsCalculator.calculate(releases: releases)
            }
        }
    }

    // MARK: - Journey Hero (Unlocked)

    private func journeyHero(insights: ReleaseInsights) -> some View {
        let theme = appearance.theme

        return VStack(spacing: DandelionSpacing.sm) {
            // Main stats - large and prominent
            HStack(alignment: .firstTextBaseline, spacing: DandelionSpacing.xl) {
                VStack(spacing: DandelionSpacing.xs) {
                    Text(formatNumber(insights.totalReleases))
                        .font(.system(size: 44, weight: .light, design: .serif))
                        .foregroundColor(theme.primary)
                    Text("releases")
                        .font(.dandelionCaption)
                        .foregroundColor(theme.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(insights.totalReleases) total releases")

                VStack(spacing: DandelionSpacing.xs) {
                    Text(formatNumber(insights.totalWords))
                        .font(.system(size: 44, weight: .light, design: .serif))
                        .foregroundColor(theme.primary)
                    Text("words let go")
                        .font(.dandelionCaption)
                        .foregroundColor(theme.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(insights.totalWords) words let go")
            }

            // Journey duration
            if let start = insights.journeyStart {
                Text("since \(formatDateLong(start))")
                    .font(.dandelionCaption)
                    .foregroundColor(theme.secondary)
                    .padding(.top, DandelionSpacing.xs)
                    .accessibilityLabel("Your journey started on \(formatDateLong(start))")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DandelionSpacing.xs)
    }

    // MARK: - Journey Hero (Locked - shows totals only)

    private func journeyHeroLocked(insights: ReleaseInsights) -> some View {
        let theme = appearance.theme

        return VStack(spacing: DandelionSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: DandelionSpacing.xl) {
                VStack(spacing: DandelionSpacing.xs) {
                    Text(formatNumber(insights.totalReleases))
                        .font(.system(size: 44, weight: .light, design: .serif))
                        .foregroundColor(theme.primary)
                    Text("releases")
                        .font(.dandelionCaption)
                        .foregroundColor(theme.secondary)
                }

                VStack(spacing: DandelionSpacing.xs) {
                    Text(formatNumber(insights.totalWords))
                        .font(.system(size: 44, weight: .light, design: .serif))
                        .foregroundColor(theme.primary)
                    Text("words let go")
                        .font(.dandelionCaption)
                        .foregroundColor(theme.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DandelionSpacing.md)
    }

    // MARK: - Streaks Section

    private func streaksSection(insights: ReleaseInsights) -> some View {
        let theme = appearance.theme

        return HStack(spacing: DandelionSpacing.md) {
            // Current streak
            VStack(spacing: DandelionSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(insights.currentStreak)")
                        .font(.system(size: 32, weight: .light, design: .serif))
                        .foregroundColor(theme.primary)
                    Text(insights.currentStreak == 1 ? "day" : "days")
                        .font(.dandelionCaption)
                        .foregroundColor(theme.secondary)
                }
                Text("current streak")
                    .font(.dandelionCaption)
                    .foregroundColor(theme.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DandelionSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.card)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Current streak: \(insights.currentStreak) \(insights.currentStreak == 1 ? "day" : "days")")

            // Longest streak
            VStack(spacing: DandelionSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(insights.longestStreak)")
                        .font(.system(size: 32, weight: .light, design: .serif))
                        .foregroundColor(theme.primary)
                    Text(insights.longestStreak == 1 ? "day" : "days")
                        .font(.dandelionCaption)
                        .foregroundColor(theme.secondary)
                }
                Text("longest streak")
                    .font(.dandelionCaption)
                    .foregroundColor(theme.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DandelionSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.card)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Longest streak: \(insights.longestStreak) \(insights.longestStreak == 1 ? "day" : "days")")
        }
    }

    // MARK: - Recent Activity

    private func recentActivitySection(insights: ReleaseInsights) -> some View {
        let theme = appearance.theme

        return VStack(alignment: .leading, spacing: DandelionSpacing.sm) {
            Text("Last 30 Days")
                .font(.system(size: 15, weight: .medium, design: .serif))
                .foregroundColor(theme.secondary)
                .padding(.leading, DandelionSpacing.xs)

            HStack(spacing: DandelionSpacing.md) {
                // Releases
                VStack(spacing: DandelionSpacing.xs) {
                    Text("\(insights.last30DaysReleases)")
                        .font(.system(size: 28, weight: .light, design: .serif))
                        .foregroundColor(theme.text)
                    Text("releases")
                        .font(.dandelionCaption)
                        .foregroundColor(theme.secondary)
                    if insights.prev30DaysReleases > 0 {
                        trendBadge(current: insights.last30DaysReleases, previous: insights.prev30DaysReleases)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DandelionSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.card)
                )

                // Words
                VStack(spacing: DandelionSpacing.xs) {
                    Text(formatNumber(insights.last30DaysWords))
                        .font(.system(size: 28, weight: .light, design: .serif))
                        .foregroundColor(theme.text)
                    Text("words")
                        .font(.dandelionCaption)
                        .foregroundColor(theme.secondary)
                    if insights.prev30DaysWords > 0 {
                        trendBadge(current: insights.last30DaysWords, previous: insights.prev30DaysWords)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DandelionSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.card)
                )
            }
        }
    }

    private func trendBadge(current: Int, previous: Int) -> some View {
        let theme = appearance.theme
        let delta = Double(current - previous) / Double(previous)
        let percent = Int(round(delta * 100))
        let isPositive = percent >= 0

        return HStack(spacing: 2) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .medium))
            Text("\(abs(percent))%")
                .font(.system(size: 12, weight: .medium, design: .serif))
        }
        .foregroundColor(isPositive ? theme.accent : theme.secondary)
        .padding(.top, DandelionSpacing.xs)
    }

    // MARK: - Monthly Trends

    private func monthlyTrendsSection(summaries: [MonthlySummary]) -> some View {
        let theme = appearance.theme

        return VStack(alignment: .leading, spacing: DandelionSpacing.sm) {
            Text("Your Year")
                .font(.system(size: 15, weight: .medium, design: .serif))
                .foregroundColor(theme.secondary)
                .padding(.leading, DandelionSpacing.xs)

            VStack(spacing: DandelionSpacing.lg) {
                monthlyChart(
                    summaries: summaries,
                    metric: .releases,
                    label: "Releases",
                    selectedIndex: $selectedReleaseMonthIndex,
                    hoveredIndex: $hoveredReleaseMonthIndex
                )
                monthlyChart(
                    summaries: summaries,
                    metric: .words,
                    label: "Words",
                    selectedIndex: $selectedWordsMonthIndex,
                    hoveredIndex: $hoveredWordsMonthIndex
                )
            }
            .padding(DandelionSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.card)
            )
        }
    }

    private func monthlyChart(
        summaries: [MonthlySummary],
        metric: MonthlyMetric,
        label: String,
        selectedIndex: Binding<Int?>,
        hoveredIndex: Binding<Int?>
    ) -> some View {
        let theme = appearance.theme
        let values = summaries.map { metric == .releases ? $0.releaseCount : $0.wordCount }
        let maxValue = max(values.max() ?? 1, 1)
        let activeIndex = hoveredIndex.wrappedValue ?? selectedIndex.wrappedValue

        return VStack(alignment: .leading, spacing: DandelionSpacing.sm) {
            Text(label)
                .font(.dandelionCaption)
                .foregroundColor(theme.secondary)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(summaries.enumerated()), id: \.offset) { index, summary in
                    let value = metric == .releases ? summary.releaseCount : summary.wordCount
                    let height = max(4, CGFloat(value) / CGFloat(maxValue) * 60)
                    let isSelected = activeIndex == index
                    let hasSelection = activeIndex != nil
                    let barOpacity = hasSelection && !isSelected ? 0.25 : 1.0

                    VStack(spacing: 4) {
                        if isSelected {
                            Text(formatCompactNumber(value))
                                .font(.system(size: 14, weight: .medium, design: .serif))
                                .foregroundColor(theme.text)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.bottom, 2)
                                .transition(.opacity)
                        }
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.accent.opacity(0.85))
                            .frame(height: height)
                            .opacity(barOpacity)

                        Text(monthLabel(from: summary.monthStart))
                            .font(.system(size: 9, design: .serif))
                            .foregroundColor(theme.subtle)
                            .opacity(barOpacity)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedIndex.wrappedValue = isSelected ? nil : index
                        }
                    }
#if os(macOS)
                    .onHover { isHovering in
                        withAnimation(.easeInOut(duration: 0.12)) {
                            if isHovering {
                                hoveredIndex.wrappedValue = index
                            } else if hoveredIndex.wrappedValue == index {
                                hoveredIndex.wrappedValue = nil
                            }
                        }
                    }
#endif
                }
            }
            .frame(height: 80)
        }
    }

    private func monthLabel(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).prefix(1).uppercased()
    }

    // MARK: - Activity Stats Section

    private func activityStatsSection(insights: ReleaseInsights) -> some View {
        let theme = appearance.theme

        return VStack(alignment: .leading, spacing: DandelionSpacing.sm) {
            Text("Activity")
                .font(.system(size: 15, weight: .medium, design: .serif))
                .foregroundColor(theme.secondary)
                .padding(.leading, DandelionSpacing.xs)

            VStack(spacing: 0) {
                statRow(label: "Releases (7 days)", value: "\(insights.releasesLast7Days)")
                Divider().background(theme.subtle.opacity(0.5))
                statRow(label: "Weekly average", value: "\(Int(round(insights.releasesPerWeekAverage)))")
                Divider().background(theme.subtle.opacity(0.5))
                statRow(label: "Active days", value: "\(insights.activeDays)")
                Divider().background(theme.subtle.opacity(0.5))
                statRow(label: "Days on journey", value: "\(insights.daysOnJourney)")
            }
            .padding(.horizontal, DandelionSpacing.md)
            .padding(.vertical, DandelionSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.card)
            )
        }
    }

    // MARK: - Patterns Section

    private func patternsSection(insights: ReleaseInsights) -> some View {
        let theme = appearance.theme

        return VStack(alignment: .leading, spacing: DandelionSpacing.sm) {
            Text("Patterns")
                .font(.system(size: 15, weight: .medium, design: .serif))
                .foregroundColor(theme.secondary)
                .padding(.leading, DandelionSpacing.xs)

            VStack(spacing: 0) {
                statRow(label: "Most active day", value: insights.mostActiveWeekday ?? "—")
                Divider().background(theme.subtle.opacity(0.5))
                statRow(label: "Most active time", value: insights.mostActiveTimeBucket ?? "—")
                Divider().background(theme.subtle.opacity(0.5))
                statRow(label: "Average words/release", value: "\(Int(round(insights.averageWordsPerRelease)))")
                Divider().background(theme.subtle.opacity(0.5))
                statRow(label: "Median words/release", value: "\(insights.medianWordsPerRelease)")
                Divider().background(theme.subtle.opacity(0.5))
                statRow(label: "Longest release", value: "\(insights.longestRelease) words")
                Divider().background(theme.subtle.opacity(0.5))
                statRow(label: "Shortest release", value: "\(insights.shortestRelease) words")
                Divider().background(theme.subtle.opacity(0.5))
                statRow(label: "Words per active day", value: formatNumber(Int(round(insights.wordsPerActiveDay))))
            }
            .padding(.horizontal, DandelionSpacing.md)
            .padding(.vertical, DandelionSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.card)
            )
        }
    }

    private func statRow(label: String, value: String) -> some View {
        let theme = appearance.theme

        return HStack {
            Text(label)
                .font(.dandelionSecondary)
                .foregroundColor(theme.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundColor(theme.text)
        }
        .padding(.vertical, DandelionSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Privacy Note

    private var privacyNote: some View {
        let theme = appearance.theme

        return VStack(spacing: DandelionSpacing.sm) {
            Image(systemName: "lock.shield")
                .font(.system(size: 20))
                .foregroundColor(theme.secondary)

            Text("Your data stays with you")
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(theme.secondary)

            Text("Release history is stored locally on your device and in iCloud (if enabled). We never store your actual words—only dates, counts, and word totals. Dandelion has no servers.")
                .font(.system(size: 12, design: .serif))
                .foregroundColor(theme.subtle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DandelionSpacing.md)
        }
        .padding(.vertical, DandelionSpacing.lg)
        .padding(.horizontal, DandelionSpacing.md)
    }

    // MARK: - Locked Preview

    private func lockedInsightsPreview(insights: ReleaseInsights) -> some View {
        VStack(spacing: DandelionSpacing.lg) {
            streaksSection(insights: insights)
            recentActivitySection(insights: insights)
            monthlyTrendsSection(summaries: insights.monthlySummaries)
            activityStatsSection(insights: insights)
            patternsSection(insights: insights)
        }
        .blur(radius: 6)
        .allowsHitTesting(false)
        .overlay(alignment: .top) {
            BloomUnlockCallout(
                title: "Discover your patterns",
                subtitle: "See trends, streaks, and insights about your writing journey.",
                action: { showPaywall = true }
            )
            .padding(.top, DandelionSpacing.lg)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        let theme = appearance.theme

        return VStack(spacing: DandelionSpacing.lg) {
            DandelionBloomView(
                seedCount: 60,
                filamentsPerSeed: 12,
                windStrength: 0.4,
                style: .procedural,
                isAnimating: appearance.isWindAnimationAllowed && !reduceMotion
            )
                .frame(height: 160)
                .accessibilityHidden(true)

            VStack(spacing: DandelionSpacing.sm) {
                Text("Your journey awaits")
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundColor(theme.text)

                Text("Write your first entry and let it go to begin tracking your progress here.")
                    .font(.dandelionSecondary)
                    .foregroundColor(theme.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DandelionSpacing.lg)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DandelionSpacing.xxl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your journey awaits. Write your first entry and let it go to begin tracking your progress here.")
    }

    // MARK: - Export Menu

    private func exportMenu(insights: ReleaseInsights) -> some View {
        let summary = ReleaseHistoryExport.summaryText(for: releases, insights: insights)

        return Menu {
            if premium.isBloomUnlocked {
                ShareLink(item: summary) {
                    Label("Share Summary", systemImage: "square.and.arrow.up")
                }
            } else {
                Button("Share Summary") {
                    showPaywall = true
                }
            }

            Button {
                if premium.isBloomUnlocked {
                    csvDocument = ReleaseHistoryCSVDocument(csv: ReleaseHistoryExport.csvString(for: releases, insights: insights))
                    showCSVExporter = true
                } else {
                    showPaywall = true
                }
            } label: {
                Label("Export CSV", systemImage: "tablecells")
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
    }

    // MARK: - Helpers

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func formatCompactNumber(_ number: Int) -> String {
        let absValue = abs(number)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0

        if absValue >= 1_000_000 {
            let value = Double(number) / 1_000_000
            formatter.maximumFractionDigits = abs(value) < 10 ? 1 : 0
            let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
            return "\(formatted)M"
        }

        if absValue >= 1_000 {
            let value = Double(number) / 1_000
            formatter.maximumFractionDigits = abs(value) < 10 ? 1 : 0
            let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
            return "\(formatted)K"
        }

        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func formatDateLong(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

private enum MonthlyMetric {
    case releases
    case words
}
