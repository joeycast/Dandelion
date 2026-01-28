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
    @State private var isInspectorPresented: Bool = false
    @State private var closeTask: Task<Void, Never>?

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
            get: { isInspectorPresented },
            set: { if !$0 { closeInspector(animated: true) } }
        )) {
            inspectorContent
                .inspectorColumnWidth(min: 350, ideal: 400, max: 500)
        }
        .focusedSceneValue(\.togglePanelAction) { panelType in
            togglePanel(panelType)
        }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
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
        if activePanel == panelType {
            closeInspector(animated: true)
            return
        }

        if activePanel == nil {
            activePanel = panelType
            withAnimation(.easeInOut(duration: 0.25)) {
                isInspectorPresented = true
            }
        } else {
            // Avoid animating a full content swap while the inspector is open.
            activePanel = panelType
            if !isInspectorPresented {
                isInspectorPresented = true
            }
        }
    }

    private var isMacBloomLocked: Bool {
        !premium.isBloomUnlocked
    }

    private func closeInspector(animated: Bool) {
        closeTask?.cancel()
        if animated {
            withAnimation(.easeInOut(duration: 0.25)) {
                isInspectorPresented = false
            }
        } else {
            isInspectorPresented = false
        }

        closeTask = Task {
            try? await Task.sleep(nanoseconds: 260_000_000)
            guard !Task.isCancelled, !isInspectorPresented else { return }
            activePanel = nil
        }
    }
}
#endif
