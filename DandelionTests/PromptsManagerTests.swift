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
        XCTAssertFalse(prompt.text.isEmpty, "Prompt text should not be empty")
    }

    func testRandomPromptReturnsVariedPrompts() {
        var prompts = Set<String>()

        // Get 10 prompts and check for variety
        for _ in 0..<10 {
            let prompt = sut.randomPrompt()
            prompts.insert(prompt.text)
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
}
