//
//  BlowDetectionService.swift
//  Dandelion
//
//  Detects when user blows into the microphone to trigger release
//  Supported on iOS, iPadOS, and macOS
//

import AVFoundation

#if os(macOS)
import AVFAudio
#endif

/// Service that detects blowing into the microphone
@Observable
final class BlowDetectionService {
    // MARK: - Public State

    /// Whether the service is currently listening
    private(set) var isListening = false

    /// Whether microphone permission has been granted
    private(set) var hasPermission = false

    /// Whether permission has been determined (asked)
    private(set) var permissionDetermined = false

    /// Current detected audio level (0-1)
    private(set) var currentLevel: Float = 0

    /// Whether a blow is currently being detected
    private(set) var isBlowing = false

    /// Whether blow detection is available on this platform
    var isAvailable: Bool {
        return true
    }

    // MARK: - Callbacks

    /// Called when a complete blow is detected (sustained airflow)
    var onBlowDetected: (() -> Void)?

    /// Called when blow starts
    var onBlowStarted: (() -> Void)?

    /// Called when blow ends without completing
    var onBlowEnded: (() -> Void)?

    // MARK: - Private Properties

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    /// Threshold for detecting blow vs ambient noise
    private let blowThreshold: Float = 0.15

    /// How long (in seconds) the blow must be sustained
    private let requiredBlowDuration: TimeInterval = 0.5

    /// Timer tracking blow duration
    private var blowStartTime: Date?

    /// Whether blow threshold has been met
    private var blowThresholdMet = false

    // MARK: - Initialization

    init() {}

    deinit {
        stopListening()
    }

    // MARK: - Permission

    /// Request microphone permission
    func requestPermission() async -> Bool {
        #if os(iOS)
        let status = AVAudioApplication.shared.recordPermission

        switch status {
        case .granted:
            hasPermission = true
            permissionDetermined = true
            return true

        case .denied:
            hasPermission = false
            permissionDetermined = true
            return false

        case .undetermined:
            let granted = await AVAudioApplication.requestRecordPermission()
            hasPermission = granted
            permissionDetermined = true
            return granted

        @unknown default:
            return false
        }
        #elseif os(macOS)
        // macOS uses AVCaptureDevice for microphone permission
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            hasPermission = true
            permissionDetermined = true
            return true

        case .denied, .restricted:
            hasPermission = false
            permissionDetermined = true
            return false

        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            hasPermission = granted
            permissionDetermined = true
            return granted

        @unknown default:
            return false
        }
        #endif
    }

    /// Check current permission status without prompting
    func checkPermission() {
        #if os(iOS)
        let status = AVAudioApplication.shared.recordPermission
        permissionDetermined = status != .undetermined
        hasPermission = status == .granted
        #elseif os(macOS)
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        permissionDetermined = status != .notDetermined
        hasPermission = status == .authorized
        #endif
    }

    // MARK: - Listening

    /// Start listening for blows
    func startListening() {
        guard hasPermission, !isListening else { return }

        do {
            #if os(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try audioSession.setActive(true)
            #endif

            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else { return }

            inputNode = audioEngine.inputNode
            guard let inputNode = inputNode else { return }

            let format = inputNode.outputFormat(forBus: 0)

            // Ensure format is valid
            guard format.sampleRate > 0 else {
                debugLog("Invalid audio format")
                return
            }

            // Install tap to monitor audio levels
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer)
            }

            try audioEngine.start()
            isListening = true

        } catch {
            debugLog("Failed to start audio engine: \(error)")
            isListening = false
        }
    }

    /// Stop listening
    func stopListening() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil

        isListening = false
        isBlowing = false
        currentLevel = 0
        blowStartTime = nil
        blowThresholdMet = false
    }

    // MARK: - Audio Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        // Calculate RMS (root mean square) for audio level
        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))

        // Normalize to 0-1 range (with some headroom)
        let normalizedLevel = min(rms * 5, 1.0)

        DispatchQueue.main.async { [weak self] in
            self?.updateLevel(normalizedLevel)
        }
    }

    private func updateLevel(_ level: Float) {
        currentLevel = level

        let wasBlowing = isBlowing
        isBlowing = level > blowThreshold

        if isBlowing {
            if !wasBlowing {
                // Blow just started
                blowStartTime = Date()
                blowThresholdMet = false
                onBlowStarted?()
            } else if let startTime = blowStartTime {
                // Check if blow has been sustained long enough
                let duration = Date().timeIntervalSince(startTime)
                if duration >= requiredBlowDuration && !blowThresholdMet {
                    blowThresholdMet = true
                    onBlowDetected?()
                }
            }
        } else {
            if wasBlowing {
                // Blow ended
                if !blowThresholdMet {
                    onBlowEnded?()
                }
                blowStartTime = nil
                blowThresholdMet = false
            }
        }
    }
}
