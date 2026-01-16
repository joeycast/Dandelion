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

@MainActor
@Observable
final class WritingViewModel {
    // MARK: - State

    var writingState: WritingState = .prompt
    var writtenText: String = ""
    var currentPrompt: WritingPrompt
    var currentReleaseMessage: ReleaseMessage
    var isDandelionReturning: Bool = false

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
    private let haptics: HapticsService

    /// Callback invoked when a release is triggered, passing word count
    /// Set this from the view to record releases to history
    var onReleaseTriggered: ((Int) -> Void)?
    let dandelionSeedCount: Int = 140
    private var detachmentOrder: [Int] = []
    private var detachmentCursor: Int = 0
    private var detachmentTask: Task<Void, Never>?
    private var releaseTask: Task<Void, Never>?
    private var releaseHapticsTask: Task<Void, Never>?
    private let releaseDuration: TimeInterval = 9.0  // After message fully fades
    private var activeReleaseID: UUID?
    private var seedRestoreTask: Task<Void, Never>?
    private var regrowHapticsTask: Task<Void, Never>?
    private(set) var seedRestoreStartTime: TimeInterval?
    let seedRestoreDuration: TimeInterval = 8.0
    private let dandelionReturnDuration: TimeInterval = 1.5  // Position animation before regrowth begins
    static let debugReleaseFlow = true

    // MARK: - Computed Properties

