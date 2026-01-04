//
//  WritingViewModel.swift
//  Dandelion
//
//  ViewModel for the main writing experience
//

import SwiftUI

/// The current state of the writing flow
enum WritingState: Equatable {
    case prompt          // Showing a writing prompt
    case writing         // User is writing
    case releasing       // Animation playing
    case complete        // Post-release, ready to restart
}

@Observable
final class WritingViewModel {
    // MARK: - State

    var writingState: WritingState = .prompt
    var writtenText: String = ""
    var currentPrompt: WritingPrompt
    var currentReleaseMessage: ReleaseMessage

    /// Whether to show the blow indicator
    var showBlowIndicator: Bool = false

    /// Current blow level for visual feedback (0-1)
    var blowLevel: Float = 0

    /// Whether to show permission request
    var showPermissionRequest: Bool = false

    /// Error message if something goes wrong
    var errorMessage: String?

    // MARK: - Dependencies

    private let promptsManager: PromptsManager
    let blowDetection: BlowDetectionService

    // MARK: - Computed Properties

    var canRelease: Bool {
        !writtenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasText: Bool {
        !writtenText.isEmpty
    }

    // MARK: - Initialization

    init(
        promptsManager: PromptsManager = PromptsManager(),
        blowDetection: BlowDetectionService = BlowDetectionService()
    ) {
        self.promptsManager = promptsManager
        self.blowDetection = blowDetection
        self.currentPrompt = promptsManager.randomPrompt()
        self.currentReleaseMessage = promptsManager.randomReleaseMessage()

        setupBlowDetection()
    }

    // MARK: - Actions

    /// Start writing (transition from prompt)
    func startWriting() {
        withAnimation(DandelionAnimation.gentle) {
            writingState = .writing
        }

        // Check permission and start listening if granted
        Task {
            blowDetection.checkPermission()
            if blowDetection.hasPermission {
                blowDetection.startListening()
            }
        }
    }

    /// Request microphone permission
    func requestMicrophonePermission() async {
        let granted = await blowDetection.requestPermission()
        if granted {
            blowDetection.startListening()
        }
    }

    /// Trigger release via manual action
    func manualRelease() {
        guard canRelease else { return }
        triggerRelease()
    }

    /// Called when release animation completes
    func releaseComplete() {
        // Clear the text (it's gone forever!)
        writtenText = ""

        // Get new prompt and message for next time
        currentPrompt = promptsManager.randomPrompt()
        currentReleaseMessage = promptsManager.randomReleaseMessage()

        withAnimation(DandelionAnimation.slow) {
            writingState = .prompt
        }
    }

    /// Start a new writing session
    func startNewSession() {
        writtenText = ""
        currentPrompt = promptsManager.randomPrompt()
        currentReleaseMessage = promptsManager.randomReleaseMessage()

        withAnimation(DandelionAnimation.gentle) {
            writingState = .prompt
        }
    }

    // MARK: - Private Methods

    private func setupBlowDetection() {
        blowDetection.onBlowDetected = { [weak self] in
            guard let self = self, self.canRelease else { return }
            self.triggerRelease()
        }

        blowDetection.onBlowStarted = { [weak self] in
            self?.showBlowIndicator = true
        }

        blowDetection.onBlowEnded = { [weak self] in
            self?.showBlowIndicator = false
        }
    }

    private func triggerRelease() {
        // Stop listening during animation
        blowDetection.stopListening()
        showBlowIndicator = false

        withAnimation(DandelionAnimation.gentle) {
            writingState = .releasing
        }
    }
}
