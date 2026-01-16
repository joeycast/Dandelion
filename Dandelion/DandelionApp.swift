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
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
