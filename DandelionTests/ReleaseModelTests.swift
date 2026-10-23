//
//  ReleaseModelTests.swift
//  DandelionTests
//
//  Tests for the SwiftData models that back release history and prompts
//

import XCTest
import SwiftData
@testable import Dandelion

@MainActor
final class ReleaseModelTests: XCTestCase {

    func testCalendarDayIsStartOfDay() throws {
        let timestamp = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 9, hour: 23, minute: 59)))
        let release = Release(timestamp: timestamp, wordCount: 3)

        XCTAssertEqual(release.calendarDay, Calendar.current.startOfDay(for: timestamp))
    }

    func testModelsPersistInMemoryStore() throws {
        let schema = Schema([Release.self, CustomPrompt.self, DefaultPromptSetting.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        context.insert(Release(wordCount: 42))
        context.insert(CustomPrompt(text: "What is on your mind?"))
        context.insert(DefaultPromptSetting(promptId: "3", isEnabled: false))
        try context.save()

        let releases = try context.fetch(FetchDescriptor<Release>())
        XCTAssertEqual(releases.map(\.wordCount), [42])

        let prompts = try context.fetch(FetchDescriptor<CustomPrompt>())
        XCTAssertEqual(prompts.first?.text, "What is on your mind?")
        XCTAssertEqual(prompts.first?.isActive, true)

        let settings = try context.fetch(FetchDescriptor<DefaultPromptSetting>())
        XCTAssertEqual(settings.first?.promptId, "3")
        XCTAssertEqual(settings.first?.isEnabled, false)
    }

    func testModelDefaults() {
        let release = Release()
        XCTAssertEqual(release.wordCount, 0)

        let setting = DefaultPromptSetting(promptId: "1")
        XCTAssertTrue(setting.isEnabled)
    }
}
