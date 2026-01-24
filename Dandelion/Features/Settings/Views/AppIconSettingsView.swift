//
//  AppIconSettingsView.swift
//  Dandelion
//
//  Alternate app icons (Bloom)
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AppIconSettingsView: View {
    @Environment(PremiumManager.self) private var premium
    @Environment(AppearanceManager.self) private var appearance

    @State private var selectedIcon: AppIconOption = .default
    @State private var showPaywall: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isUpdatingIcon: Bool = false

    var body: some View {
        let theme = appearance.theme
        let availableOptions: [AppIconOption] = [
            .default,
            // .watercolor,
            // .lineArt,
            .dawn,
            .twilight,
            .forest,
        ]

        List {
#if canImport(UIKit)
            if UIApplication.shared.supportsAlternateIcons {
                Section {
                    ForEach(availableOptions) { option in
                        Button {
                            select(option)
                        } label: {
                            HStack(spacing: DandelionSpacing.md) {
                                // Icon preview
                                Image(option.previewImageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(theme.subtle, lineWidth: 0.5)
                                    )

                                Text(option.displayName)
                                    .foregroundColor(theme.text)

                                Spacer()

                                if selectedIcon == option {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(theme.accent)
                                } else if option != .default && !premium.isBloomUnlocked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isUpdatingIcon)
                        .listRowBackground(theme.card)
                    }
                } header: {
                    Text("App Icon")
                        .foregroundColor(theme.secondary)
                } footer: {
                    if !premium.isBloomUnlocked {
                        (Text("Custom icons included with ") +
                        Text("Dandelion Bloom")
                            .foregroundColor(theme.accent) +
                        Text("."))
                        .onTapGesture { showPaywall = true }
                    }
                }
            } else {
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(theme.secondary)
                        Text("Alternate icons are not available on this device.")
                            .font(.dandelionSecondary)
                            .foregroundColor(theme.secondary)
                    }
                    .listRowBackground(theme.card)
                }
            }
#else
            Section {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(theme.secondary)
                    Text("Alternate icons are not available on macOS.")
                        .font(.dandelionSecondary)
                        .foregroundColor(theme.secondary)
                }
                .listRowBackground(theme.card)
            }
#endif
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.primary)
        .toolbarBackground(theme.background, for: .navigationBar)
        .toolbarColorScheme(appearance.colorScheme, for: .navigationBar)
        .onAppear {
            selectedIcon = AppIconOption.current
#if DEBUG
            debugLog("[AppIcon] supportsAlternateIcons=\(UIApplication.shared.supportsAlternateIcons) current=\(selectedIcon.rawValue)")
#endif
        }
        .sheet(isPresented: $showPaywall) {
            BloomPaywallView(onClose: { showPaywall = false })
        }
        .alert("App Icon Unavailable", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func select(_ option: AppIconOption) {
#if DEBUG
        debugLog("[AppIcon] select \(option.rawValue) iconName=\(option.iconName ?? "default")")
#endif
        if option == .default || premium.isBloomUnlocked {
#if canImport(UIKit)
            guard !isUpdatingIcon else { return }
            isUpdatingIcon = true
            UIApplication.shared.setAlternateIconName(option.iconName) { error in
#if DEBUG
                if let error {
                    let nsError = error as NSError
                    debugLog("[AppIcon] failed: \(error.localizedDescription) domain=\(nsError.domain) code=\(nsError.code)")
                    if !nsError.userInfo.isEmpty {
                        debugLog("[AppIcon] error userInfo=\(nsError.userInfo)")
                    }
                } else {
                    debugLog("[AppIcon] success")
                }
#endif
                if let error {
                    let nsError = error as NSError
                    let shouldRetry = nsError.localizedDescription.contains("Resource temporarily unavailable")
                    if shouldRetry {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            UIApplication.shared.setAlternateIconName(option.iconName) { retryError in
#if DEBUG
                                if let retryError {
                                    let nsRetryError = retryError as NSError
                                    debugLog("[AppIcon] retry failed: \(retryError.localizedDescription) domain=\(nsRetryError.domain) code=\(nsRetryError.code)")
                                    if !nsRetryError.userInfo.isEmpty {
                                        debugLog("[AppIcon] retry userInfo=\(nsRetryError.userInfo)")
                                    }
                                } else {
                                    debugLog("[AppIcon] retry success")
                                }
#endif
                                isUpdatingIcon = false
                                if let retryError {
                                    errorMessage = retryError.localizedDescription
                                    showError = true
                                    selectedIcon = AppIconOption.current
                                } else {
                                    selectedIcon = option
                                }
                            }
                        }
                    } else {
                        isUpdatingIcon = false
                        errorMessage = error.localizedDescription
                        showError = true
                        selectedIcon = AppIconOption.current
                    }
                } else {
                    isUpdatingIcon = false
                    selectedIcon = option
                }
            }
#endif
        } else {
            showPaywall = true
        }
    }
}

enum AppIconOption: String, CaseIterable, Identifiable {
    case `default`
    case watercolor
    case lineArt
    case dawn
    case twilight
    case forest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .watercolor: return "Watercolor"
        case .lineArt: return "Line Art"
        case .dawn: return "Dawn"
        case .twilight: return "Twilight"
        case .forest: return "Forest"
        }
    }

    var iconName: String? {
        switch self {
        case .default:
            return nil
        case .watercolor:
            return "AppIcon-Watercolor"
        case .lineArt:
            return "AppIcon-LineArt"
        case .dawn:
            return "AppIcon-Dawn"
        case .twilight:
            return "AppIcon-Twilight"
        case .forest:
            return "AppIcon-Forest"
        }
    }

    /// Preview image name in asset catalog
    var previewImageName: String {
        switch self {
        case .default: return "AppIconPreview-Default"
        case .watercolor: return "AppIconPreview-Watercolor"
        case .lineArt: return "AppIconPreview-LineArt"
        case .dawn: return "AppIconPreview-Dawn"
        case .twilight: return "AppIconPreview-Twilight"
        case .forest: return "AppIconPreview-Forest"
        }
    }

#if canImport(UIKit)
    static var current: AppIconOption {
        let currentName = UIApplication.shared.alternateIconName
        return AppIconOption.allCases.first(where: { $0.iconName == currentName }) ?? .default
    }
#else
    static var current: AppIconOption { .default }
#endif
}

#Preview {
    NavigationStack {
        AppIconSettingsView()
    }
    .environment(PremiumManager.shared)
    .environment(AppearanceManager())
}
