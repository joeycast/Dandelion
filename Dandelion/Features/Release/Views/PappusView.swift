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

    @State private var opacity: Double = 1.0

    var body: some View {
        Text(pappus.text)
            .font(.dandelionWriting)
            .foregroundColor(.dandelionText)
            .opacity(opacity)
            .position(isAnimating ? pappus.endPosition : pappus.startPosition)
            .rotationEffect(.degrees(isAnimating ? pappus.endRotation : pappus.startRotation))
            .animation(
                .easeOut(duration: pappus.duration)
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

    var body: some View {
        ZStack {
            // Simple radiating lines to suggest the fluffy seed head
            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(Color.dandelionPappus.opacity(0.6))
                    .frame(width: 1, height: size * 0.4)
                    .offset(y: -size * 0.2)
                    .rotationEffect(.degrees(Double(index) * 45))
            }

            // Center dot
            Circle()
                .fill(Color.dandelionAccent.opacity(0.4))
                .frame(width: size * 0.15, height: size * 0.15)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        Color.dandelionBackground
            .ignoresSafeArea()

        PappusSeedView(size: 40)
    }
}
