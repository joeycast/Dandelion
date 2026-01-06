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

    /// Detached seed timestamps for the dandelion bloom
    var detachedSeedTimes: [Int: TimeInterval] = [:]

    /// Whether to show permission request
    var showPermissionRequest: Bool = false

    /// Error message if something goes wrong
    var errorMessage: String?

    // MARK: - Dependencies

    private let promptsManager: PromptsManager
    let blowDetection: BlowDetectionService
    let dandelionSeedCount: Int = 140
    private var detachmentOrder: [Int] = []
    private var detachmentCursor: Int = 0
    private var detachmentTask: Task<Void, Never>?

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

        prepareDetachmentOrder()
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
        resetDandelionDetachment()

        withAnimation(DandelionAnimation.slow) {
            writingState = .prompt
        }
    }

    /// Start a new writing session
    func startNewSession() {
        writtenText = ""
        currentPrompt = promptsManager.randomPrompt()
        currentReleaseMessage = promptsManager.randomReleaseMessage()
        resetDandelionDetachment()

        withAnimation(DandelionAnimation.gentle) {
            writingState = .prompt
        }
    }

    // MARK: - Private Methods

    private func setupBlowDetection() {
        blowDetection.onBlowDetected = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                guard self.writingState == .writing else { return }
                if self.canRelease {
                    self.triggerRelease()
                }
            }
        }

        blowDetection.onBlowStarted = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                guard self.writingState == .writing else { return }
                self.showBlowIndicator = true
            }
        }

        blowDetection.onBlowEnded = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.showBlowIndicator = false
                self.stopDetachingSeeds()
            }
        }
    }

    private func triggerRelease() {
        // Stop listening during animation
        blowDetection.stopListening()
        showBlowIndicator = false
        stopDetachingSeeds()

        withAnimation(DandelionAnimation.gentle) {
            writingState = .releasing
        }
    }

    private func prepareDetachmentOrder() {
        detachmentOrder = Array(0..<dandelionSeedCount).shuffled()
        detachmentCursor = 0
    }

    private func resetDandelionDetachment() {
        detachedSeedTimes = [:]
        prepareDetachmentOrder()
        stopDetachingSeeds()
    }

    private func startDetachingSeeds() {
        guard detachmentTask == nil else { return }

        detachmentTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await MainActor.run {
                    self.detachSeeds(count: 2)
                }
                try? await Task.sleep(nanoseconds: 140_000_000)
            }
        }
    }

    private func stopDetachingSeeds() {
        detachmentTask?.cancel()
        detachmentTask = nil
    }

    @MainActor
    private func detachSeeds(count: Int) {
        guard detachmentCursor < detachmentOrder.count else { return }
        var updated = detachedSeedTimes
        let timestamp = Date().timeIntervalSinceReferenceDate
        for _ in 0..<count {
            guard detachmentCursor < detachmentOrder.count else { break }
            let id = detachmentOrder[detachmentCursor]
            detachmentCursor += 1
            updated[id] = timestamp
        }
        detachedSeedTimes = updated
    }

    @MainActor
    private func detachAllSeeds() {
        let timestamp = Date().timeIntervalSinceReferenceDate
        var updated: [Int: TimeInterval] = [:]
        updated.reserveCapacity(dandelionSeedCount)
        for id in 0..<dandelionSeedCount {
            updated[id] = timestamp
        }
        detachedSeedTimes = updated
        detachmentCursor = detachmentOrder.count
        stopDetachingSeeds()
    }

    @MainActor
    func beginReleaseDetachment() {
        guard detachedSeedTimes.count < dandelionSeedCount else { return }
        detachAllSeeds()
    }
}
