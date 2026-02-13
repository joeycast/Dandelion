//
//  ReminderNotificationService.swift
//  Dandelion
//
//  Local daily reminder scheduling for release prompts.
//

import Foundation
import UserNotifications

@Observable
@MainActor
final class ReminderNotificationService {
    enum PermissionState: Equatable {
        case unknown
        case notDetermined
        case authorized
        case denied
    }

    static let reminderTitle = "Dandelion"

    var isEnabled: Bool
    var hour: Int
    var minute: Int
    private(set) var permissionState: PermissionState = .unknown

    private let center: ReminderNotificationCenter
    private let userDefaults: UserDefaults
    private let calendar: Calendar

    private enum Keys {
        static let isEnabled = "releaseReminder.isEnabled"
        static let hour = "releaseReminder.hour"
        static let minute = "releaseReminder.minute"
        static let lastScheduledAt = "releaseReminder.lastScheduledAt"
        static let lastKnownTimeZoneID = "releaseReminder.lastKnownTimeZoneID"
        static let hasShownFirstReleaseNudge = "releaseReminder.hasShownFirstReleaseNudge.v2"
    }

    private static let reminderPrefix = "release-reminder-"
    private let schedulingHorizonDays = 14

    convenience init(
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.init(
            center: SystemReminderNotificationCenter(),
            userDefaults: userDefaults,
            calendar: calendar
        )
    }

    init(
        center: ReminderNotificationCenter,
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.center = center
        self.userDefaults = userDefaults
        self.calendar = calendar

        let hasStoredEnabled = userDefaults.object(forKey: Keys.isEnabled) != nil
        self.isEnabled = hasStoredEnabled ? userDefaults.bool(forKey: Keys.isEnabled) : false

        let storedHour = userDefaults.object(forKey: Keys.hour) as? Int
        let storedMinute = userDefaults.object(forKey: Keys.minute) as? Int
        self.hour = storedHour ?? 20
        self.minute = storedMinute ?? 0

        if userDefaults.string(forKey: Keys.lastKnownTimeZoneID) == nil {
            userDefaults.set(TimeZone.current.identifier, forKey: Keys.lastKnownTimeZoneID)
        }
    }

