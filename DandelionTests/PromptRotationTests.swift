//
//  PromptRotationTests.swift
//  DandelionTests
//
//  Tests for prompt and release-message rotation rules and default content
//

import XCTest
@testable import Dandelion

@MainActor
final class PromptRotationTests: XCTestCase {

    func testDefaultPromptIdsAreUnique() {
        let ids = WritingPrompt.defaults.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Default prompt IDs back DefaultPromptSetting and must be unique")
    }

    func testDefaultReleaseMessageIdsAreUnique() {
        let ids = ReleaseMessage.defaults.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testReleaseMessagesDoNotRepeatWithinThree() {
        let manager = PromptsManager()
        var recent: [String] = []

        for _ in 0..<50 {
            let message = manager.randomReleaseMessage()
            XCTAssertFalse(recent.contains(message.id), "Message \(message.id) repeated within three releases")
            recent.append(message.id)
            if recent.count > 3 { recent.removeFirst() }
        }
    }

    func testPromptsDoNotRepeatWithinFive() {
        let manager = PromptsManager()
        var recent: [String] = []

        for _ in 0..<60 {
            guard let prompt = manager.randomPrompt() else {
                return XCTFail("Expected a prompt")
            }
            XCTAssertFalse(recent.contains(prompt.id), "Prompt \(prompt.id) repeated within five prompts")
            recent.append(prompt.id)
            if recent.count > 5 { recent.removeFirst() }
        }
    }

    func testNonPremiumSeesAllDefaultsEvenWithDisabledIds() {
        let manager = PromptsManager()
        manager.updatePrompts(
            customPrompts: [WritingPrompt(text: "Custom")],
            disabledDefaultIds: Set(WritingPrompt.defaults.map(\.id)),
            isPremiumUnlocked: false
        )

        XCTAssertEqual(manager.availablePrompts, WritingPrompt.defaults)
        XCTAssertEqual(manager.availablePromptCount, WritingPrompt.defaults.count)
    }

    func testPremiumCountCombinesActiveDefaultsAndCustomPrompts() {
        let manager = PromptsManager()
        let custom = [WritingPrompt(text: "One"), WritingPrompt(text: "Two")]
        manager.updatePrompts(customPrompts: custom, disabledDefaultIds: ["1", "2", "3"], isPremiumUnlocked: true)

        XCTAssertEqual(manager.availablePromptCount, WritingPrompt.defaults.count - 3 + custom.count)
        XCTAssertFalse(manager.availablePrompts.contains { ["1", "2", "3"].contains($0.id) })
    }

    func testPromptsRoundTripThroughCodable() throws {
        let data = PromptsData(
            writingPrompts: [WritingPrompt(id: "a", text: "Prompt")],
            releaseMessages: [ReleaseMessage(id: "b", text: "Message")]
        )

        let decoded = try JSONDecoder().decode(PromptsData.self, from: JSONEncoder().encode(data))
        XCTAssertEqual(decoded.writingPrompts, data.writingPrompts)
        XCTAssertEqual(decoded.releaseMessages, data.releaseMessages)
    }
}
