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
    @State private var navigationPath = NavigationPath()

    private enum Destination: Hashable {
        case prompts
        case appearance
        case sounds
        case appIcon
    }

    var body: some View {
        let theme = appearance.theme
        @Bindable var premium = premium
        NavigationStack(path: $navigationPath) {
            List {
                Section {
                    if premium.isBloomUnlocked {
                        HStack {
                            Image(systemName: "leaf.fill")
                                .foregroundColor(theme.accent)
                                .frame(width: 24)
                            Text("Dandelion Bloom")
                                .foregroundColor(theme.text)
                            Spacer()
                            Text("Purchased")
                                .font(.dandelionCaption)
                                .foregroundColor(theme.secondary)
                        }
                        .listRowBackground(theme.card)
                    } else {
                        BloomUnlockRow(action: { showPaywall = true })
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Dandelion Bloom")
                        .foregroundColor(theme.secondary)
                }

                Section {
                    Button { navigationPath.append(Destination.prompts) } label: {
                        SettingsRow(icon: "text.quote", title: "Prompts")
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.card)

                    Button { navigationPath.append(Destination.appearance) } label: {
                        SettingsRow(icon: "paintpalette", title: "Appearance")
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.card)

                    Button { navigationPath.append(Destination.sounds) } label: {
                        SettingsRow(icon: "speaker.wave.2", title: "Sounds")
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.card)
                } header: {
                    Text("Writing")
                        .foregroundColor(theme.secondary)
                }

                Section {
                    Button { navigationPath.append(Destination.appIcon) } label: {
                        SettingsRow(icon: "app.badge", title: "App Icon")
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.card)
                } header: {
                    Text("App")
                        .foregroundColor(theme.secondary)
                }

#if DEBUG
                Section {
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
                } header: {
                    Text("Debug")
                        .foregroundColor(theme.secondary)
                }
#endif
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
                }
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .prompts:
                    PromptsSettingsView()
                case .appearance:
                    AppearanceSettingsView()
                case .sounds:
                    SoundSettingsView()
                case .appIcon:
                    AppIconSettingsView()
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
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.secondary)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    SettingsView()
        .environment(PremiumManager.shared)
        .environment(AppearanceManager())
}
