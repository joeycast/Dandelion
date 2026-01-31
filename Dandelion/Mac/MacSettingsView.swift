//
//  MacSettingsView.swift
//  Dandelion
//
//  Native macOS settings with TabView.
//

import SwiftUI

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
    @State private var showPaywall: Bool = false

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
