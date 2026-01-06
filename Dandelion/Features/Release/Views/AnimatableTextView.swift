//
//  AnimatableTextView.swift
//  Dandelion
//
//  A text view that renders each character separately so they can animate independently
//

import SwiftUI

struct AnimatableTextView: View {
    let text: String
    let font: Font
    let textColor: Color
    let lineWidth: CGFloat
    let isAnimating: Bool
    let screenSize: CGSize

    // Character metrics for 22pt serif font - slightly smaller to match TextEditor wrapping
    private let charWidth: CGFloat = 10.5
    private let lineHeight: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { lineIndex, line in
                HStack(spacing: 0) {
                    ForEach(Array(line.enumerated()), id: \.offset) { charIndex, char in
                        CharacterView(
                            character: char,
                            font: font,
                            textColor: textColor,
                            isAnimating: isAnimating,
                            screenSize: screenSize,
                            charIndex: charIndex,
                            lineIndex: lineIndex
                        )
                    }
                    Spacer(minLength: 0)
                }
                .frame(height: lineHeight)
            }
        }
    }

    // Break text into lines based on available width
    private var lines: [[Character]] {
        var result: [[Character]] = []
        var currentLine: [Character] = []
        var currentWidth: CGFloat = 0
        var currentWord: [Character] = []
        var wordWidth: CGFloat = 0

        for char in text {
            if char == "\n" {
                // Explicit newline
                currentLine.append(contentsOf: currentWord)
                result.append(currentLine)
                currentLine = []
                currentWord = []
                currentWidth = 0
                wordWidth = 0
            } else if char.isWhitespace {
                // Space - commit current word to line
                if currentWidth + wordWidth + charWidth <= lineWidth {
                    currentLine.append(contentsOf: currentWord)
                    currentLine.append(char)
                    currentWidth += wordWidth + charWidth
                } else if currentLine.isEmpty {
                    // Word is too long for line, force it
                    currentLine.append(contentsOf: currentWord)
                    currentLine.append(char)
                    result.append(currentLine)
                    currentLine = []
                    currentWidth = 0
                } else {
                    // Wrap to next line
                    result.append(currentLine)
                    currentLine = currentWord
                    currentLine.append(char)
                    currentWidth = wordWidth + charWidth
                }
                currentWord = []
                wordWidth = 0
            } else {
                // Regular character - add to current word
                currentWord.append(char)
                wordWidth += charWidth
            }
        }

        // Commit remaining word and line
        if !currentWord.isEmpty {
            if currentWidth + wordWidth <= lineWidth {
                currentLine.append(contentsOf: currentWord)
            } else if currentLine.isEmpty {
                currentLine.append(contentsOf: currentWord)
            } else {
                result.append(currentLine)
                currentLine = currentWord
            }
        }
        if !currentLine.isEmpty {
            result.append(currentLine)
        }

        return result
    }
}

struct CharacterView: View {
    let character: Character
    let font: Font
    let textColor: Color
    let isAnimating: Bool
    let screenSize: CGSize
    let charIndex: Int
    let lineIndex: Int

    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1

    var body: some View {
        Text(String(character))
            .font(font)
            .foregroundColor(textColor)
            .opacity(opacity)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .onChange(of: isAnimating) { _, newValue in
                if newValue {
                    startAnimation()
                }
            }
    }

    private func startAnimation() {
        let delay = Double.random(in: 0...0.3)
        let duration = Double.random(in: 4.0...6.0)

        // Random drift direction
        let horizontalDrift = CGFloat.random(in: -200...200)
        let verticalDrift = CGFloat.random(in: -screenSize.height * 0.8 ... -screenSize.height * 0.3)
        let finalRotation = Double.random(in: -60...60)

        withAnimation(.easeInOut(duration: duration).delay(delay)) {
            offset = CGSize(width: horizontalDrift, height: verticalDrift)
            rotation = finalRotation
        }

        // Fade out in the latter part of animation
        withAnimation(.easeIn(duration: duration * 0.6).delay(delay + duration * 0.4)) {
            opacity = 0
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        AnimatableTextView(
            text: "Hello World this is a test of the animation",
            font: .dandelionWriting,
            textColor: .dandelionText,
            lineWidth: 300,
            isAnimating: false,
            screenSize: CGSize(width: 393, height: 852)
        )
        .padding()
    }
}
