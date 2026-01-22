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

    @State private var showPaywall: Bool = false
    @State private var showCSVExporter: Bool = false
    @State private var csvDocument = ReleaseHistoryCSVDocument(csv: "")

    var body: some View {
        let theme = appearance.theme
        let insights = ReleaseInsightsCalculator.calculate(releases: releases)

        ScrollView {
            VStack(spacing: DandelionSpacing.lg) {
                headerSummary(insights: insights)

                if releases.isEmpty {
                    emptyState
                } else if premium.isBloomUnlocked {
                    last30DaysSection(insights: insights)
                    chartsSection(summaries: insights.monthlySummaries)
                    activitySection(insights: insights)
                } else {
                    lockedPreview
                }
            }
            .padding(.horizontal, DandelionSpacing.lg)
            .padding(.top, DandelionSpacing.md)
        }
        .background(theme.background.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                exportMenu(insights: insights)
            }
        }
        .sheet(isPresented: $showPaywall) {
            BloomPaywallView(onClose: { showPaywall = false })
        }
        .fileExporter(
            isPresented: $showCSVExporter,
            document: csvDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "dandelion-release-history"
        ) { _ in }
    }

    private func headerSummary(insights: ReleaseInsights) -> some View {
        let theme = appearance.theme

        return VStack(spacing: DandelionSpacing.md) {
            HStack(spacing: DandelionSpacing.md) {
                StatBox(value: insights.totalReleases, label: "Releases")
                StatBox(value: insights.totalWords, label: "Words")
            }
            HStack(spacing: DandelionSpacing.md) {
                StatBox(value: insights.currentStreak, label: "Current Streak")
                StatBox(value: insights.longestStreak, label: "Longest Streak")
            }
        }
        .padding(.vertical, DandelionSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.primary.opacity(0.08))
        )
    }

    private func last30DaysSection(insights: ReleaseInsights) -> some View {
        SectionCard(title: "Last 30 Days") {
            VStack(spacing: DandelionSpacing.md) {
                StatRow(label: "Releases", value: insights.last30DaysReleases, trend: trendPercent(current: insights.last30DaysReleases, previous: insights.prev30DaysReleases))
                StatRow(label: "Words", value: insights.last30DaysWords, trend: trendPercent(current: insights.last30DaysWords, previous: insights.prev30DaysWords))
            }
        }
    }

    private func chartsSection(summaries: [MonthlySummary]) -> some View {
        SectionCard(title: "Last 12 Months") {
            VStack(spacing: DandelionSpacing.lg) {
                MonthlyChartView(summaries: summaries, metric: .releases)
                MonthlyChartView(summaries: summaries, metric: .words)
            }
        }
    }

    private func activitySection(insights: ReleaseInsights) -> some View {
        SectionCard(title: "Activity") {
            VStack(spacing: DandelionSpacing.md) {
                StatRow(label: "Releases (7 Days)", value: insights.releasesLast7Days)
                StatRow(label: "Weekly Avg (4w)", value: Int(round(insights.releasesPerWeekAverage)))
                StatRow(label: "Active Days", value: insights.activeDays)
                StatRowText(label: "Journey Start", value: insights.journeyStart.map { formatDate($0) } ?? "—")
                StatRow(label: "Days on Journey", value: insights.daysOnJourney)
                StatRow(label: "Average Words/Release", value: Int(round(insights.averageWordsPerRelease)))
                StatRow(label: "Median Words/Release", value: insights.medianWordsPerRelease)
                StatRow(label: "Longest Release", value: insights.longestRelease)
                StatRow(label: "Shortest Release", value: insights.shortestRelease)
                StatRow(label: "Words per Active Day", value: Int(round(insights.wordsPerActiveDay)))
                StatRowText(label: "Most Active Day", value: insights.mostActiveWeekday ?? "—")
                StatRowText(label: "Most Active Time", value: insights.mostActiveTimeBucket ?? "—")
            }
        }
    }

    private var lockedPreview: some View {
        let theme = appearance.theme

        return VStack(spacing: DandelionSpacing.md) {
            Image(systemName: "lock.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(theme.secondary)

            Text("Unlock Insights")
                .font(.dandelionTitle)
                .foregroundColor(theme.text)

            Text("See your release trends, activity patterns, and export history.")
                .font(.dandelionCaption)
                .foregroundColor(theme.secondary)
                .multilineTextAlignment(.center)

            Button("Unlock Dandelion Bloom") {
                showPaywall = true
            }
            .buttonStyle(.dandelion)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DandelionSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.subtle, lineWidth: 1)
        )
    }

    private var emptyState: some View {
        let theme = appearance.theme

        return VStack(spacing: DandelionSpacing.md) {
            DandelionBloomView(seedCount: 60, filamentsPerSeed: 12, windStrength: 0.4, style: .procedural)
                .frame(height: 140)

            Text("No releases yet")
                .font(.dandelionTitle)
                .foregroundColor(theme.text)

            Text("Write your first entry and let it go to see your journey here.")
                .font(.dandelionCaption)
                .foregroundColor(theme.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DandelionSpacing.xl)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DandelionSpacing.xl)
    }

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

            Button("Export CSV") {
                if premium.isBloomUnlocked {
                    csvDocument = ReleaseHistoryCSVDocument(csv: ReleaseHistoryExport.csvString(for: releases))
                    showCSVExporter = true
                } else {
                    showPaywall = true
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
    }

    private func trendPercent(current: Int, previous: Int) -> String {
        guard previous > 0 else { return "Not enough data" }
        let delta = Double(current - previous) / Double(previous)
        let percent = Int(round(delta * 100))
        return percent >= 0 ? "+\(percent)%" : "\(percent)%"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    let content: Content
    @Environment(AppearanceManager.self) private var appearance

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        let theme = appearance.theme

        VStack(alignment: .leading, spacing: DandelionSpacing.md) {
            Text(title)
                .font(.dandelionSecondary)
                .foregroundColor(theme.secondary)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DandelionSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.background.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.subtle.opacity(0.6), lineWidth: 1)
                )
        )
    }
}

