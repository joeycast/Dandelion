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
#if os(macOS)
        soundsForm
#else
        soundsList
#endif
    }

#if os(macOS)
    private var soundsForm: some View {
        @Bindable var ambientSound = ambientSound

        return Form {
            if premium.isBloomUnlocked {
                Section {
                    Toggle("Ambient Sounds", isOn: $ambientSound.isEnabled)
                }

                if ambientSound.isEnabled {
                    Section {
                        Picker("Sound", selection: $ambientSound.selectedSound) {
                            ForEach(AmbientSound.allCases) { sound in
                                Text(sound.displayName).tag(sound)
                            }
                        }
                        .onChange(of: ambientSound.selectedSound) { _, _ in
                            ambientSound.previewSelectedSound()
                        }
                    } header: {
                        Text("Sound")
                    }

                    Section {
                        HStack {
                            Image(systemName: "speaker.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Slider(value: Binding(
                                get: { Double(ambientSound.volume) },
                                set: { ambientSound.volume = Float($0) }
                            ), in: 0...1)
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Volume")
                    }
                }
            } else {
                Section {
                    ForEach(AmbientSound.allCases) { sound in
                        Button(sound.displayName) {
                            showPaywall = true
                        }
                    }
                } header: {
                    Text("Sounds")
                } footer: {
                    Text("Calming soundscapes to accompany your writing. Included with Dandelion Bloom.")
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showPaywall) {
            BloomPaywallView(onClose: { showPaywall = false })
        }
    }
#endif

    private var soundsList: some View {
        let theme = appearance.theme
        @Bindable var ambientSound = ambientSound

        return List {
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
                                ambientSound.previewSelectedSound()
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
                            .foregroundColor(theme.secondary)
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
                            .foregroundColor(theme.secondary)
                    }
                }
            } else {
                Section {
                    ForEach(AmbientSound.allCases) { sound in
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Text(sound.displayName)
                                    .foregroundColor(theme.text)
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(theme.card)
                    }
                } header: {
                    Text("Sounds")
                        .foregroundColor(theme.secondary)
                } footer: {
                    (Text("Calming soundscapes to accompany your writing. Included with ") +
                    Text("Dandelion Bloom")
                        .foregroundColor(theme.accent) +
                    Text("."))
                    .onTapGesture { showPaywall = true }
                }
            }
        }
        .dandelionListStyle()
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .navigationTitle("Sounds")
        .tint(theme.primary)
        .dandelionNavigationBarStyle(background: theme.background, colorScheme: appearance.colorScheme)
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
