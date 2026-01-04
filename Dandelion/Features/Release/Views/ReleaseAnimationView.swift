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

    @State private var pappuses: [Pappus] = []
    @State private var isAnimating = false
    @State private var showMessage = false
    @State private var messageOpacity: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.dandelionBackground
                    .ignoresSafeArea()

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
                setupPappuses(screenSize: geometry.size)
                startAnimation()
            }
        }
    }

    private func setupPappuses(screenSize: CGSize) {
        // Parse text into individual letters and create pappuses
        pappuses = Pappus.fromText(text, screenSize: screenSize)
    }

    private func startAnimation() {
        // Small delay before animation starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                isAnimating = true
            }
        }

        // Show release message after pappuses start floating
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showMessage = true
            withAnimation(.easeIn(duration: 0.8)) {
                messageOpacity = 1.0
            }
        }

        // Fade out message and complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 1.0)) {
                messageOpacity = 0
            }
        }

        // Complete the animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
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
