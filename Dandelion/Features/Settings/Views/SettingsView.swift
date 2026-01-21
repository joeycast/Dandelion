//
//  SettingsView.swift
//  Dandelion
//
//  Settings sheet
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PremiumManager.self) private var premium
    @Environment(AppearanceManager.self) private var appearance
    @State private var showPaywall: Bool = false

    var body: some View {
        let theme = appearance.theme
        @Bindable var premium = premium
        NavigationStack {
            List {
                Section {
                    Button {
                        if !premium.isBloomUnlocked {
                            showPaywall = true
                        }
                    } label: {
                        HStack {
                            if premium.isBloomUnlocked {
                                Image(systemName: "leaf.fill")
                                    .foregroundColor(theme.accent)
                                    .frame(width: 24)
                                Text("Dandelion Bloom")
                                    .foregroundColor(theme.text)
                                Spacer()
                                Text("Purchased")
                                    .font(.dandelionCaption)
                                    .foregroundColor(theme.secondary)
                            } else {
                                Image(systemName: "leaf")
                                    .foregroundColor(theme.accent)
                                    .frame(width: 24)
                                Text("Unlock Dandelion Bloom")
                                    .foregroundColor(theme.text)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(theme.subtle)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.card)
#if DEBUG
                    Toggle(isOn: $premium.debugForceBloom) {
                        HStack {
                            Image(systemName: "ladybug")
                                .foregroundColor(theme.secondary)
                                .frame(width: 24)
                            Text("Debug: Bloom Unlocked")
                                .foregroundColor(theme.text)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: theme.accent))
                    .listRowBackground(theme.card)
#endif
                }

                Section {
                    NavigationLink {
                        PromptsSettingsView()
                    } label: {
                        SettingsRow(icon: "text.quote", title: "Prompts")
                    }
                    .listRowBackground(theme.card)

                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        SettingsRow(icon: "paintpalette", title: "Appearance")
                    }
                    .listRowBackground(theme.card)

                    NavigationLink {
                        SoundSettingsView()
                    } label: {
                        SettingsRow(icon: "speaker.wave.2", title: "Sounds")
                    }
                    .listRowBackground(theme.card)
                } header: {
                    Text("Writing")
                }

                Section {
                    NavigationLink {
                        AppIconSettingsView()
                    } label: {
                        SettingsRow(icon: "app.badge", title: "App Icon")
                    }
                    .listRowBackground(theme.card)
                } header: {
                    Text("App")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.background, for: .navigationBar)
            .toolbarColorScheme(appearance.colorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(theme.primary)
                }
            }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showPaywall) {
            BloomPaywallView(onClose: { showPaywall = false })
        }
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    @Environment(AppearanceManager.self) private var appearance

    var body: some View {
        let theme = appearance.theme
        HStack(spacing: DandelionSpacing.md) {
            Image(systemName: icon)
                .foregroundColor(theme.accent)
                .frame(width: 24)
            Text(title)
                .foregroundColor(theme.text)
        }
    }
}

#Preview {
    SettingsView()
        .environment(PremiumManager.shared)
        .environment(AppearanceManager())
}
