//
//  MacSettingsView.swift
//  Dandelion
//
//  Native macOS settings with TabView.
//

import SwiftUI
import StoreKit

#if os(macOS)
struct MacSettingsView: View {
    @Environment(PremiumManager.self) private var premium

    var body: some View {
        let isBloomLocked = !premium.isBloomUnlocked
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            PromptsSettingsView()
                .disabled(isBloomLocked)
                .tabItem {
                    Label("Prompts", systemImage: "text.quote")
                }

            AppearanceSettingsView()
                .disabled(isBloomLocked)
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }

            SoundSettingsView()
                .disabled(isBloomLocked)
                .tabItem {
                    Label("Sounds", systemImage: "speaker.wave.2")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General Settings Tab

private struct GeneralSettingsTab: View {
    @Environment(PremiumManager.self) private var premium
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @State private var showPaywall: Bool = false
    @AppStorage(HapticsService.settingsKey) private var hapticsEnabled: Bool = true

    var body: some View {
        @Bindable var premium = premium

        Form {
            Section {
                if premium.isBloomUnlocked {
                    HStack {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.green)
                        Text("Dandelion Bloom")
                        Spacer()
                        Text("Purchased")
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack {
                        Image(systemName: "leaf")
                            .foregroundColor(.green)
                        Text("Dandelion Bloom")
                        Spacer()
                        Button("Unlock") {
                            showPaywall = true
                        }
                    }
                }
            } header: {
                Text("Dandelion Bloom")
            }

            Section {
                Toggle("Haptics", isOn: $hapticsEnabled)
            } header: {
                Text("Writing")
            }

            Section {
                Button {
                    if let reviewURL = AppStoreConfiguration.reviewURL {
                        openURL(reviewURL)
                    } else {
                        requestReview()
                    }
                } label: {
                    SettingsActionRow(icon: "star", title: "Rate on the App Store")
                }
                .buttonStyle(.plain)

                ShareLink(item: AppStoreConfiguration.shareMessage) {
                    SettingsActionRow(icon: "square.and.arrow.up", title: "Share Dandelion")
                }
                .buttonStyle(.plain)
            } header: {
                Text("App")
            } footer: {
                SettingsFooterView(
                    useThemeColors: false,
                    useAppFont: false,
                    usePrimaryColor: true,
                    alignment: .center,
                    textAlignment: .center
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
                .padding(.bottom, 10)
            }

#if DEBUG
            Section {
                Toggle(isOn: $premium.debugForceBloom) {
                    Label("Debug: Bloom Unlocked", systemImage: "ladybug")
                }
                Toggle(isOn: $premium.debugForceBloomLocked) {
                    Label("Debug: Force Bloom Locked", systemImage: "lock.fill")
                }

                Label("CloudKit: Enabled", systemImage: "icloud")
                    .foregroundColor(.secondary)
            } header: {
                Text("Debug")
            }
#endif
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showPaywall) {
            BloomPaywallView(onClose: { showPaywall = false })
        }
    }
}
#endif

private struct SettingsActionRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 18)
            Text(title)
            Spacer()
        }
        .contentShape(Rectangle())
    }
}
