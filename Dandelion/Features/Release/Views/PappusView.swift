//
//  PappusView.swift
//  Dandelion
//
//  View for a single floating pappus (dandelion seed with text)
//

import SwiftUI

/// A single floating pappus view
struct PappusView: View {
    let pappus: Pappus
    let isAnimating: Bool
    @Environment(AppearanceManager.self) private var appearance

    @State private var opacity: Double = 1.0

    var body: some View {
        let theme = appearance.theme
        Text(pappus.text)
            .font(.dandelionWriting)
            .foregroundColor(theme.text)
            .opacity(opacity)
            .position(isAnimating ? pappus.endPosition : pappus.startPosition)
            .rotationEffect(.degrees(isAnimating ? pappus.endRotation : pappus.startRotation))
            .animation(
                .easeInOut(duration: pappus.duration)
                .delay(pappus.driftDelay),
                value: isAnimating
            )
            .onChange(of: isAnimating) { _, newValue in
                if newValue {
                    withAnimation(
                        .easeIn(duration: pappus.duration * 0.7)
                        .delay(pappus.driftDelay + pappus.duration * 0.3)
                    ) {
                        opacity = 0
                    }
                }
            }
    }
}

// MARK: - Pappus Seed Decoration

/// Visual representation of a pappus seed (the fluffy part)
struct PappusSeedView: View {
    let size: CGFloat
    @Environment(AppearanceManager.self) private var appearance

    var body: some View {
        let theme = appearance.theme
        ZStack {
            // Simple radiating lines to suggest the fluffy seed head
            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(theme.pappus.opacity(0.6))
                    .frame(width: 1, height: size * 0.4)
                    .offset(y: -size * 0.2)
                    .rotationEffect(.degrees(Double(index) * 45))
            }

            // Center dot
            Circle()
                .fill(theme.accent.opacity(0.4))
                .frame(width: size * 0.15, height: size * 0.15)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        AppearanceManager().theme.background
            .ignoresSafeArea()

        PappusSeedView(size: 40)
    }
    .environment(AppearanceManager())
}
