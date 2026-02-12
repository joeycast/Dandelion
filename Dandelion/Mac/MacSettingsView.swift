//
//  MacSettingsView.swift
//  Dandelion
//
//  Native macOS settings with TabView.
//

import SwiftUI
import StoreKit
import CloudKit

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

            BlowDetectionSettingsView()
                .tabItem {
                    Label("Blow Detection", systemImage: "wind")
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
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(HapticsService.settingsKey) private var hapticsEnabled: Bool = true
    @AppStorage("hasUsedPromptTap") private var hasUsedPromptTap: Bool = false
    @AppStorage("hasSeenLetGoHint") private var hasSeenLetGoHint: Bool = false
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled: Bool = true
    @AppStorage("globalCountEnabled") private var globalCountEnabled: Bool = true
    @State private var iCloudAvailability: ICloudAvailability = .checking
    @State private var showICloudSyncRestartAlert: Bool = false
    @State private var showHintsResetAlert: Bool = false
    @State private var iCloudStatusTask: Task<Void, Never>?
    @State private var iCloudStatusRequestID = UUID()

    var body: some View {
        @Bindable var premium = premium

        Form {
            Section {
                if premium.isBloomUnlocked {
                    HStack {
                        Image(systemName: "leaf.fill")
                        Text("Dandelion Bloom")
                        Spacer()
                        Text("Purchased")
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack {
                        Image(systemName: "leaf")
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
                Toggle(isOn: $hapticsEnabled) {
                    Label("Haptics", systemImage: "hand.tap")
                }
            } header: {
                Text("Writing")
            } footer: {
                Text("Customize your writing experience.")
            }

            Section {
                HStack {
                    Label("iCloud Status", systemImage: "icloud")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(iCloudAvailability.dotColor)
                            .frame(width: 8, height: 8)
                        Text(iCloudAvailability.label)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: iCloudSyncToggleBinding) {
                    Label("iCloud Sync", systemImage: "arrow.triangle.2.circlepath.icloud")
                }
                    .disabled(!isICloudAvailable)

                Toggle(isOn: globalStatsToggleBinding) {
                    Label("Contribute to Global Stats", systemImage: "globe")
                }
                    .disabled(!isICloudAvailable)
            } header: {
                Text("iCloud")
            } footer: {
                Text("Sync keeps your release history and app settings up to date across your devices through iCloud when available. Changes to iCloud Sync apply the next time you launch Dandelion. Global stats share anonymous totals only (release and word counts). Your writing text is never uploaded.")
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

                Button {
                    hasUsedPromptTap = false
                    hasSeenLetGoHint = false
                    showHintsResetAlert = true
                } label: {
                    SettingsActionRow(icon: "lightbulb", title: "Reset Hints")
                }
                .buttonStyle(.plain)
            } header: {
                Text("App")
            }

            Section {
                ForEach(AppStoreConfiguration.moreFromBrink13Labs) { link in
                    Button {
                        openURL(link.url)
                    } label: {
                        SettingsActionRow(icon: link.symbol, title: link.title)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("More from Brink 13 Labs")
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
            } header: {
                Text("Debug")
            }
#endif
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showPaywall) {
            BloomPaywallView(onClose: { showPaywall = false })
        }
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
        .alert("Restart Required", isPresented: $showICloudSyncRestartAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Changes to iCloud Sync apply the next time you launch Dandelion.")
        }
        .alert("Hints Reset", isPresented: $showHintsResetAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You’ll see helpful hints again as you use Dandelion.")
        }
    }

    private var isICloudAvailable: Bool {
        iCloudAvailability == .available
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

    private func refreshICloudAvailability() {
        iCloudStatusTask?.cancel()
        let requestID = UUID()
        iCloudStatusRequestID = requestID
        iCloudAvailability = .checking
        iCloudStatusTask = Task {
            let availability = await fetchICloudAvailability()
            await MainActor.run {
                guard iCloudStatusRequestID == requestID else { return }
                iCloudAvailability = availability
            }
        }
    }

    private func fetchICloudAvailability() async -> ICloudAvailability {
        do {
            let status = try await CKContainer.default().accountStatus()
            return status == .available ? .available : .unavailable
        } catch {
            return .unavailable
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
