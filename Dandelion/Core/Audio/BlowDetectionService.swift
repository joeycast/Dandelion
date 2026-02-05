//
//  BlowDetectionService.swift
//  Dandelion
//
//  Detects when user blows into the microphone to trigger release
//  Supported on iOS, iPadOS, and macOS
//

import AVFoundation
import Accelerate

#if os(macOS)
import AVFAudio
#endif

/// Service that detects blowing into the microphone using frequency analysis
/// Blowing has distinct acoustic characteristics:
/// - Dominated by low frequencies (wind noise below 500Hz)
/// - Flat, noise-like spectrum (unlike speech with harmonic peaks)
/// - High zero-crossing rate (characteristic of noise)
enum BlowDetectionSensitivity {
    static let settingsKey = "blowSensitivity"
    static let enabledKey = "blowDetectionEnabled"
    static let minValue: Double = 0.8
    static let maxValue: Double = 1.2
    static let step: Double = 0.1
    static let defaultValue: Double = 1.0
    static let maxIndex: Int = 4

    static func clamped(_ value: Double) -> Double {
        min(max(value, minValue), maxValue)
    }

    static func snapped(_ value: Double) -> Double {
        let clampedValue = clamped(value)
        let index = (clampedValue - minValue) / step
        let roundedIndex = (index).rounded()
        return minValue + (roundedIndex * step)
    }

    static func ensureDefaultExists() {
        if UserDefaults.standard.object(forKey: settingsKey) == nil {
            UserDefaults.standard.set(defaultValue, forKey: settingsKey)
        }
        if UserDefaults.standard.object(forKey: enabledKey) == nil {
            UserDefaults.standard.set(true, forKey: enabledKey)
        }
    }

    static func presetIndex(for value: Double) -> Int {
        let snappedValue = snapped(value)
        let rawIndex = (snappedValue - minValue) / step
        let roundedIndex = Int(rawIndex.rounded())
        return min(max(roundedIndex, 0), maxIndex)
    }

    static func value(for index: Int) -> Double {
        let clampedIndex = min(max(index, 0), maxIndex)
        return minValue + (Double(clampedIndex) * step)
    }

    static func label(for value: Double) -> String {
        let index = presetIndex(for: value)
        switch index {
        case 0: return "Lowest"
        case 1: return "Low"
        case 2: return "Default"
        case 3: return "High"
        default: return "Highest"
        }
    }

    static func duration(for value: Double) -> TimeInterval {
        let index = presetIndex(for: value)
        switch index {
        case 0: return 0.5
        case 1: return 0.45
        case 2: return 0.4
        case 3: return 0.35
        default: return 0.3
        }
    }

    static func frames(for value: Double) -> Int {
        let index = presetIndex(for: value)
        switch index {
        case 0: return 4
        case 1: return 3
        case 2: return 3
        case 3: return 2
        default: return 2
        }
    }

    static func currentValue() -> Double {
        ensureDefaultExists()
        return snapped(UserDefaults.standard.double(forKey: settingsKey))
    }

