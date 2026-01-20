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

    init() {
        let schema = Schema([Release.self])
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

        // Create date for January 9, 2023
        var components = DateComponents()
        components.year = 2023
        components.month = 1
        components.day = 9
        guard let mockDate = Calendar.current.date(from: components) else { return }

        // Check if we already have a release on this date
        let startOfDay = Calendar.current.startOfDay(for: mockDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<Release>(
            predicate: #Predicate { release in
                release.timestamp >= startOfDay && release.timestamp < endOfDay
            }
        )

        do {
            let existing = try context.fetch(descriptor)
            if existing.isEmpty {
                let mockRelease = Release(timestamp: mockDate, wordCount: 42)
                context.insert(mockRelease)
                try context.save()
            }
        } catch {
            print("Failed to seed mock data: \(error)")
        }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
