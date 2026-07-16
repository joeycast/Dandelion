//
//  AudioSessionCoordinator.swift
//  Dandelion
//
//  Single owner of AVAudioSession category/activation so ambient playback
//  and blow detection do not overwrite each other.
//

import AVFoundation
import Foundation

/// Coordinates shared `AVAudioSession` configuration for ambient playback and
/// microphone-based blow detection. Only meaningful on iOS/iPadOS; macOS
/// audio input does not use `AVAudioSession`.
///
/// Thread-safe: blow detection may start/stop from non-main contexts (engine
/// teardown / deinit), while ambient is driven from the main actor.
enum AudioSessionCoordinator {
    private static let lock = NSLock()
    private static var ambientClients = 0
    private static var blowClients = 0

    /// Request session configuration suitable for ambient loop playback.
    /// Call when starting ambient sound (including previews).
    static func acquireAmbient() {
        lock.lock()
        ambientClients += 1
        let ambient = ambientClients
        let blow = blowClients
        lock.unlock()
        apply(ambientClients: ambient, blowClients: blow)
    }

    /// Release ambient claim. Call when ambient playback fully stops.
    static func releaseAmbient() {
        lock.lock()
        ambientClients = max(0, ambientClients - 1)
        let ambient = ambientClients
        let blow = blowClients
        lock.unlock()
        apply(ambientClients: ambient, blowClients: blow)
    }

    /// Request session configuration suitable for microphone blow detection.
    /// Call before installing the audio engine input tap.
    static func acquireBlowDetection() throws {
        lock.lock()
        blowClients += 1
        let ambient = ambientClients
        let blow = blowClients
        lock.unlock()
        try applyThrowing(ambientClients: ambient, blowClients: blow)
    }

    /// Release blow-detection claim. Call after tearing down the audio engine.
    static func releaseBlowDetection() {
        lock.lock()
        blowClients = max(0, blowClients - 1)
        let ambient = ambientClients
        let blow = blowClients
        lock.unlock()
        apply(ambientClients: ambient, blowClients: blow)
    }

    /// Snapshot of active claims (for tests).
    static func clientCountsForTesting() -> (ambient: Int, blow: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (ambientClients, blowClients)
    }

    /// Test helper: reset client counts without touching the session.
    static func resetForTesting() {
        lock.lock()
        ambientClients = 0
        blowClients = 0
        lock.unlock()
    }

    // MARK: - Private

    private static func apply(ambientClients: Int, blowClients: Int) {
        do {
            try applyThrowing(ambientClients: ambientClients, blowClients: blowClients)
        } catch {
            debugLog("AudioSessionCoordinator: failed to apply session: \(error)")
        }
    }

    private static func applyThrowing(ambientClients: Int, blowClients: Int) throws {
#if os(iOS)
        let session = AVAudioSession.sharedInstance()
        let wantsAmbient = ambientClients > 0
        let wantsBlow = blowClients > 0

        guard wantsAmbient || wantsBlow else {
            // Step down to ambient mixable category when nothing needs the session.
            try session.setCategory(.ambient, options: [.mixWithOthers])
            return
        }

        if wantsBlow {
            // playAndRecord allows mic + speaker simultaneously.
            // mixWithOthers keeps ambient AVAudioPlayer audible while listening.
            // Prefer .default mode when ambient is also active so playback is not
            // aggressively optimized away by .measurement.
            let mode: AVAudioSession.Mode = wantsAmbient ? .default : .measurement
            try session.setCategory(
                .playAndRecord,
                mode: mode,
                options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothA2DP]
            )
        } else {
            try session.setCategory(.ambient, options: [.mixWithOthers])
        }

        try session.setActive(true, options: [])
#else
        _ = ambientClients
        _ = blowClients
#endif
    }
}
