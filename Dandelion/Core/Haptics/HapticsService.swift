//
//  HapticsService.swift
//  Dandelion
//
//  Simple haptics patterns for key interactions
//

import UIKit

@MainActor
final class HapticsService {
    static let shared = HapticsService()

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let soft = UIImpactFeedbackGenerator(style: .soft)

    func tap() {
        light.prepare()
        light.impactOccurred(intensity: 0.7)
    }

    func playReleasePattern() async {
        // Seeds scattering from a dandelion:
        // - Rapid burst at the start (many seeds catching the wind)
        // - Gradually slows as remaining seeds drift away
        // - Intensity fades as seeds disperse into the distance

        let intensities: [CGFloat] = [
            // Initial burst - strong and rapid
            0.85, 0.8, 0.75, 0.7, 0.65,
            // Middle dispersal - moderate pace
            0.55, 0.5, 0.45, 0.4, 0.35,
            // Final drift - slow and fading
            0.3, 0.25, 0.2, 0.15, 0.1
        ]

        let delays: [TimeInterval] = [
            // Rapid burst (50-70ms)
            0.0, 0.05, 0.055, 0.06, 0.07,
            // Moderate spacing (100-150ms)
            0.1, 0.12, 0.13, 0.14, 0.15,
            // Slow drift (200-350ms)
            0.2, 0.25, 0.3, 0.32, 0.35
        ]

        for index in intensities.indices {
            if Task.isCancelled { return }
            soft.prepare()
            soft.impactOccurred(intensity: intensities[index])
            let delay = delays[index]
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    func playRegrowthPattern() async {
        // Seeds returning to the dandelion:
        // - Slow and tentative at first (first seeds finding their way back)
        // - Builds momentum as more seeds return
        // - Ends with a gentle flourish of fullness

        let intensities: [CGFloat] = [
            // First seeds - tentative, soft
            0.15, 0.18, 0.2, 0.22,
            // Building momentum
            0.28, 0.32, 0.36, 0.4, 0.44,
            // Growing stronger
            0.48, 0.52, 0.56, 0.6,
            // Final flourish - full bloom restored
            0.65, 0.7, 0.75, 0.8
        ]

        let delays: [TimeInterval] = [
            // Slow start - seeds drifting back (350-280ms)
            0.0, 0.35, 0.32, 0.3,
            // Building momentum (250-180ms)
            0.28, 0.25, 0.22, 0.2, 0.18,
            // Accelerating (160-120ms)
            0.16, 0.14, 0.13, 0.12,
            // Quick finish (100-60ms)
            0.1, 0.08, 0.07, 0.06
        ]

        for index in intensities.indices {
            if Task.isCancelled { return }
            light.prepare()
            light.impactOccurred(intensity: intensities[index])
            let delay = delays[index]
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
}
