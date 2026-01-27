//
//  MacRootView.swift
//  Dandelion
//
//  Native macOS root layout - focused writing experience.
//

import SwiftUI
import SwiftData

#if os(macOS)
struct MacRootView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(PremiumManager.self) private var premium
    @Environment(AppearanceManager.self) private var appearance

    var body: some View {
        ZStack {
            WritingView(
                topSafeArea: 0,
                bottomSafeArea: 0,
                onShowHistory: {
                    openWindow(id: "history")
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
                    openWindow(id: "history")
                } label: {
                    Image(systemName: "calendar")
                }
                .help("History (Cmd+Shift+H)")

                Button {
                    openWindow(id: "insights")
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
        .focusedSceneValue(\.openWindowAction) { windowId in
            openWindow(id: windowId)
        }
    }

    private var isMacBloomLocked: Bool {
        !premium.isBloomUnlocked
    }
}
#endif
