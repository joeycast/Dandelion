//
//  AmbientSoundService.swift
//  Dandelion
//
//  Simple ambient sound playback for writing sessions
//

import Foundation
import AVFoundation

enum AmbientSound: String, CaseIterable, Identifiable {
    case wind
    case rain
    case fire

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wind: return "Wind"
        case .rain: return "Rain"
        case .fire: return "Fire"
        }
    }

    var filename: String {
        switch self {
        case .wind: return "ambient_wind"
        case .rain: return "ambient_rain"
        case .fire: return "ambient_fire"
        }
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

    init() {
        if let savedSound = UserDefaults.standard.string(forKey: Keys.sound),
           let sound = AmbientSound(rawValue: savedSound) {
            selectedSound = sound
        } else {
            selectedSound = .wind
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
        fadeTask?.cancel()
        fadeTask = nil

        if player?.isPlaying == true, currentSound == selectedSound {
            return
        }
        if player?.isPlaying == true {
            stop()
        }

        guard let url = Bundle.main.url(forResource: selectedSound.filename, withExtension: "wav") else {
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
            self.currentSound = selectedSound
        } catch {
            // Ignore audio errors; ambient sound is optional.
        }
    }

    func stop() {
        fadeTask?.cancel()
        fadeTask = nil
        player?.stop()
        player = nil
        currentSound = nil
    }

    func fadeOut(duration: TimeInterval = 1.2) {
        guard let player else { return }
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
            stop()
        }
    }
}
