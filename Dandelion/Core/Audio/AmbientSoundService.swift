//
//  AmbientSoundService.swift
//  Dandelion
//
//  Simple ambient sound playback for writing sessions
//

import Foundation
import AVFoundation

enum AmbientSound: String, CaseIterable, Identifiable {
    case rain
    case fireplace
    case ocean
    case stream
    case birds

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rain: return "Rain"
        case .fireplace: return "Fireplace"
        case .ocean: return "Ocean Waves"
        case .stream: return "Stream"
        case .birds: return "Forest Birds"
        }
    }

    var filename: String {
        switch self {
        case .rain: return "ambient_rain"
        case .fireplace: return "ambient_fireplace"
        case .ocean: return "ambient_ocean"
        case .stream: return "ambient_stream"
        case .birds: return "ambient_birds"
        }
    }

    var fileExtension: String {
        "m4a"
    }
}

@MainActor
@Observable
final class AmbientSoundService {
    private enum Keys {
        static let enabled = "com.dandelion.ambient.enabled"
        static let sound = "com.dandelion.ambient.sound"
        static let volume = "com.dandelion.ambient.volume"
    }

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.enabled) }
    }

    var selectedSound: AmbientSound {
        didSet { UserDefaults.standard.set(selectedSound.rawValue, forKey: Keys.sound) }
    }

    var volume: Float {
        didSet {
            UserDefaults.standard.set(volume, forKey: Keys.volume)
            player?.volume = volume
        }
    }

    private var player: AVAudioPlayer?
    private var fadeTask: Task<Void, Never>?
    private var currentSound: AmbientSound?
    private var previewTask: Task<Void, Never>?
    private(set) var isPreviewing = false
    private(set) var isFadingOut = false

    init() {
        if let savedSound = UserDefaults.standard.string(forKey: Keys.sound) {
            if let sound = AmbientSound(rawValue: savedSound) {
                selectedSound = sound
            } else if savedSound == "wind" {
                selectedSound = .birds
            } else if savedSound == "fire" {
                selectedSound = .fireplace
            } else {
                selectedSound = .rain
            }
        } else {
            selectedSound = .rain
        }

        if UserDefaults.standard.object(forKey: Keys.enabled) != nil {
            isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)
        } else {
            isEnabled = false
        }

        let savedVolume = UserDefaults.standard.object(forKey: Keys.volume) as? Float
        volume = savedVolume ?? 0.6
    }

    func start() {
        guard isEnabled else { return }
        isFadingOut = false
        isPreviewing = false
        debugLog("AmbientSoundService: start")
        previewTask?.cancel()
        previewTask = nil
        fadeTask?.cancel()
        fadeTask = nil

        play(sound: selectedSound, force: false)
    }

    func previewSelectedSound(duration: TimeInterval = 5) {
        previewTask?.cancel()
        previewTask = nil
        fadeTask?.cancel()
        fadeTask = nil
        isFadingOut = false
        isPreviewing = true
        debugLog("AmbientSoundService: preview start")
        let sound = selectedSound
        stopPlayback(resetPreview: false)
        play(sound: sound, force: true)
        previewTask = Task { @MainActor in
            let fadeDuration = min(0.8, duration)
            let holdDuration = max(0, duration - fadeDuration)
            if holdDuration > 0 {
                try? await Task.sleep(nanoseconds: UInt64(holdDuration * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            guard currentSound == sound else { return }
            fadeOut(duration: fadeDuration)
        }
    }

    private func play(sound: AmbientSound, force: Bool) {
        if !force, !isEnabled {
            return
        }

        if player?.isPlaying == true, currentSound == sound {
            return
        }
        if player?.isPlaying == true {
            stopPlayback(resetPreview: false)
        }

        guard let url = Bundle.main.url(forResource: sound.filename,
                                        withExtension: sound.fileExtension) else {
            debugLog("AmbientSoundService: missing audio file \(sound.filename).\(sound.fileExtension)")
            return
        }

        do {
            #if os(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.ambient, options: [.mixWithOthers])
            try audioSession.setActive(true)
            #endif

            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = volume
            player.prepareToPlay()
            player.play()
            self.player = player
            self.currentSound = sound
            debugLog("AmbientSoundService: playing \(sound.filename).\(sound.fileExtension)")
        } catch {
            debugLog("AmbientSoundService: failed to play \(sound.filename).\(sound.fileExtension): \(error)")
            // Ignore audio errors; ambient sound is optional.
        }
    }

    func stop() {
        debugLog("AmbientSoundService: stop")
        stopPlayback(resetPreview: true)
    }

    private func stopPlayback(resetPreview: Bool) {
        fadeTask?.cancel()
        fadeTask = nil
        previewTask?.cancel()
        previewTask = nil
        isFadingOut = false
        if resetPreview {
            isPreviewing = false
        }
        player?.stop()
        player = nil
        currentSound = nil
    }

    func fadeOut(duration: TimeInterval = 1.2) {
        guard let player else { return }
        isFadingOut = true
        debugLog("AmbientSoundService: fadeOut start duration=\(duration)")
        fadeTask?.cancel()
        fadeTask = Task { @MainActor in
            let steps = 12
            let stepDuration = duration / Double(steps)
            let startVolume = player.volume
            for step in 1...steps {
                guard !Task.isCancelled else { return }
                let progress = Float(step) / Float(steps)
                player.volume = max(0, startVolume * (1 - progress))
                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
            }
            debugLog("AmbientSoundService: fadeOut complete")
            stop()
        }
    }
}
