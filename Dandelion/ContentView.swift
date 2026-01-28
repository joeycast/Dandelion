//
//  ContentView.swift
//  Dandelion
//
//  Created by Joe Castagnaro on 1/4/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var isHistoryPresented: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PremiumManager.self) private var premium
    @Environment(AppearanceManager.self) private var appearance

    var body: some View {
#if os(macOS)
        MacRootView()
            .preferredColorScheme(appearance.colorScheme)
#else
        GeometryReader { geometry in
            let topSafeArea = geometry.safeAreaInsets.top
            let bottomSafeArea = geometry.safeAreaInsets.bottom

            ZStack {
                WritingView(
                    topSafeArea: topSafeArea,
                    bottomSafeArea: bottomSafeArea,
                    onShowHistory: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isHistoryPresented = true
                        }
                    },
                    onSwipeEligibilityChange: { _ in }
                )
                .sheet(isPresented: $isHistoryPresented) {
                    ReleaseHistoryView(
                        topSafeArea: 0,
                        onNavigateToWriting: {
                            isHistoryPresented = false
                        }
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                }
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
        }
        .background(appearance.theme.background.ignoresSafeArea())
        .preferredColorScheme(appearance.colorScheme)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await premium.refreshEntitlement() }
            }
        }
#endif
    }

    private var isMacBloomLocked: Bool {
#if os(macOS)
        return !premium.isBloomUnlocked
#else
        return false
#endif
    }
}

#Preview {
    ContentView()
        .environment(PremiumManager.shared)
        .environment(AppearanceManager())
        .environment(AmbientSoundService())
        .modelContainer(for: Release.self, inMemory: true)
}
