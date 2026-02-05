//
//  SettingsView.swift
//  Dandelion
//
//  Settings sheet
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    let showsDoneButton: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(PremiumManager.self) private var premium
    @Environment(AppearanceManager.self) private var appearance
    @State private var showPaywall: Bool = false
    @State private var navigationPath = NavigationPath()
    @AppStorage(HapticsService.settingsKey) private var hapticsEnabled: Bool = true

    private enum Destination: Hashable {
        case prompts
        case appearance
        case sounds
        case appIcon
        case blowDetection
    }

    init(showsDoneButton: Bool = true) {
        self.showsDoneButton = showsDoneButton
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
                    .accessibilityHint("Customize writing prompts")

                    Button { navigationPath.append(Destination.appearance) } label: {
                        SettingsRow(icon: "paintpalette", title: "Appearance")
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.card)
                    .accessibilityHint("Change colors and visual style")

                    Button { navigationPath.append(Destination.sounds) } label: {
                        SettingsRow(icon: "speaker.wave.2", title: "Sounds")
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.card)
                    .accessibilityHint("Configure ambient sounds")

                    Button { navigationPath.append(Destination.blowDetection) } label: {
                        SettingsRow(icon: "wind", title: "Blow Detection")
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.card)
                    .accessibilityHint("Configure blow detection")

                    Toggle(isOn: $hapticsEnabled) {
                        HStack(spacing: DandelionSpacing.md) {
                            Image(systemName: "hand.tap")
                                .foregroundColor(theme.accent)
                                .frame(width: 24)
                            Text("Haptics")
                                .foregroundColor(theme.text)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: theme.accent))
                    .listRowBackground(theme.card)
                    .accessibilityHint("Enable or disable vibration feedback")
                } header: {
                    Text("Writing")
                        .foregroundColor(theme.secondary)
                } footer: {
                    Text("Customize your writing experience.")
                }

                Section {
                    Button { navigationPath.append(Destination.appIcon) } label: {
                        SettingsRow(icon: "app.badge", title: "App Icon")
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.card)
                    .accessibilityHint("Choose a different app icon")

                    Button {
#if os(iOS)
                        requestReview()
#else
                        if let reviewURL = AppStoreConfiguration.reviewURL {
                            openURL(reviewURL)
                        }
#endif
                    } label: {
                        SettingsRow(icon: "star", title: "Rate on the App Store", showsChevron: false)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.card)
                    .accessibilityHint("Open the App Store to leave a review")

                    ShareLink(item: AppStoreConfiguration.shareMessage) {
                        SettingsRow(icon: "square.and.arrow.up", title: "Share Dandelion", showsChevron: false)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.card)
                    .accessibilityHint("Share Dandelion with others")
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
#if os(macOS)
                    HStack {
                        Image(systemName: "icloud")
                            .foregroundColor(theme.secondary)
                            .frame(width: 24)
                        Text("CloudKit: Enabled")
                            .foregroundColor(theme.secondary)
                    }
                    .font(.dandelionSecondary)
                    .listRowBackground(theme.card)
#endif
                } header: {
                    Text("Debug")
                        .foregroundColor(theme.secondary)
                }
#endif

                Section {
                    SettingsFooterView(
                        alignment: .center,
                        textAlignment: .center,
                        useSmallText: true
                    )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(
                            top: DandelionSpacing.md,
                            leading: DandelionSpacing.lg,
                            bottom: DandelionSpacing.lg,
                            trailing: DandelionSpacing.lg
                        ))
                }
            }
            .dandelionListStyle()
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle("Settings")
            .dandelionNavigationBarStyle(background: theme.background, colorScheme: appearance.colorScheme)
            .toolbar {
                if showsDoneButton {
#if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .font(.system(size: 17, weight: .semibold))
                    }
#else
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done") {
                            dismiss()
                        }
                        .font(.system(size: 17, weight: .semibold))
                    }
#endif
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
                case .blowDetection:
                    BlowDetectionSettingsView()
                }
            }
        }
        .dandelionSettingsSheetDetents()
        .preferredColorScheme(appearance.colorScheme)
        .sheet(isPresented: $showPaywall) {
            BloomPaywallView(onClose: { showPaywall = false })
        }
    }

}

private struct SettingsRow: View {
    let icon: String
    let title: String
    let showsChevron: Bool
    @Environment(AppearanceManager.self) private var appearance

    init(icon: String, title: String, showsChevron: Bool = true) {
        self.icon = icon
        self.title = title
        self.showsChevron = showsChevron
    }

    var body: some View {
        let theme = appearance.theme
        HStack(spacing: DandelionSpacing.md) {
            Image(systemName: icon)
                .foregroundColor(theme.accent)
                .frame(width: 24)
            Text(title)
                .foregroundColor(theme.text)
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    SettingsView()
        .environment(PremiumManager.shared)
        .environment(AppearanceManager())
}
