//
//  ReleaseMessageView.swift
//  Dandelion
//
//  Shows the release message after letters start floating away
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ReleaseMessageView: View {
    let releaseMessage: String
    let onMessageAppear: () -> Void
    let onMessageFadeStart: () -> Void
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
                        .offset(y: -DandelionSpacing.sm)
                        .frame(height: messageAreaHeight, alignment: .top)
                    Spacer()
                }
            }
        }
        .onAppear {
            startSequence()
        }
    }

    private var messageAreaHeight: CGFloat {
        let lineHeight: CGFloat
        #if canImport(UIKit)
        lineHeight = UIFont.dandelionTitle.lineHeight
        #elseif canImport(AppKit)
        lineHeight = NSFont.dandelionTitle.lineHeight
        #else
        lineHeight = 24
        #endif
        return lineHeight * 2.2
    }

    private func startSequence() {
        // Show message after letters are mostly gone
        let showDelay: TimeInterval = 4.0
        let fadeDelay: TimeInterval = 8.0
        let completeDelay: TimeInterval = 9.0

        DispatchQueue.main.asyncAfter(deadline: .now() + showDelay) {
            showMessage = true
            onMessageAppear()
            withAnimation(.easeIn(duration: 0.8)) {
                messageOpacity = 1.0
            }
        }

        // Fade out message and notify
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDelay) {
            onMessageFadeStart()
            withAnimation(.easeOut(duration: 1.0)) {
                messageOpacity = 0
            }
        }

        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + completeDelay) {
            onComplete()
        }
    }
}

#Preview {
    ZStack {
        Color.dandelionBackground.ignoresSafeArea()
        ReleaseMessageView(
            releaseMessage: "Let it drift away.",
            onMessageAppear: {},
            onMessageFadeStart: {},
            onComplete: {}
        )
    }
}
