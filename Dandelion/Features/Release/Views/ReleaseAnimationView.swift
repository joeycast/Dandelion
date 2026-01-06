//
//  ReleaseAnimationView.swift
//  Dandelion
//
//  Full-screen view showing text floating away like dandelion seeds
//

import SwiftUI

struct ReleaseAnimationView: View {
    let text: String
    let releaseMessage: String
    let onComplete: () -> Void
    var showsBackground: Bool = true
    var textRect: CGRect = .zero

    @State private var pappuses: [Pappus] = []
    @State private var isAnimating = false
    @State private var showMessage = false
    @State private var messageOpacity: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                if showsBackground {
                    Color.dandelionBackground
                        .ignoresSafeArea()
                }

                // Floating pappuses
                ForEach(pappuses) { pappus in
                    PappusView(pappus: pappus, isAnimating: isAnimating)
                }

                // Release message
                if showMessage {
                    VStack {
                        Spacer()

                        Text(releaseMessage)
                            .font(.dandelionTitle)
                            .foregroundColor(.dandelionText)
                            .opacity(messageOpacity)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DandelionSpacing.xl)

                        Spacer()
                    }
                }
            }
            .onAppear {
                let maxEndTime = setupPappuses(
                    screenSize: geometry.size,
                    textRect: textRect.isEmpty ? nil : textRect
                )
                startAnimation(maxEndTime: maxEndTime)
            }
        }
    }

    private func setupPappuses(screenSize: CGSize, textRect: CGRect?) -> Double {
        // Parse text into individual letters and create pappuses
        let generated = Pappus.fromText(text, screenSize: screenSize, textRect: textRect)
        pappuses = generated
        return generated.map { $0.duration + $0.driftDelay }.max() ?? 0
    }

    private func startAnimation(maxEndTime: Double) {
        let clampedEndTime = max(3.4, maxEndTime)
        let messageDelay = max(1.4, clampedEndTime * 0.3)
        let messageHold = max(0.9, clampedEndTime * 0.2)
        let messageFadeTime = messageDelay + messageHold
        let completionTime = clampedEndTime + 0.4

        // Wait one frame for pappuses to render at start positions, then animate
        DispatchQueue.main.async {
            isAnimating = true
        }

        // Show release message after pappuses start floating
        DispatchQueue.main.asyncAfter(deadline: .now() + messageDelay) {
            showMessage = true
            withAnimation(.easeIn(duration: 0.8)) {
                messageOpacity = 1.0
            }
        }

        // Fade out message and complete
        DispatchQueue.main.asyncAfter(deadline: .now() + messageFadeTime) {
            withAnimation(.easeOut(duration: 1.0)) {
                messageOpacity = 0
            }
        }

        // Complete the animation
        DispatchQueue.main.asyncAfter(deadline: .now() + completionTime) {
            onComplete()
        }
    }
}

#Preview {
    ReleaseAnimationView(
        text: "This is a test of the release animation. Words should float away like dandelion seeds in the wind.",
        releaseMessage: "Let it drift away.",
        onComplete: {}
    )
}
