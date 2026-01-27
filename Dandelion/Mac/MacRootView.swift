//
//  MacRootView.swift
//  Dandelion
//
//  Native macOS root layout - focused writing experience with inspector panel.
//

import SwiftUI
import SwiftData

#if os(macOS)
struct MacRootView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(PremiumManager.self) private var premium
    @Environment(AppearanceManager.self) private var appearance
    @Query(sort: \Release.timestamp) private var releases: [Release]

    @State private var activePanel: MacPanelType?

    var body: some View {
        ZStack {
            WritingView(
                topSafeArea: 0,
                bottomSafeArea: 0,
                onShowHistory: {
                    togglePanel(.history)
                },
                onSwipeEligibilityChange: { _ in },
                isActive: !isMacBloomLocked
            )
            .allowsHitTesting(!isMacBloomLocked)

            if isMacBloomLocked {
                BloomPaywallView(
                    title: "Dandelion Bloom Required",
                    subtitle: "Unlock the full Dandelion experience on Mac.",
                    bodyText: "Bloom is a one-time purchase that brings Insights, custom prompts, themes, and ambient sounds to all your devices.",
                    showsClose: false
                )
            }
        }
        .background(appearance.theme.background.ignoresSafeArea())
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    togglePanel(.history)
                } label: {
                    Image(systemName: "calendar")
                }
                .help("History (Cmd+Shift+H)")

                Button {
                    togglePanel(.insights)
                } label: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                }
                .help("Insights (Cmd+Shift+I)")

                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings (Cmd+,)")
            }
        }
        .inspector(isPresented: Binding(
            get: { activePanel != nil },
            set: { if !$0 { activePanel = nil } }
        )) {
            inspectorContent
                .inspectorColumnWidth(min: 350, ideal: 400, max: 500)
        }
        .focusedSceneValue(\.togglePanelAction) { panelType in
            togglePanel(panelType)
        }
    }

    @ViewBuilder
    private var inspectorContent: some View {
        switch activePanel {
        case .history:
            ReleaseHistoryView(
                topSafeArea: 0,
                showsTabs: false,
                onNavigateToWriting: {
                    activePanel = nil
                }
            )
            .background(appearance.theme.background)
        case .insights:
            InsightsView(releases: releases)
                .background(appearance.theme.background)
        case nil:
            EmptyView()
        }
    }

    private func togglePanel(_ panelType: MacPanelType) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if activePanel == panelType {
                activePanel = nil
            } else {
                activePanel = panelType
            }
        }
    }

    private var isMacBloomLocked: Bool {
        !premium.isBloomUnlocked
    }
}
#endif
