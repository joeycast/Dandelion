//
//  SoundSettingsView.swift
//  Dandelion
//
//  Ambient sound settings
//

import SwiftUI

struct SoundSettingsView: View {
    @Environment(AmbientSoundService.self) private var ambientSound
    @Environment(PremiumManager.self) private var premium
    @Environment(AppearanceManager.self) private var appearance

    @State private var showPaywall: Bool = false

    var body: some View {
        let theme = appearance.theme
        @Bindable var ambientSound = ambientSound

        List {
            if premium.isBloomUnlocked {
                Section {
                    Toggle(isOn: $ambientSound.isEnabled) {
                        HStack(spacing: DandelionSpacing.md) {
                            Image(systemName: ambientSound.isEnabled ? "speaker.wave.2.fill" : "speaker.wave.2")
                                .foregroundColor(theme.accent)
                                .frame(width: 24)
                            Text("Ambient Sounds")
                                .foregroundColor(theme.text)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: theme.accent))
                    .listRowBackground(theme.card)
                }

                if ambientSound.isEnabled {
                    Section {
                        ForEach(AmbientSound.allCases) { sound in
                            Button {
                                ambientSound.selectedSound = sound
                            } label: {
                                HStack {
                                    Text(sound.displayName)
                                        .foregroundColor(theme.text)
                                    Spacer()
                                    if ambientSound.selectedSound == sound {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(theme.accent)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(theme.card)
                        }
                    } header: {
                        Text("Sound")
                    }

                    Section {
                        VStack(alignment: .leading, spacing: DandelionSpacing.sm) {
                            HStack {
                                Image(systemName: "speaker.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.secondary)
                                Slider(value: Binding(
                                    get: { Double(ambientSound.volume) },
                                    set: { ambientSound.volume = Float($0) }
                                ), in: 0...1)
                                .tint(theme.accent)
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.secondary)
                            }
                        }
                        .listRowBackground(theme.card)
                    } header: {
                        Text("Volume")
                    }
                }
            } else {
                Section {
                    BloomLockedCard(
                        title: "Unlock Ambient Sounds",
                        subtitle: "Add calming soundscapes to accompany your writing.",
                        isCompact: true,
                        action: { showPaywall = true }
                    )
                    .listRowBackground(theme.card)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .navigationTitle("Sounds")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.background, for: .navigationBar)
        .toolbarColorScheme(appearance.colorScheme, for: .navigationBar)
        .sheet(isPresented: $showPaywall) {
            BloomPaywallView(onClose: { showPaywall = false })
        }
    }
}

#Preview {
    NavigationStack {
        SoundSettingsView()
    }
    .environment(PremiumManager.shared)
    .environment(AppearanceManager())
    .environment(AmbientSoundService())
}
