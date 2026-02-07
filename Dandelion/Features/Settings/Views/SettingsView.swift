//
//  SettingsView.swift
//  Dandelion
//
//  Settings sheet
//

import SwiftUI
import StoreKit
import CloudKit
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
    @AppStorage("hasUsedPromptTap") private var hasUsedPromptTap: Bool = false
    @AppStorage("hasSeenLetGoHint") private var hasSeenLetGoHint: Bool = false
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled: Bool = true
    @AppStorage("globalCountEnabled") private var globalCountEnabled: Bool = true
    @State private var iCloudAvailability: ICloudAvailability = .checking
    @State private var isICloudStatusInfoPresented: Bool = false
    @State private var showICloudSyncRestartAlert: Bool = false
    @State private var iCloudStatusTask: Task<Void, Never>?
    @State private var iCloudStatusRequestID = UUID()

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
                    iCloudStatusRow
                        .listRowBackground(theme.card)

                    Toggle(isOn: iCloudSyncToggleBinding) {
                        HStack(spacing: DandelionSpacing.md) {
                            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                                .foregroundColor(theme.accent)
                                .frame(width: 24)
                            Text("iCloud Sync")
                                .foregroundColor(theme.text)
                        }
                    }
                    .disabled(!isICloudAvailable)
                    .toggleStyle(SwitchToggleStyle(tint: theme.accent))
                    .listRowBackground(theme.card)
                    .accessibilityHint("Sync your data through iCloud when available")

                    Toggle(isOn: globalStatsToggleBinding) {
                        HStack(spacing: DandelionSpacing.md) {
                            Image(systemName: "globe")
                                .foregroundColor(theme.accent)
                                .frame(width: 24)
                            Text("Contribute to Global Stats")
                                .foregroundColor(theme.text)
                        }
                    }
                    .disabled(!isICloudAvailable)
                    .toggleStyle(SwitchToggleStyle(tint: theme.accent))
                    .listRowBackground(theme.card)
                    .accessibilityHint("Share anonymous release and word totals to show global community stats; requires iCloud")
                } header: {
                    Text("iCloud")
                        .foregroundColor(theme.secondary)
                } footer: {
                    Text("Sync keeps your release history and app settings up to date across your devices through iCloud when available. Changes to iCloud Sync apply the next time you launch Dandelion. Global stats share anonymous totals only (release and word counts). Your writing text is never uploaded.")
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

                    Button {
                        hasUsedPromptTap = false
                        hasSeenLetGoHint = false
                    } label: {
                        SettingsRow(icon: "lightbulb", title: "Reset Hints", showsChevron: false)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.card)
                    .accessibilityHint("Show helpful hints again")
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
                refreshICloudAvailability()
            }
            .onChange(of: scenePhase) { _, newValue in
                if newValue == .active {
                    refreshICloudAvailability()
                }
            }
            .onDisappear {
                iCloudStatusTask?.cancel()
                iCloudStatusTask = nil
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
        .sheet(isPresented: $isICloudStatusInfoPresented) {
            iCloudStatusInfoSheet
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .alert("Restart Required", isPresented: $showICloudSyncRestartAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Changes to iCloud Sync apply the next time you launch Dandelion.")
        }
    }

    private func refreshICloudAvailability() {
        iCloudStatusTask?.cancel()
        let requestID = UUID()
        iCloudStatusRequestID = requestID
        iCloudAvailability = .checking
        iCloudStatusTask = Task {
            let availability = await fetchICloudAvailabilityWithTimeout()
            await MainActor.run {
                guard iCloudStatusRequestID == requestID else { return }
                iCloudAvailability = availability
            }
        }
    }

    private func fetchICloudAvailabilityWithTimeout() async -> ICloudAvailability {
        await withTaskGroup(of: ICloudAvailability.self) { group in
            group.addTask {
                do {
                    let status = try await CKContainer.default().accountStatus()
                    return status == .available ? .available : .unavailable
                } catch {
                    return .unavailable
                }
            }

            group.addTask {
                try? await Task.sleep(for: .seconds(8))
                return .unavailable
            }

            let result = await group.next() ?? .unavailable
            group.cancelAll()
            return result
        }
    }

    private var iCloudStatusRow: some View {
        let theme = appearance.theme
        return Button {
            isICloudStatusInfoPresented = true
        } label: {
            HStack(spacing: DandelionSpacing.md) {
                Image(systemName: "icloud")
                    .foregroundColor(theme.accent)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text("iCloud Status")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(theme.text)
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(iCloudAvailability.dotColor)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text(iCloudAvailability.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("iCloud Status, \(iCloudAvailability.label). Double tap for details.")
    }

    private var isICloudAvailable: Bool {
        iCloudAvailability == .available
    }

    private var iCloudStatusInfoSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DandelionSpacing.md) {
                    Text(iCloudStatusSheetBody)
                        .font(.system(size: 16))
                        .foregroundColor(appearance.theme.text)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)

                    if case .unavailable = iCloudAvailability {
                        VStack(alignment: .leading, spacing: DandelionSpacing.xs) {
                            Text("To enable iCloud:")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(appearance.theme.text)
                            Text("1. Open the Settings app.")
                            Text("2. Sign in to iCloud with your Apple Account.")
                            Text("3. Return to Dandelion and check status again.")
                        }
                        .font(.system(size: 14))
                        .foregroundColor(appearance.theme.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(DandelionSpacing.lg)
            }
            .background(appearance.theme.background.ignoresSafeArea())
            .navigationTitle("iCloud Status")
            .dandelionNavigationBarStyle(background: appearance.theme.background, colorScheme: appearance.colorScheme)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isICloudStatusInfoPresented = false
                    }
                }
                if case .checking = iCloudAvailability {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Refresh") {
                            refreshICloudAvailability()
                        }
                    }
                }
            }
        }
    }

    private var iCloudStatusSheetBody: String {
        switch iCloudAvailability {
        case .available:
            return "iCloud is available on this device. iCloud Sync and Global Stats contribution can be enabled."
        case .checking:
            return "Dandelion is currently checking iCloud availability. This usually resolves in a moment."
        case .unavailable:
            return "iCloud is not available on this device right now. iCloud Sync and Global Stats contribution are turned off until iCloud is available."
        }
    }

    private var iCloudSyncToggleBinding: Binding<Bool> {
        Binding(
            get: { isICloudAvailable ? iCloudSyncEnabled : false },
            set: { newValue in
                guard isICloudAvailable else { return }
                let oldValue = iCloudSyncEnabled
                iCloudSyncEnabled = newValue
                if oldValue != newValue {
                    showICloudSyncRestartAlert = true
                }
            }
        )
    }

    private var globalStatsToggleBinding: Binding<Bool> {
        Binding(
            get: { isICloudAvailable ? globalCountEnabled : false },
            set: { newValue in
                guard isICloudAvailable else { return }
                globalCountEnabled = newValue
            }
        )
    }
}

enum ICloudAvailability {
    case checking
    case available
    case unavailable

    var label: String {
        switch self {
        case .checking:
            return "Checking..."
        case .available:
            return "Available"
        case .unavailable:
            return "Not Available"
        }
    }

    var dotColor: Color {
        switch self {
        case .checking:
            return .gray
        case .available:
            return .green
        case .unavailable:
            return .red
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
