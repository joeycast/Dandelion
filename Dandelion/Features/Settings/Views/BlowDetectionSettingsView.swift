//
//  BlowDetectionSettingsView.swift
//  Dandelion
//
//  Blow detection settings
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct BlowDetectionSettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppearanceManager.self) private var appearance
    @AppStorage(BlowDetectionSensitivity.settingsKey)
    private var blowSensitivity: Double = BlowDetectionSensitivity.defaultValue
    @AppStorage(BlowDetectionSensitivity.enabledKey)
    private var blowDetectionEnabled: Bool = true
    @State private var blowSensitivityIndex: Int = BlowDetectionSensitivity.presetIndex(for: BlowDetectionSensitivity.defaultValue)
    @State private var micPermission: MicrophonePermissionState = .unknown

    var body: some View {
#if os(macOS)
        Form {
            Section {
                microphonePermissionRow
                if canShowBlowDetectionControls {
                    blowDetectionToggleRow
                    if blowDetectionEnabled {
                        blowSensitivityRow
                    }
                }
            } header: {
                Text("Blow Detection")
            } footer: {
                Text("Microphone access lets you blow to release your writing, like dandelion seeds blowing away in the wind.")
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: syncState)
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                refreshMicrophonePermission()
            }
        }
        .onChange(of: blowSensitivityIndex) { _, newValue in
            blowSensitivity = BlowDetectionSensitivity.value(for: newValue)
        }
#else
        let theme = appearance.theme
        return List {
            Section {
                microphonePermissionRow
                if canShowBlowDetectionControls {
                    blowDetectionToggleRow
                    if blowDetectionEnabled {
                        blowSensitivityRow
                    }
                }
            } header: {
                Text("Blow Detection")
                    .foregroundColor(theme.secondary)
            } footer: {
                Text("Microphone access lets you blow to release your writing, like dandelion seeds blowing away in the wind.")
            }
        }
        .dandelionListStyle()
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .navigationTitle("Blow Detection")
        .dandelionNavigationBarStyle(background: theme.background, colorScheme: appearance.colorScheme)
        .onAppear(perform: syncState)
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                refreshMicrophonePermission()
            }
        }
        .onChange(of: blowSensitivityIndex) { _, newValue in
            blowSensitivity = BlowDetectionSensitivity.value(for: newValue)
        }
#endif
    }

    private var blowSensitivityLabel: String {
        BlowDetectionSensitivity.label(for: BlowDetectionSensitivity.value(for: blowSensitivityIndex))
    }

    private var canShowBlowDetectionControls: Bool {
        micPermission == .granted
    }

    private var blowDetectionToggleRow: some View {
#if os(macOS)
        return HStack {
            Label("Blow Detection", systemImage: "wind")
            Spacer()
            Toggle("", isOn: $blowDetectionEnabled)
                .labelsHidden()
        }
#else
        let theme = appearance.theme
        return HStack(spacing: DandelionSpacing.md) {
            Image(systemName: "wind")
                .foregroundColor(theme.accent)
                .frame(width: 24)
            Text("Blow Detection")
                .foregroundColor(theme.text)
            Spacer()
            Toggle("", isOn: $blowDetectionEnabled)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: theme.accent))
        }
        .listRowBackground(theme.card)
#endif
    }

    private var blowSensitivityRow: some View {
#if os(macOS)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Sensitivity", systemImage: "slider.horizontal.3")
                Spacer()
                Text(blowSensitivityLabel)
                    .foregroundColor(.secondary)
                    .font(.footnote)
            }
            Slider(
                value: Binding(
                    get: { Double(blowSensitivityIndex) },
                    set: { blowSensitivityIndex = Int($0.rounded()) }
                ),
                in: 0...Double(BlowDetectionSensitivity.maxIndex),
                step: 1
            )
            HStack {
                Spacer()
                Text("Higher means easier to trigger.")
                    .foregroundColor(.secondary)
                    .font(.footnote)
            }
        }
#else
        let theme = appearance.theme
        return VStack(alignment: .leading, spacing: DandelionSpacing.xs) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(theme.accent)
                    .frame(width: 24)
                Text("Sensitivity")
                    .foregroundColor(theme.text)
                Spacer()
                Text(blowSensitivityLabel)
                    .font(.caption)
                    .foregroundColor(theme.secondary)
            }
            Slider(value: Binding(
                get: { Double(blowSensitivityIndex) },
                set: { blowSensitivityIndex = Int($0.rounded()) }
            ), in: 0...Double(BlowDetectionSensitivity.maxIndex), step: 1)
            .tint(theme.accent)

            HStack {
                Spacer()
                Text("Higher means easier to trigger.")
                    .font(.caption)
                    .foregroundColor(theme.secondary)
            }
        }
        .listRowBackground(theme.card)
#endif
    }

    private var microphonePermissionRow: some View {
#if os(macOS)
        return HStack {
            Label("Microphone", systemImage: micPermission.iconName)
            Spacer()
            Text(micPermission.statusText)
                .foregroundColor(.secondary)
            if micPermission.isActionEnabled {
                Button(micPermission.actionTitle) {
                    handleMicrophoneAction()
                }
            }
        }
#else
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
                    .font(.caption)
                    .foregroundColor(theme.secondary)
            }
            Spacer()
            if micPermission.isActionEnabled {
                Button(micPermission.actionTitle) {
                    handleMicrophoneAction()
                }
                .font(.caption)
                .foregroundColor(theme.accent)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Microphone, \(micPermission.statusText)")
        .accessibilityHint(micPermission.isActionEnabled ? "Tap to \(micPermission.actionTitle.lowercased())" : "")
        .listRowBackground(theme.card)
#endif
    }

    private func syncState() {
        blowSensitivity = BlowDetectionSensitivity.snapped(blowSensitivity)
        blowSensitivityIndex = BlowDetectionSensitivity.presetIndex(for: blowSensitivity)
        blowDetectionEnabled = BlowDetectionSensitivity.isEnabled()
        refreshMicrophonePermission()
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