    var canRelease: Bool {
        !writtenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasText: Bool {
        !writtenText.isEmpty
    }

    // MARK: - Initialization

    convenience init() {
        self.init(
            promptsManager: PromptsManager(),
            blowDetection: BlowDetectionService(),
            haptics: .shared
        )
    }

    init(
        promptsManager: PromptsManager,
        blowDetection: BlowDetectionService,
        haptics: HapticsService
    ) {
        self.promptsManager = promptsManager
        self.blowDetection = blowDetection
        self.haptics = haptics
        self.currentPrompt = promptsManager.randomPrompt()
        self.currentReleaseMessage = promptsManager.randomReleaseMessage()

        prepareDetachmentOrder()
        setupBlowDetection()
    }

    // MARK: - Actions

    /// Start writing (transition from prompt)
    func startWriting() {
        if Self.debugReleaseFlow {
            debugLog("[ReleaseFlow] startWriting")
        }
        haptics.tap()
        isDandelionReturning = false
        withAnimation(DandelionAnimation.slow) {
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
        if Self.debugReleaseFlow {
            debugLog("[ReleaseFlow] manualRelease")
        }
        triggerRelease()
    }

    /// Called when release animation completes
    func releaseComplete() {
        releaseTask?.cancel()
        releaseTask = nil
        releaseHapticsTask?.cancel()
        releaseHapticsTask = nil
        activeReleaseID = nil
        if Self.debugReleaseFlow {
            debugLog("[ReleaseFlow] releaseComplete")
        }

        // Clear the text (it's gone forever!)
        writtenText = ""
        // Change state first so ReleaseMessageView disappears
        withAnimation(.easeInOut(duration: dandelionReturnDuration)) {
            isDandelionReturning = false
            writingState = .prompt
        }

        // Then get new prompt and message for next time
        currentPrompt = promptsManager.randomPrompt()
        currentReleaseMessage = promptsManager.randomReleaseMessage()
        beginSeedRestore()
    }

    /// Start a new writing session
    func startNewSession() {
        releaseTask?.cancel()
        releaseTask = nil
        releaseHapticsTask?.cancel()
        releaseHapticsTask = nil
        regrowHapticsTask?.cancel()
        regrowHapticsTask = nil
        activeReleaseID = nil
        if Self.debugReleaseFlow {
            debugLog("[ReleaseFlow] startNewSession")
        }

        writtenText = ""
        // Change state first so ReleaseMessageView disappears
        withAnimation(.easeInOut(duration: dandelionReturnDuration)) {
            isDandelionReturning = false
            writingState = .prompt
        }

        // Then get new prompt and message for next time
        currentPrompt = promptsManager.randomPrompt()
        currentReleaseMessage = promptsManager.randomReleaseMessage()
        beginSeedRestore()
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
        cancelSeedRestore()
        regrowHapticsTask?.cancel()
        regrowHapticsTask = nil
        if Self.debugReleaseFlow {
            debugLog("[ReleaseFlow] triggerRelease")
        }

        // Record the release BEFORE clearing text (captures word count)
        let wordCount = WordCounter.count(writtenText)
        onReleaseTriggered?(wordCount)

        isDandelionReturning = false
        writingState = .releasing

        releaseTask?.cancel()
        releaseHapticsTask?.cancel()
        let releaseID = UUID()
        activeReleaseID = releaseID
        if Self.debugReleaseFlow {
            debugLog("[ReleaseFlow] scheduleReleaseComplete id=\(releaseID)")
        }
        releaseHapticsTask = Task { [haptics = self.haptics] in
            await haptics.playReleasePattern()
        }
        releaseTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.releaseDuration * 1_000_000_000))
            await MainActor.run {
                guard self.activeReleaseID == releaseID else {
                    if Self.debugReleaseFlow {
                        debugLog("[ReleaseFlow] releaseComplete skipped id=\(releaseID)")
                    }
                    return
                }
                self.releaseComplete()
            }
        }
    }

    private func prepareDetachmentOrder() {
        detachmentOrder = Array(0..<dandelionSeedCount).shuffled()
        detachmentCursor = 0
    }

    private func cancelSeedRestore() {
        seedRestoreTask?.cancel()
        seedRestoreTask = nil
        seedRestoreStartTime = nil
    }

    private func beginSeedRestore() {
        // Skip if restore is already in progress (started by startSeedRestoreNow)
        guard seedRestoreStartTime == nil else { return }

        guard !detachedSeedTimes.isEmpty else {
            prepareDetachmentOrder()
            stopDetachingSeeds()
            return
        }

        cancelSeedRestore()

        // Delay regrowth until after dandelion returns to default position
        let returnDelay = dandelionReturnDuration
        let restoreDuration = seedRestoreDuration
        seedRestoreTask = Task { [weak self] in
            // Wait for position animation to complete
            try? await Task.sleep(nanoseconds: UInt64(returnDelay * 1_000_000_000))

            // Now start the regrowth animation
            await MainActor.run {
                guard let self else { return }
                self.seedRestoreStartTime = Date().timeIntervalSinceReferenceDate
                self.regrowHapticsTask?.cancel()
                self.regrowHapticsTask = Task { [haptics = self.haptics] in
                    await haptics.playRegrowthPattern()
                }
            }

            // Wait for regrowth to complete
            try? await Task.sleep(nanoseconds: UInt64(restoreDuration * 1_000_000_000))
            await MainActor.run {
                guard let self else { return }
                self.detachedSeedTimes = [:]
                self.seedRestoreStartTime = nil
                self.prepareDetachmentOrder()
                self.stopDetachingSeeds()
            }
        }
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
        if Self.debugReleaseFlow {
            debugLog("[ReleaseFlow] beginReleaseDetachment")
        }
        detachAllSeeds()
    }

    func startDandelionReturn() {
        guard !isDandelionReturning else { return }
        if Self.debugReleaseFlow {
            debugLog("[ReleaseFlow] startDandelionReturn")
        }
        withAnimation(.easeInOut(duration: dandelionReturnDuration)) {
            isDandelionReturning = true
        }
    }

    /// Start the seed restore animation immediately (called when release message starts fading)
    func startSeedRestoreNow() {
        guard seedRestoreStartTime == nil else { return }
        guard !detachedSeedTimes.isEmpty else { return }
        if Self.debugReleaseFlow {
            debugLog("[ReleaseFlow] startSeedRestoreNow")
        }

        cancelSeedRestore()

        let restoreDuration = seedRestoreDuration
        seedRestoreStartTime = Date().timeIntervalSinceReferenceDate
        regrowHapticsTask?.cancel()
        regrowHapticsTask = Task { [haptics] in
            await haptics.playRegrowthPattern()
        }

        seedRestoreTask = Task { [weak self] in
            // Wait for regrowth animation to complete
            try? await Task.sleep(nanoseconds: UInt64(restoreDuration * 1_000_000_000))
            await MainActor.run {
                guard let self else { return }
                self.detachedSeedTimes = [:]
                self.seedRestoreStartTime = nil
                self.prepareDetachmentOrder()
                self.stopDetachingSeeds()
            }
        }
    }
}
