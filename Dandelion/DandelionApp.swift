//
//  DandelionApp.swift
//  Dandelion
//
//  Created by Joe Castagnaro on 1/4/26.
//

import SwiftUI
import SwiftData
import OSLog
#if os(macOS)
import AppKit
#endif

@main
struct DandelionApp: App {
    private static let logger = Logger(subsystem: "app.brink13labs.Dandelion", category: "AppLaunch")
    let modelContainer: ModelContainer
    private let premiumManager = PremiumManager.shared
    private let appearanceManager = AppearanceManager()
    private let ambientSoundService = AmbientSoundService()
    private let reminderNotificationService = ReminderNotificationService()
    private static let iCloudSyncSettingKey = "iCloudSyncEnabled"

    init() {
        UserDefaults.standard.register(defaults: [Self.iCloudSyncSettingKey: true])
        let iCloudSyncEnabled = UserDefaults.standard.bool(forKey: Self.iCloudSyncSettingKey)
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = iCloudSyncEnabled ? .automatic : .none

        let schema = Schema([Release.self, CustomPrompt.self, DefaultPromptSetting.self])
        modelContainer = Self.makeModelContainer(
            schema: schema,
            preferredCloudKitDatabase: cloudKitDatabase,
            preferredCloudKitEnabled: iCloudSyncEnabled
        )

#if os(macOS)
        NSHelpManager.shared.registerBooks(in: .main)
#endif

        // DEBUG: Seed mock release for testing
        #if DEBUG
        seedMockData()
        #endif
    }

    private static func makeModelContainer(
        schema: Schema,
        preferredCloudKitDatabase: ModelConfiguration.CloudKitDatabase,
        preferredCloudKitEnabled: Bool
    ) -> ModelContainer {
        do {
            return try buildModelContainer(schema: schema, cloudKitDatabase: preferredCloudKitDatabase)
        } catch {
            logger.error("ModelContainer init failed with preferred CloudKit mode: \(String(describing: error), privacy: .public)")

            if preferredCloudKitEnabled {
                do {
                    let fallbackContainer = try buildModelContainer(schema: schema, cloudKitDatabase: .none)
                    UserDefaults.standard.set(false, forKey: iCloudSyncSettingKey)
                    logger.error("Fell back to local-only SwiftData store and disabled iCloud Sync for this install.")
                    return fallbackContainer
                } catch {
                    logger.error("Fallback local SwiftData store init also failed: \(String(describing: error), privacy: .public)")
                }
            }

            do {
                let inMemoryConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
                logger.error("Using in-memory SwiftData store as last-resort launch fallback.")
                return try ModelContainer(for: schema, configurations: [inMemoryConfiguration])
            } catch {
                fatalError("Could not create any ModelContainer configuration: \(error)")
            }
        }
    }

    private static func buildModelContainer(
        schema: Schema,
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase
    ) throws -> ModelContainer {
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: cloudKitDatabase
        )

        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    }

    #if DEBUG
    private func seedMockData() {
        let context = modelContainer.mainContext
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        guard let startWindow = calendar.date(byAdding: .month, value: -11, to: startOfMonth) else { return }
        let seedKey = "didSeedMockData_v3"
        guard !UserDefaults.standard.bool(forKey: seedKey) else { return }

        do {
            for monthOffset in 0..<12 {
                guard let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: startWindow),
                      let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else { continue }

                let releasesThisMonth = 4 + (monthOffset % 5) * 2
                let daysInMonth = dayRange.count

                for releaseIndex in 0..<releasesThisMonth {
                    let day = min(daysInMonth, 1 + (releaseIndex * 3 + monthOffset) % daysInMonth)
                    let hour = (releaseIndex * 5 + monthOffset * 2) % 24
                    let minute = (releaseIndex * 7 + monthOffset * 3) % 60
                    let second = (releaseIndex * 11) % 60

                    var components = calendar.dateComponents([.year, .month], from: monthStart)
                    components.day = day
                    components.hour = hour
                    components.minute = minute
                    components.second = second

                    guard let date = calendar.date(from: components), date <= now else { continue }

                    let wordCount = 120 + ((monthOffset * 37 + releaseIndex * 53) % 1400)
                    context.insert(Release(timestamp: date, wordCount: wordCount))
                }
            }

            try context.save()
            UserDefaults.standard.set(true, forKey: seedKey)
        } catch {
            debugLog("Failed to seed mock data: \(error)")
        }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        .environment(premiumManager)
        .environment(appearanceManager)
        .environment(ambientSoundService)
        .environment(reminderNotificationService)
#if os(macOS)
        .defaultSize(width: 900, height: 700)
        .commands {
            MacCommands()
        }
#endif

#if os(macOS)
        Settings {
            MacSettingsView()
        }
        .environment(premiumManager)
        .environment(appearanceManager)
        .environment(ambientSoundService)
        .environment(reminderNotificationService)
        .modelContainer(modelContainer)
#endif
    }
}
