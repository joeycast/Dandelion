//
//  ReminderSettingsView.swift
//  Dandelion
//
//  Daily release reminder settings.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct ReminderSettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppearanceManager.self) private var appearance
    @Environment(ReminderNotificationService.self) private var reminderService
    @Query(sort: \Release.timestamp) private var releases: [Release]

    var body: some View {
        Group {
#if os(macOS)
            Form {
                Section {
                    permissionRow
                    if reminderService.permissionState == .authorized {
                        Toggle("Daily Reminder", isOn: isEnabledBinding)
                        if reminderService.isEnabled {
                            DatePicker(
                                "Time",
                                selection: reminderTimeBinding,
                                displayedComponents: [.hourAndMinute]
                            )
                        }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("A gentle daily reminder to write and let go.")
                }
            }
            .formStyle(.grouped)
#else
            let theme = appearance.theme

            List {
                Section {
                    permissionRow

                    if reminderService.permissionState == .authorized {
                        Toggle(isOn: isEnabledBinding) {
                            HStack(spacing: DandelionSpacing.md) {
                                Image(systemName: "clock")
                                    .foregroundColor(theme.accent)
                                    .frame(width: 24)
                                Text("Daily Reminder")
                                    .foregroundColor(theme.text)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: theme.accent))
                        .listRowBackground(theme.card)

                        if reminderService.isEnabled {
                            DatePicker(
                                "Time",
                                selection: reminderTimeBinding,
                                displayedComponents: [.hourAndMinute]
                            )
                            .listRowBackground(theme.card)
                        }
                    }
                } header: {
                    Text("Reminders")
                        .foregroundColor(theme.secondary)
                } footer: {
                    Text("A gentle daily reminder to write and let go.")
                }
            }
            .dandelionListStyle()
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle("Reminders")
            .dandelionNavigationBarStyle(background: theme.background, colorScheme: appearance.colorScheme)
#endif
        }
        .onAppear {
            Task {
                await reminderService.refreshPermissionStatus()
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task {
                await reminderService.refreshPermissionStatus()
                await reminderService.rescheduleIfNeeded(releases: releases)
            }
        }
    }

    private var isEnabledBinding: Binding<Bool> {
        Binding(
            get: { reminderService.isEnabled },
            set: { newValue in
                Task {
                    await reminderService.setEnabled(newValue, releases: releases)
                }
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { reminderService.reminderTime },
            set: { newValue in
                Task {
                    await reminderService.updateReminderTime(newValue, releases: releases)
                }
            }
        )
    }

    private var permissionRow: some View {
#if os(macOS)
        return HStack {
            Label("Notifications", systemImage: iconName)
            Spacer()
            Text(statusText)
                .foregroundColor(.secondary)
            if actionTitle != nil {
                Button(actionTitle ?? "") {
                    handlePermissionAction()
                }
            }
        }
#else
        let theme = appearance.theme
        return HStack(spacing: DandelionSpacing.md) {
            Image(systemName: iconName)
                .foregroundColor(theme.accent)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications")
                    .foregroundColor(theme.text)
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(theme.secondary)
            }
            Spacer()
            if let actionTitle {
                Button(actionTitle) {
                    handlePermissionAction()
                }
                .font(.caption)
                .foregroundColor(theme.accent)
            }
        }
        .listRowBackground(theme.card)
#endif
    }

    private var iconName: String {
        switch reminderService.permissionState {
        case .authorized:
            return "bell.badge.fill"
        case .denied:
            return "bell.slash"
        case .notDetermined, .unknown:
            return "bell"
        }
    }

    private var statusText: String {
        switch reminderService.permissionState {
        case .unknown:
            return "Checking status…"
        case .notDetermined:
            return "Not enabled"
        case .authorized:
            return "Enabled"
        case .denied:
            return "Disabled in Settings"
        }
    }

    private var actionTitle: String? {
        switch reminderService.permissionState {
        case .notDetermined:
            return "Enable"
        case .denied:
            return "Open Settings"
        case .unknown, .authorized:
            return nil
        }
    }

    private func handlePermissionAction() {
        switch reminderService.permissionState {
        case .notDetermined:
            Task {
                _ = await reminderService.requestPermission()
            }
        case .denied:
            openAppSettings()
        case .authorized, .unknown:
            break
        }
    }

    private func openAppSettings() {
#if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
#elseif os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            openURL(url)
        }
#endif
    }
}
