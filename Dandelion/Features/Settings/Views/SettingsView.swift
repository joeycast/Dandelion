//
//  SettingsView.swift
//  Dandelion
//
//  Settings sheet
//

import SwiftUI
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    let showsDoneButton: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PremiumManager.self) private var premium
    @Environment(AppearanceManager.self) private var appearance
    @State private var showPaywall: Bool = false
    @State private var navigationPath = NavigationPath()
    @AppStorage(HapticsService.settingsKey) private var hapticsEnabled: Bool = true
    @State private var micPermission: MicrophonePermissionState = .unknown

    private enum Destination: Hashable {
        case prompts
        case appearance
        case sounds
        case appIcon
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

                    microphonePermissionRow
                        .listRowBackground(theme.card)
                } header: {
                    Text("Writing")
                        .foregroundColor(theme.secondary)
                } footer: {
                    Text("Microphone access lets you blow to release your writing, like dandelion seeds blowing away in the wind.")
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
            .onAppear {
                refreshMicrophonePermission()
            }
            .onChange(of: scenePhase) { _, newValue in
                if newValue == .active {
                    refreshMicrophonePermission()
                }
            }
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
                }
            }
        }
        .dandelionSettingsSheetDetents()
        .preferredColorScheme(appearance.colorScheme)
        .sheet(isPresented: $showPaywall) {
            BloomPaywallView(onClose: { showPaywall = false })
        }
    }

    private var microphonePermissionRow: some View {
        let theme = appearance.theme
        return HStack(spacing: DandelionSpacing.md) {
            Image(systemName: micPermission.iconName)
                .foregroundColor(theme.accent)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Microphone")
                    .foregroundColor(theme.text)
                Text(micPermission.statusText)
                    .font(.dandelionCaption)
                    .foregroundColor(theme.secondary)
            }
            Spacer()
            if micPermission.isActionEnabled {
                Button(micPermission.actionTitle) {
                    handleMicrophoneAction()
                }
                .font(.dandelionCaption)
                .foregroundColor(theme.accent)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Microphone, \(micPermission.statusText)")
        .accessibilityHint(micPermission.isActionEnabled ? "Tap to \(micPermission.actionTitle.lowercased())" : "")
    }

    private func refreshMicrophonePermission() {
        let status = WritingViewModel.permissionStatus()
        if !status.determined {
            micPermission = .notDetermined
        } else if status.granted {
            micPermission = .granted
        } else {
            micPermission = .denied
        }
    }

    private func handleMicrophoneAction() {
        switch micPermission {
        case .notDetermined:
            Task {
                _ = await WritingViewModel.requestMicrophonePermission()
                refreshMicrophonePermission()
            }
        case .denied:
            openAppSettings()
        case .granted, .unknown:
            break
        }
    }

    private func openAppSettings() {
#if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
#elseif os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            openURL(url)
        }
#endif
    }
}

private enum MicrophonePermissionState {
    case unknown
    case notDetermined
    case granted
    case denied

    var statusText: String {
        switch self {
        case .unknown:
            return "Checking status…"
        case .notDetermined:
            return "Not granted"
        case .granted:
            return "Enabled"
        case .denied:
            return "Disabled in Settings"
        }
    }

    var actionTitle: String {
        switch self {
        case .notDetermined:
            return "Enable"
        case .denied:
            return "Open Settings"
        case .granted:
            return "Enabled"
        case .unknown:
            return "Enable"
        }
    }

    var isActionEnabled: Bool {
        switch self {
        case .granted:
            return false
        case .unknown:
            return false
        case .notDetermined, .denied:
            return true
        }
    }

    var iconName: String {
        switch self {
        case .granted:
            return "mic.fill"
        case .notDetermined:
            return "mic"
        case .denied:
            return "mic.slash"
        case .unknown:
            return "mic"
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
