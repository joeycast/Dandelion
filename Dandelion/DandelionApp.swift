//
//  DandelionApp.swift
//  Dandelion
//
//  Created by Joe Castagnaro on 1/4/26.
//

import SwiftUI
import SwiftData

@main
struct DandelionApp: App {
    let modelContainer: ModelContainer
    private let premiumManager = PremiumManager.shared
    private let appearanceManager = AppearanceManager()
    private let ambientSoundService = AmbientSoundService()

    init() {
        let schema = Schema([Release.self, CustomPrompt.self, DefaultPromptSetting.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            // DEBUG: Seed mock release for testing
            #if DEBUG
            seedMockData()
            #endif
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
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
        .modelContainer(modelContainer)
#endif
    }
}
