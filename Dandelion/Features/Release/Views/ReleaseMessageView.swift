//
//  ReleaseMessageView.swift
//  Dandelion
//
//  Shows the release message after letters start floating away
//

import SwiftUI

struct ReleaseMessageView: View {
    let releaseMessage: String
    let onComplete: () -> Void

    @State private var showMessage = false
    @State private var messageOpacity: Double = 0

    var body: some View {
        ZStack {
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
            startSequence()
        }
    }

    private func startSequence() {
        // Show message after letters start floating
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showMessage = true
            withAnimation(.easeIn(duration: 0.8)) {
                messageOpacity = 1.0
            }
        }

        // Fade out message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeOut(duration: 1.0)) {
                messageOpacity = 0
            }
        }

        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            onComplete()
        }
    }
}

#Preview {
    ZStack {
        Color.dandelionBackground.ignoresSafeArea()
        ReleaseMessageView(
            releaseMessage: "Let it drift away.",
            onComplete: {}
        )
    }
}
