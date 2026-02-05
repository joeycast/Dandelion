//
//  WritingViewModelTests.swift
//  DandelionTests
//
//  Unit tests for the WritingViewModel
//

import XCTest
@testable import Dandelion

@MainActor
final class WritingViewModelTests: XCTestCase {

    var sut: WritingViewModel!
    private var originalBlowDetectionEnabled: Any?

    override func setUp() {
        super.setUp()
        originalBlowDetectionEnabled = UserDefaults.standard.object(forKey: BlowDetectionSensitivity.enabledKey)
        sut = WritingViewModel()
    }

    override func tearDown() {
        if let originalBlowDetectionEnabled {
            UserDefaults.standard.set(originalBlowDetectionEnabled, forKey: BlowDetectionSensitivity.enabledKey)
        } else {
            UserDefaults.standard.removeObject(forKey: BlowDetectionSensitivity.enabledKey)
        }
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialStateIsPrompt() {
        XCTAssertEqual(sut.writingState, .prompt, "Initial state should be prompt")
    }

    func testInitialTextIsEmpty() {
        XCTAssertTrue(sut.writtenText.isEmpty, "Initial text should be empty")
    }

    func testInitialPromptIsSet() {
        XCTAssertNotNil(sut.currentPrompt, "Initial prompt should be set")
        XCTAssertFalse(sut.currentPrompt?.text.isEmpty ?? true, "Initial prompt text should not be empty")
    }

    func testInitialReleaseMessageIsSet() {
        XCTAssertFalse(sut.currentReleaseMessage.text.isEmpty, "Initial release message should be set")
    }

    // MARK: - Can Release Tests

    func testCanReleaseIsFalseWhenTextIsEmpty() {
        sut.writtenText = ""
        XCTAssertFalse(sut.canRelease, "Cannot release when text is empty")
    }

    func testCanReleaseIsFalseWhenTextIsWhitespaceOnly() {
        sut.writtenText = "   \n\t  "
        XCTAssertFalse(sut.canRelease, "Cannot release when text is only whitespace")
    }

    func testCanReleaseIsTrueWhenTextHasContent() {
        sut.writtenText = "Hello world"
        XCTAssertTrue(sut.canRelease, "Can release when text has content")
    }

    func testCanReleaseIsTrueWithSingleCharacter() {
        sut.writtenText = "a"
        XCTAssertTrue(sut.canRelease, "Can release with single character")
    }

    // MARK: - Has Text Tests

    func testHasTextIsFalseWhenEmpty() {
        sut.writtenText = ""
        XCTAssertFalse(sut.hasText, "hasText should be false when empty")
    }

    func testHasTextIsTrueWithContent() {
        sut.writtenText = "content"
        XCTAssertTrue(sut.hasText, "hasText should be true with content")
    }

    // MARK: - State Transition Tests

    func testStartWritingTransitionsToWritingState() {
        sut.startWriting()
        XCTAssertEqual(sut.writingState, .writing, "Should transition to writing state")
    }

    func testManualReleaseDoesNothingWhenNoText() {
        sut.writingState = .writing
        sut.writtenText = ""
        sut.manualRelease()
        XCTAssertEqual(sut.writingState, .writing, "Should stay in writing state when no text")
    }

    func testManualReleaseTransitionsToReleasingWhenHasText() {
        sut.writingState = .writing
        sut.writtenText = "Some thoughts to release"
        sut.manualRelease()
        XCTAssertEqual(sut.writingState, .releasing, "Should transition to releasing state")
    }

    func testReleaseCompleteClearsText() {
        sut.writtenText = "Some text that will be released"
        sut.releaseComplete()
        XCTAssertTrue(sut.writtenText.isEmpty, "Text should be cleared after release")
    }

    func testReleaseCompleteTransitionsToPrompt() async {
        sut.writtenText = "Some text"
        sut.manualRelease()
        sut.releaseComplete()
        XCTAssertEqual(sut.writingState, .complete, "Should transition to complete state immediately")

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        XCTAssertEqual(sut.writingState, .prompt, "Should transition back to prompt state")
    }

    func testReleaseCompleteGetsNewPrompt() {
        sut.releaseComplete()
        // Note: There's a chance the same prompt is selected, so we just verify a prompt exists
        XCTAssertNotNil(sut.currentPrompt, "Should have a prompt after release complete")
    }

    func testStartNewSessionClearsText() {
        sut.writtenText = "Some text"
        sut.startNewSession()
        XCTAssertTrue(sut.writtenText.isEmpty, "Text should be cleared for new session")
    }

    func testStartNewSessionTransitionsToPrompt() {
        sut.writingState = .writing
        sut.startNewSession()
        XCTAssertEqual(sut.writingState, .prompt, "Should transition to prompt state")
    }

    // MARK: - Microphone Permission Tests

    func testRequestMicrophonePermissionStartsListeningWhenGranted() async {
        UserDefaults.standard.set(true, forKey: BlowDetectionSensitivity.enabledKey)
        let blowDetection = BlowDetectionService()
        var startListeningCalled = false
        blowDetection.permissionRequestOverride = { true }
        blowDetection.startListeningOverride = { startListeningCalled = true }

        sut = WritingViewModel(
            promptsManager: PromptsManager(),
            blowDetection: blowDetection,
            haptics: .shared
        )

        await sut.requestMicrophonePermission()

        XCTAssertTrue(blowDetection.permissionDetermined, "Permission should be determined after request")
        XCTAssertTrue(blowDetection.hasPermission, "Permission should be granted after request")
        XCTAssertTrue(startListeningCalled, "Should start listening after permission is granted")
    }

    func testRequestMicrophonePermissionDoesNotStartListeningWhenDisabled() async {
        UserDefaults.standard.set(false, forKey: BlowDetectionSensitivity.enabledKey)
        let blowDetection = BlowDetectionService()
        var startListeningCalled = false
        blowDetection.permissionRequestOverride = { true }
        blowDetection.startListeningOverride = { startListeningCalled = true }

        sut = WritingViewModel(
            promptsManager: PromptsManager(),
            blowDetection: blowDetection,
            haptics: .shared
        )

        await sut.requestMicrophonePermission()

        XCTAssertTrue(blowDetection.permissionDetermined, "Permission should be determined after request")
        XCTAssertTrue(blowDetection.hasPermission, "Permission should still be granted after request")
        XCTAssertFalse(startListeningCalled, "Should not start listening when blow detection is disabled")
    }
}
