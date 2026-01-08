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
        let intensities: [CGFloat] = [0.9, 0.75, 0.6, 0.5, 0.4, 0.35, 0.3]
        let delays: [TimeInterval] = [0.0, 0.08, 0.1, 0.12, 0.15, 0.18, 0.22]

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
        let intensities: [CGFloat] = [0.3, 0.4, 0.5, 0.65, 0.8]
        let delays: [TimeInterval] = [0.18, 0.16, 0.14, 0.12, 0.1]

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