    static func isEnabled() -> Bool {
        ensureDefaultExists()
        return UserDefaults.standard.bool(forKey: enabledKey)
    }
}

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

    /// Progress toward a confirmed blow (0-1)
    private(set) var blowProgress: Float = 0

    /// Whether a blow is currently being detected
    private(set) var isBlowing = false

    /// Whether blow detection is enabled in settings
    private(set) var isEnabled = BlowDetectionSensitivity.isEnabled()

    /// Whether blow detection is available on this platform
    var isAvailable: Bool {
        return true
    }

    #if DEBUG
    /// Overrides permission request for tests.
    @ObservationIgnored var permissionRequestOverride: (() async -> Bool)?
    /// Overrides startListening for tests.
    @ObservationIgnored var startListeningOverride: (() -> Void)?
    /// Overrides the current time for tests.
    @ObservationIgnored var nowProvider: (() -> Date) = Date.init
    #endif

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
    private var sampleRate: Double = 44100

    // FFT setup
    private var fftSetup: vDSP_DFT_Setup?
    private let fftSize: Int = 1024

    /// Minimum overall level to consider (filters out silence)
    private let minimumLevel: Float = 0.05

    /// How much low-frequency energy must dominate for it to be a blow
    /// Higher = more strict (fewer false positives from speech)
    private let lowFrequencyDominanceRatio: Float = 3.5

    /// How long (in seconds) the blow must be sustained
    private var requiredBlowDuration: TimeInterval {
        BlowDetectionSensitivity.duration(for: sensitivity)
    }

    /// Number of consecutive "blow-like" frames required before triggering
    /// This prevents single words from flashing the indicator
    private var requiredConsecutiveFrames: Int {
        BlowDetectionSensitivity.frames(for: sensitivity)
    }

    /// Counter for consecutive blow-like frames
    private var consecutiveBlowFrames: Int = 0

    /// Timer tracking tentative blow duration (before confirmation)
    private var blowCandidateStartTime: Date?

    /// Timer tracking blow duration
    private var blowStartTime: Date?

    /// Whether blow threshold has been met
    private var blowThresholdMet = false
    private var sensitivity: Double = BlowDetectionSensitivity.currentValue()
    private var sensitivityObserver: NSObjectProtocol?

    // MARK: - Initialization

    init() {
        BlowDetectionSensitivity.ensureDefaultExists()
        // Create FFT setup for frequency analysis
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            .FORWARD
        )

        sensitivityObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.sensitivity = BlowDetectionSensitivity.currentValue()
            let enabled = BlowDetectionSensitivity.isEnabled()
            if self.isEnabled != enabled {
                self.isEnabled = enabled
                if !enabled {
                    self.stopListening()
                }
            }
        }
    }

    deinit {
        stopListening()
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
        if let sensitivityObserver {
            NotificationCenter.default.removeObserver(sensitivityObserver)
        }
    }

    // MARK: - Permission

    /// Request microphone permission
    func requestPermission() async -> Bool {
        #if DEBUG
        if let permissionRequestOverride {
            let granted = await permissionRequestOverride()
            hasPermission = granted
            permissionDetermined = true
            return granted
        }
        #endif
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
        #if DEBUG
        if let startListeningOverride {
            startListeningOverride()
            isListening = true
            return
        }
        #endif
        guard isEnabled, hasPermission, !isListening else { return }

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

            sampleRate = format.sampleRate

            // Install tap to monitor audio levels
            inputNode.installTap(onBus: 0, bufferSize: UInt32(fftSize), format: format) { [weak self] buffer, _ in
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
        consecutiveBlowFrames = 0
        blowCandidateStartTime = nil
        blowProgress = 0
    }

    // MARK: - Audio Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        guard let fftSetup = fftSetup else { return }

        let frameLength = Int(buffer.frameLength)
        guard frameLength >= fftSize else { return }

        // Calculate overall RMS level
        var rms: Float = 0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(fftSize))
        let normalizedLevel = min(rms * 5, 1.0)

        // Skip frequency analysis if too quiet
        guard rms > minimumLevel else {
            DispatchQueue.main.async { [weak self] in
                self?.updateBlowState(isBlowDetected: false, level: normalizedLevel)
            }
            return
        }

        // Prepare data for FFT
        var realInput = [Float](repeating: 0, count: fftSize)
        var imagInput = [Float](repeating: 0, count: fftSize)
        var realOutput = [Float](repeating: 0, count: fftSize)
        var imagOutput = [Float](repeating: 0, count: fftSize)

        // Copy audio data to real input
        for i in 0..<fftSize {
            realInput[i] = channelData[i]
        }

        // Perform FFT
        vDSP_DFT_Execute(fftSetup, &realInput, &imagInput, &realOutput, &imagOutput)

        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        for i in 0..<(fftSize / 2) {
            let real = realOutput[i]
            let imag = imagOutput[i]
            magnitudes[i] = sqrt(real * real + imag * imag)
        }

        // Calculate frequency resolution
        let frequencyResolution = Float(sampleRate) / Float(fftSize)

        // Define frequency bands
        // Low band: 50-500 Hz (where blow noise dominates)
        // High band: 1000-4000 Hz (where speech formants live)
        let lowBandStart = Int(50 / frequencyResolution)
        let lowBandEnd = Int(500 / frequencyResolution)
        let highBandStart = Int(1000 / frequencyResolution)
        let highBandEnd = min(Int(4000 / frequencyResolution), fftSize / 2 - 1)

        // Calculate energy in each band
        var lowBandEnergy: Float = 0
        var highBandEnergy: Float = 0

        for i in lowBandStart..<lowBandEnd {
            lowBandEnergy += magnitudes[i] * magnitudes[i]
        }
        lowBandEnergy /= Float(lowBandEnd - lowBandStart)

        for i in highBandStart..<highBandEnd {
            highBandEnergy += magnitudes[i] * magnitudes[i]
        }
        highBandEnergy /= Float(highBandEnd - highBandStart)

        // Blow detection: low frequencies must strongly dominate
        // Add small epsilon to avoid division by zero
        let ratio = lowBandEnergy / (highBandEnergy + 0.0001)
        let isBlowLike = ratio > lowFrequencyDominanceRatio

        DispatchQueue.main.async { [weak self] in
            self?.updateBlowState(isBlowDetected: isBlowLike, level: normalizedLevel)
        }
    }

    private func updateBlowState(isBlowDetected: Bool, level: Float) {
        currentLevel = level

        // Track consecutive blow-like frames to filter out spurious detections
        if isBlowDetected {
            consecutiveBlowFrames += 1
            if blowCandidateStartTime == nil {
#if DEBUG
                blowCandidateStartTime = nowProvider()
#else
                blowCandidateStartTime = Date()
#endif
            }
        } else {
            consecutiveBlowFrames = 0
            blowCandidateStartTime = nil
        }

        let frameProgress = min(Float(consecutiveBlowFrames) / Float(requiredConsecutiveFrames), 1)
        var durationProgress: Float = 0
        if let candidateStart = blowCandidateStartTime {
#if DEBUG
            let duration = nowProvider().timeIntervalSince(candidateStart)
#else
            let duration = Date().timeIntervalSince(candidateStart)
#endif
            durationProgress = min(Float(duration / requiredBlowDuration), 1)
        }

        blowProgress = isBlowDetected ? min(frameProgress, durationProgress) : 0

        // Only consider it a real blow after enough consecutive frames
        let isConfirmedBlow = consecutiveBlowFrames >= requiredConsecutiveFrames

        let wasBlowing = isBlowing
        isBlowing = isConfirmedBlow

        if isBlowing {
            if !wasBlowing {
                // Blow just started (confirmed)
                #if DEBUG
                blowStartTime = nowProvider()
                #else
                blowStartTime = Date()
                #endif
                blowThresholdMet = false
                onBlowStarted?()
            } else if let startTime = blowStartTime {
                // Check if blow has been sustained long enough
                #if DEBUG
                let duration = nowProvider().timeIntervalSince(startTime)
                #else
                let duration = Date().timeIntervalSince(startTime)
                #endif
                if duration >= requiredBlowDuration && !blowThresholdMet {
                    blowThresholdMet = true
                    blowProgress = 1
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
            if !isBlowDetected {
                blowProgress = 0
            }
        }
    }

#if DEBUG
    func debugUpdateBlowState(isBlowDetected: Bool, level: Float) {
        updateBlowState(isBlowDetected: isBlowDetected, level: level)
    }
#endif
}