private struct StatRow: View {
    let label: String
    let value: Int
    let trend: String?
    @Environment(AppearanceManager.self) private var appearance

    init(label: String, value: Int, trend: String? = nil) {
        self.label = label
        self.value = value
        self.trend = trend
    }

    var body: some View {
        let theme = appearance.theme

        HStack {
            Text(label)
                .foregroundColor(theme.secondary)
            Spacer()
            if let trend {
                Text(trend)
                    .font(.dandelionCaption)
                    .foregroundColor(theme.accent)
                    .padding(.trailing, DandelionSpacing.sm)
            }
            Text("\(value)")
                .foregroundColor(theme.text)
        }
        .font(.dandelionSecondary)
    }
}

private struct StatRowText: View {
    let label: String
    let value: String
    @Environment(AppearanceManager.self) private var appearance

    var body: some View {
        let theme = appearance.theme
        HStack {
            Text(label)
                .foregroundColor(theme.secondary)
            Spacer()
            Text(value)
                .foregroundColor(theme.text)
        }
        .font(.dandelionSecondary)
    }
}

private enum MonthlyMetric {
    case releases
    case words
}

private struct MonthlyChartView: View {
    let summaries: [MonthlySummary]
    let metric: MonthlyMetric
    @Environment(AppearanceManager.self) private var appearance

    var body: some View {
        let theme = appearance.theme
        let values = summaries.map { metric == .releases ? $0.releaseCount : $0.wordCount }
        let maxValue = max(values.max() ?? 1, 1)

        VStack(alignment: .leading, spacing: DandelionSpacing.sm) {
            Text(metric == .releases ? "Releases" : "Words")
                .font(.dandelionCaption)
                .foregroundColor(theme.secondary)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(summaries.enumerated()), id: \.offset) { _, summary in
                    let value = metric == .releases ? summary.releaseCount : summary.wordCount
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.primary.opacity(0.7))
                        .frame(width: 8, height: max(6, CGFloat(value) / CGFloat(maxValue) * 80))
                        .accessibilityLabel("\(value)")
                }
            }
        }
    }
}
