//
//  AnimatableTextView.swift
//  Dandelion
//
//  A text view that renders each character separately so they can animate independently
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct AnimatableTextView: View {
    let text: String
    let font: Font
    let uiFont: PlatformFont
    let textColor: Color
    let lineWidth: CGFloat
    let isAnimating: Bool
    let screenSize: CGSize
    let visibleHeight: CGFloat
    let scrollOffset: CGFloat

    private var lineHeight: CGFloat {
        uiFont.lineHeight
    }
    private let lineFragmentPadding: CGFloat = 5

    var body: some View {
        let layout = glyphLayout
        ZStack(alignment: .topLeading) {
            ForEach(layout.glyphs) { glyph in
                CharacterView(
                    character: glyph.character,
                    font: font,
                    textColor: textColor,
                    isAnimating: isAnimating,
                    screenSize: screenSize,
                    charIndex: glyph.charIndex,
                    lineIndex: glyph.lineIndex
                )
                .position(x: glyph.rect.midX, y: glyph.rect.midY)
            }
        }
        .frame(height: layout.totalHeight, alignment: .topLeading)
    }

    private struct GlyphLayout {
        let glyphs: [Glyph]
        let totalHeight: CGFloat
    }

    private struct Glyph: Identifiable {
        let id: Int
        let character: Character
        let rect: CGRect
        let lineIndex: Int
        let charIndex: Int
    }

    private var glyphLayout: GlyphLayout {
        guard !text.isEmpty, visibleHeight > 0 else {
            return GlyphLayout(glyphs: [], totalHeight: 0)
        }

        let attributedText = NSAttributedString(
            string: text,
            attributes: [.font: uiFont]
        )
        let textStorage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            size: CGSize(width: max(lineWidth, 0), height: .greatestFiniteMagnitude)
        )
        textContainer.lineFragmentPadding = lineFragmentPadding
        textContainer.lineBreakMode = .byWordWrapping

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let nsText = text as NSString
        var glyphs: [Glyph] = []
        var glyphIndex = 0
        var lineIndex = 0

        var totalHeight = layoutManager.usedRect(for: textContainer).height
        if text.hasSuffix("\n") {
            totalHeight += lineHeight
        }

        // Account for text container insets (8pt top and bottom padding in AutoScrollingTextEditor)
        let textContainerTopInset: CGFloat = 8
        let textContainerBottomInset: CGFloat = 8
        let adjustedScrollOffset = max(0, scrollOffset - textContainerTopInset)
        // Actual visible text height is smaller than container due to insets
        let actualVisibleHeight = visibleHeight - textContainerTopInset - textContainerBottomInset

        let clampedVisibleHeight = max(0, min(actualVisibleHeight, totalHeight))
        let isCropped = clampedVisibleHeight > 0 && clampedVisibleHeight < totalHeight

        // The visible region based on scroll position
        let visibleMinY = isCropped ? adjustedScrollOffset : 0
        let visibleMaxY = isCropped ? min(adjustedScrollOffset + clampedVisibleHeight, totalHeight) : max(clampedVisibleHeight, totalHeight)

        while glyphIndex < layoutManager.numberOfGlyphs {
            var lineRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange)

            if lineRect.maxY < visibleMinY {
                glyphIndex = NSMaxRange(lineRange)
                lineIndex += 1
                continue
            }
            if lineRect.minY > visibleMaxY {
                break
            }

            var charIndex = 0
            for glyph in lineRange.location..<NSMaxRange(lineRange) {
                let glyphRange = NSRange(location: glyph, length: 1)
                let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
                if charRange.length == 0 {
                    continue
                }
                let charString = nsText.substring(with: charRange)
                if charString == "\n" || charString == "\r" {
                    continue
                }
                guard let char = charString.first else {
                    continue
                }

                let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                if rect.maxY < visibleMinY || rect.minY > visibleMaxY {
                    continue
                }
                glyphs.append(
                    Glyph(
                        id: glyphs.count,
                        character: char,
                        rect: rect.offsetBy(dx: 0, dy: -visibleMinY),
                        lineIndex: lineIndex,
                        charIndex: charIndex
                    )
                )
                charIndex += 1
            }

            glyphIndex = NSMaxRange(lineRange)
            lineIndex += 1
        }

        let layoutHeight = isCropped ? clampedVisibleHeight : totalHeight
        return GlyphLayout(glyphs: glyphs, totalHeight: layoutHeight)
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
                    resetAnimationState()
                    startAnimation()
                } else {
                    resetAnimationState()
                }
            }
    }

    private func resetAnimationState() {
        offset = .zero
        rotation = 0
        opacity = 1
    }

    private func startAnimation() {
        let delay = Double.random(in: 0...0.3)
        let duration = Double.random(in: 4.0...6.0)

        // Random drift direction
        let horizontalDrift = CGFloat.random(in: -200...200)
        let verticalDrift = CGFloat.random(in: -screenSize.height * 1.2 ... -screenSize.height * 0.6)
        let finalRotation = Double.random(in: -60...60)

        withAnimation(.easeInOut(duration: duration).delay(delay)) {
            offset = CGSize(width: horizontalDrift, height: verticalDrift)
            rotation = finalRotation
        }

        // Hold visibility, then fade
        let holdTime: Double = 3.0
        let fadeDuration = max(0.8, duration * 0.35)
        withAnimation(.easeIn(duration: fadeDuration).delay(delay + holdTime)) {
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
            uiFont: .dandelionWriting,
            textColor: .dandelionText,
            lineWidth: 300,
            isAnimating: false,
            screenSize: CGSize(width: 393, height: 852),
            visibleHeight: 300,
            scrollOffset: 0
        )
        .padding()
    }
}