    var reminderTime: Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }

    var hasShownPostFirstReleaseNudge: Bool {
        userDefaults.bool(forKey: Keys.hasShownFirstReleaseNudge)
    }

    var shouldPresentPostFirstReleaseNudge: Bool {
        permissionState == .notDetermined && !hasShownPostFirstReleaseNudge
    }

    func markPostFirstReleaseNudgeShown() {
        userDefaults.set(true, forKey: Keys.hasShownFirstReleaseNudge)
    }

    func refreshPermissionStatus() async {
        let status = await center.authorizationStatus()
        permissionState = Self.permissionState(from: status)
        debugLog("[Reminders] refreshPermissionStatus status=\(status.rawValue) mapped=\(permissionState)")

        if permissionState != .authorized && isEnabled {
            isEnabled = false
            persistSettings()
            await cancelAllNotifications()
            debugLog("[Reminders] permission not authorized, disabling reminders")
        }
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            await refreshPermissionStatus()
            debugLog("[Reminders] requestPermission granted=\(granted)")
            return granted
        } catch {
            await refreshPermissionStatus()
            debugLog("[Reminders] requestPermission error=\(error.localizedDescription)")
            return false
        }
    }

    func setEnabled(_ enabled: Bool, releases: [Release], now: Date = Date()) async {
        isEnabled = enabled
        persistSettings()

        guard enabled else {
            await cancelAllNotifications()
            return
        }

        guard permissionState == .authorized else {
            isEnabled = false
            persistSettings()
            return
        }

        await scheduleNotifications(releases: releases, now: now)
    }

    func updateReminderTime(_ date: Date, releases: [Release], now: Date = Date()) async {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        hour = components.hour ?? 20
        minute = components.minute ?? 0
        persistSettings()

        guard isEnabled, permissionState == .authorized else { return }
        await scheduleNotifications(releases: releases, now: now)
    }

    func rescheduleIfNeeded(releases: [Release], now: Date = Date()) async {
        await refreshPermissionStatus()
        guard isEnabled, permissionState == .authorized else { return }

        let didTimeZoneChange = userDefaults.string(forKey: Keys.lastKnownTimeZoneID) != TimeZone.current.identifier
        let lastScheduledAt = userDefaults.object(forKey: Keys.lastScheduledAt) as? Date
        let wasScheduledBeforeToday = {
            guard let lastScheduledAt else { return true }
            return !calendar.isDate(lastScheduledAt, inSameDayAs: now)
        }()

        if didTimeZoneChange || wasScheduledBeforeToday {
            userDefaults.set(TimeZone.current.identifier, forKey: Keys.lastKnownTimeZoneID)
            await scheduleNotifications(releases: releases, now: now)
            return
        }

        await reconcileMissingNotifications(releases: releases, now: now)
    }

    func handleReleaseRecorded(now: Date = Date()) async {
        guard isEnabled, permissionState == .authorized else { return }
        await cancelReminder(for: now)
        await scheduleNotifications(skipToday: true, now: now)
    }

    func cancelAllNotifications() async {
        let requests = await center.pendingNotificationRequests()
        let ids = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.reminderPrefix) }
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Scheduling

    private func scheduleNotifications(releases: [Release] = [], skipToday: Bool = false, now: Date) async {
        await clearScheduledReminders()

        let startOfToday = calendar.startOfDay(for: now)
        let hasReleasedToday = skipToday || releases.contains { calendar.isDate($0.timestamp, inSameDayAs: now) }

        for dayOffset in 0..<schedulingHorizonDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
            if dayOffset == 0 && hasReleasedToday { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = minute
            guard let fireDate = calendar.date(from: components) else { continue }

            if fireDate <= now { continue }

            let content = UNMutableNotificationContent()
            content.title = Self.reminderTitle
            content.body = ReminderMessageLibrary.body(for: day, calendar: calendar)
            content.sound = .default

            let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
            let identifier = Self.reminderPrefix + Self.scheduleKeyDateFormatter.string(from: day)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
            } catch {
                // Best effort scheduling.
            }
        }

        userDefaults.set(now, forKey: Keys.lastScheduledAt)
        userDefaults.set(TimeZone.current.identifier, forKey: Keys.lastKnownTimeZoneID)
    }

    private func clearScheduledReminders() async {
        let requests = await center.pendingNotificationRequests()
        let ids = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.reminderPrefix) }

        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func reconcileMissingNotifications(releases: [Release], now: Date) async {
        let requests = await center.pendingNotificationRequests()
        let scheduled = Set(
            requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.reminderPrefix) }
        )

        let startOfToday = calendar.startOfDay(for: now)
        let hasReleasedToday = releases.contains { calendar.isDate($0.timestamp, inSameDayAs: now) }

        var expectedCount = 0
        for dayOffset in 0..<schedulingHorizonDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
            if dayOffset == 0 && hasReleasedToday { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = minute
            guard let fireDate = calendar.date(from: components), fireDate > now else { continue }

            expectedCount += 1
            let identifier = Self.reminderPrefix + Self.scheduleKeyDateFormatter.string(from: day)
            if !scheduled.contains(identifier) {
                await scheduleNotifications(releases: releases, now: now)
                return
            }
        }

        if scheduled.count != expectedCount {
            await scheduleNotifications(releases: releases, now: now)
        }
    }

    private func cancelReminder(for date: Date) async {
        let day = calendar.startOfDay(for: date)
        let id = Self.reminderPrefix + Self.scheduleKeyDateFormatter.string(from: day)
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    private func persistSettings() {
        userDefaults.set(isEnabled, forKey: Keys.isEnabled)
        userDefaults.set(hour, forKey: Keys.hour)
        userDefaults.set(minute, forKey: Keys.minute)
    }

    private static func permissionState(from status: UNAuthorizationStatus) -> PermissionState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        @unknown default:
            return .unknown
        }
    }

    private static let scheduleKeyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

protocol ReminderNotificationCenter {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

struct SystemReminderNotificationCenter: ReminderNotificationCenter {
    private let center = UNUserNotificationCenter.current()

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
