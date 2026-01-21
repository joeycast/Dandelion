//
//  PromptsManagerTests.swift
//  DandelionTests
//
//  Unit tests for the PromptsManager
//

import XCTest
@testable import Dandelion

final class PromptsManagerTests: XCTestCase {

    var sut: PromptsManager!

    override func setUp() {
        super.setUp()
        sut = PromptsManager()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Writing Prompts Tests

    func testRandomPromptReturnsPrompt() {
        let prompt = sut.randomPrompt()
        XCTAssertNotNil(prompt, "Should return a prompt")
        XCTAssertFalse(prompt?.text.isEmpty ?? true, "Prompt text should not be empty")
    }

    func testRandomPromptReturnsVariedPrompts() {
        var prompts = Set<String>()

        // Get 10 prompts and check for variety
        for _ in 0..<10 {
            if let prompt = sut.randomPrompt() {
                prompts.insert(prompt.text)
            }
        }

        // Should have at least 3 different prompts out of 10 calls
        XCTAssertGreaterThanOrEqual(prompts.count, 3, "Should return varied prompts")
    }

    func testDefaultPromptsExist() {
        XCTAssertFalse(WritingPrompt.defaults.isEmpty, "Should have default prompts")
        XCTAssertGreaterThanOrEqual(WritingPrompt.defaults.count, 10, "Should have at least 10 default prompts")
    }

    func testAllDefaultPromptsHaveContent() {
        for prompt in WritingPrompt.defaults {
            XCTAssertFalse(prompt.text.isEmpty, "Prompt '\(prompt.id)' should have text")
            XCTAssertFalse(prompt.id.isEmpty, "Prompt should have an ID")
        }
    }

    // MARK: - Release Messages Tests

    func testRandomReleaseMessageReturnsMessage() {
        let message = sut.randomReleaseMessage()
        XCTAssertFalse(message.text.isEmpty, "Release message text should not be empty")
    }

    func testDefaultReleaseMessagesExist() {
        XCTAssertFalse(ReleaseMessage.defaults.isEmpty, "Should have default release messages")
        XCTAssertGreaterThanOrEqual(ReleaseMessage.defaults.count, 5, "Should have at least 5 default release messages")
    }

    func testAllDefaultReleaseMessagesHaveContent() {
        for message in ReleaseMessage.defaults {
            XCTAssertFalse(message.text.isEmpty, "Message '\(message.id)' should have text")
            XCTAssertFalse(message.id.isEmpty, "Message should have an ID")
        }
    }

    // MARK: - Custom Prompts Tests

    func testCustomPromptsIgnoredWhenNotPremium() {
        let custom = [WritingPrompt(text: "Custom prompt")]
        sut.updatePrompts(customPrompts: custom, disabledDefaultIds: [], isPremiumUnlocked: false)

        let prompt = sut.randomPrompt()
        XCTAssertNotEqual(prompt?.text, "Custom prompt", "Custom prompt should be locked without premium")
    }

    func testCustomPromptsAvailableWithPremium() {
        let custom = [WritingPrompt(text: "Custom prompt")]
        sut.updatePrompts(customPrompts: custom, disabledDefaultIds: [], isPremiumUnlocked: true)

        var found = false
        for _ in 0..<20 {
            if let prompt = sut.randomPrompt(), prompt.text == "Custom prompt" {
                found = true
                break
            }
        }
        XCTAssertTrue(found, "Custom prompt should be available with premium")
    }

    func testDisabledDefaultPromptsAreSkipped() {
        // Disable all default prompts except one
        let allDefaultIds = Set(WritingPrompt.defaults.map { $0.id })
        let keepId = WritingPrompt.defaults.first!.id
        let disabledIds = allDefaultIds.subtracting([keepId])

        sut.updatePrompts(customPrompts: [], disabledDefaultIds: disabledIds, isPremiumUnlocked: true)

        // All prompts should now be the one we kept
        for _ in 0..<10 {
            let prompt = sut.randomPrompt()
            XCTAssertEqual(prompt?.id, keepId, "Only the non-disabled prompt should be returned")
        }
    }

    func testAllPromptsDisabledReturnsNil() {
        // Disable all default prompts
        let allDefaultIds = Set(WritingPrompt.defaults.map { $0.id })
        sut.updatePrompts(customPrompts: [], disabledDefaultIds: allDefaultIds, isPremiumUnlocked: true)

        let prompt = sut.randomPrompt()
        XCTAssertNil(prompt, "Should return nil when all prompts are disabled")
    }

    func testNeverReturnsSamePromptTwiceInARow() {
        // With multiple prompts available, tapping "Another Prompt" should never show the same one
        for _ in 0..<20 {
            let first = sut.randomPrompt()
            let second = sut.randomPrompt()
            XCTAssertNotEqual(first?.id, second?.id, "Should never return the same prompt twice in a row")
        }
    }

    func testSamePromptAllowedWhenOnlyOneAvailable() {
        // Disable all but one default prompt
        let allDefaultIds = Set(WritingPrompt.defaults.map { $0.id })
        let keepId = WritingPrompt.defaults.first!.id
        let disabledIds = allDefaultIds.subtracting([keepId])

        sut.updatePrompts(customPrompts: [], disabledDefaultIds: disabledIds, isPremiumUnlocked: true)

        // With only one prompt, it should return the same one
        let first = sut.randomPrompt()
        let second = sut.randomPrompt()
        XCTAssertEqual(first?.id, second?.id, "Should return the same prompt when it's the only option")
    }
}
