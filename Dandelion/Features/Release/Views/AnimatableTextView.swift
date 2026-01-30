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
    let fadeOutTrigger: Bool
    let screenSize: CGSize
    let visibleHeight: CGFloat
    let scrollOffset: CGFloat
    var horizontalOffset: CGFloat = 0

    private var lineHeight: CGFloat {
        uiFont.lineHeight
    }
    private let lineFragmentPadding: CGFloat = 5
    @State private var cachedLayout: GlyphLayout = GlyphLayout(glyphs: [], totalHeight: 0)
    @State private var cachedKey: LayoutKey?
    @State private var containerOpacity: Double = 1

#if os(macOS)
    // Animation state for Canvas-based rendering (macOS only)
    @State private var animationStartTime: Date?
    @State private var glyphAnimations: [MacGlyphAnimation] = []

    private struct MacGlyphAnimation {
        let delay: Double
        let duration: Double
        let horizontalDrift: CGFloat
        let verticalDrift: CGFloat
        let finalRotation: Double
    }
#endif

    // Extra space above text for upward animation on macOS
    private let topOverflowForAnimation: CGFloat = 500

    var body: some View {
        // Compute layout synchronously on first render to avoid frame jumps
        let layout: GlyphLayout = {
            if cachedLayout.glyphs.isEmpty && !text.isEmpty {
                return computeGlyphLayout()
            }
            return cachedLayout
        }()
#if os(macOS)
        // macOS: Use Canvas + TimelineView for performance (no view creation overhead)
        // Canvas is extended upward to allow characters to animate above the text area
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isAnimating)) { timeline in
            Canvas { context, size in
                let elapsed = animationStartTime.map { timeline.date.timeIntervalSince($0) } ?? 0

                for (index, glyph) in layout.glyphs.enumerated() {
                    // If animations aren't ready yet, draw at starting position
                    guard index < glyphAnimations.count else {
                        drawCharacter(context: context, glyph: glyph, offset: CGSize(width: 0, height: topOverflowForAnimation), rotation: 0, opacity: 1)
                        continue
                    }
                    let anim = glyphAnimations[index]

                    // Calculate animation progress
                    let timeSinceStart = elapsed - anim.delay
                    guard timeSinceStart > 0 else {
                        // Not started yet - draw at original position (offset down by topOverflow)
                        drawCharacter(context: context, glyph: glyph, offset: CGSize(width: 0, height: topOverflowForAnimation), rotation: 0, opacity: 1)
                        continue
                    }

                    let progress = min(timeSinceStart / anim.duration, 1.0)
                    let easedProgress = easeInOut(progress)

                    // Interpolate values - add topOverflow to vertical position
                    let currentOffset = CGSize(
                        width: anim.horizontalDrift * easedProgress,
                        height: topOverflowForAnimation + anim.verticalDrift * easedProgress
                    )
                    let currentRotation = anim.finalRotation * easedProgress
                    let currentOpacity = 1.0 // Opacity handled by container fadeOut

                    drawCharacter(context: context, glyph: glyph, offset: currentOffset, rotation: currentRotation, opacity: currentOpacity)
                }
            }
        }
        .frame(height: layout.totalHeight + topOverflowForAnimation)
        .opacity(containerOpacity)
        .onAppear {
            // Update cached layout if needed
            if cachedLayout.glyphs.isEmpty {
                cachedLayout = layout
                cachedKey = layoutKey
            }
            // Start animations immediately
            if isAnimating && glyphAnimations.isEmpty {
                prepareAnimations(for: cachedLayout)
                animationStartTime = Date()
            }
        }
        .onChange(of: layoutKey) { _, _ in
            updateLayoutIfNeeded()
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                prepareAnimations(for: cachedLayout)
                animationStartTime = Date()
            } else {
                animationStartTime = nil
            }
        }
        .onChange(of: fadeOutTrigger) { _, newValue in
            if newValue {
                withAnimation(.easeIn(duration: 0.5)) {
                    containerOpacity = 0
                }
            } else {
                containerOpacity = 1
            }
        }
#else
        // iOS: Use CharacterView approach (works well on iOS)
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
        .opacity(containerOpacity)
        .onAppear {
            updateLayoutIfNeeded()
        }
        .onChange(of: layoutKey) { _, _ in
            updateLayoutIfNeeded()
        }
        .onChange(of: fadeOutTrigger) { _, newValue in
            if newValue {
                withAnimation(.easeIn(duration: 0.5)) {
                    containerOpacity = 0
                }
            } else {
                containerOpacity = 1
            }
        }
#endif
    }

#if os(macOS)
    private func prepareAnimations(for layout: GlyphLayout) {
        // Wider horizontal drift to let particles roam across the full screen
        let maxHorizontalDrift = screenSize.width * 0.4
        glyphAnimations = layout.glyphs.map { _ in
            MacGlyphAnimation(
                delay: Double.random(in: 0...0.3),
                // Duration must exceed fade-out timing (4.0s + 0.5s fade) so letters keep moving while fading
                duration: Double.random(in: 5.5...7.5),
                horizontalDrift: CGFloat.random(in: -maxHorizontalDrift...maxHorizontalDrift),
                verticalDrift: CGFloat.random(in: -screenSize.height * 1.2 ... -screenSize.height * 0.6),
                finalRotation: Double.random(in: -60...60)
            )
        }
    }

    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    private func drawCharacter(context: GraphicsContext, glyph: Glyph, offset: CGSize, rotation: Double, opacity: Double) {
        var context = context
        let position = CGPoint(
            x: glyph.rect.midX + offset.width + horizontalOffset,
            y: glyph.rect.midY + offset.height
        )

        context.opacity = opacity
        context.translateBy(x: position.x, y: position.y)
        context.rotate(by: .degrees(rotation))

        let text = Text(String(glyph.character))
            .font(font)
            .foregroundColor(textColor)

        context.draw(text, at: .zero)
    }
#endif

    private func updateLayoutIfNeeded() {
        let key = layoutKey
        guard cachedKey != key else { return }
        cachedKey = key
        cachedLayout = computeGlyphLayout()
    }

    private func computeGlyphLayout() -> GlyphLayout {
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
        layoutManager.ensureLayout(for: textContainer)

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

    private struct LayoutKey: Hashable {
        let textHash: Int
        let lineWidth: Int
        let visibleHeight: Int
        let scrollOffset: Int
        let fontName: String
        let fontSize: Int
    }

    private var layoutKey: LayoutKey {
        LayoutKey(
            textHash: text.hashValue,
            lineWidth: Int(lineWidth.rounded()),
            visibleHeight: Int(visibleHeight.rounded()),
            scrollOffset: Int(scrollOffset.rounded()),
            fontName: uiFont.fontName,
            fontSize: Int(uiFont.pointSize.rounded())
        )
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
            .onAppear {
                if isAnimating {
                    resetAnimationState()
                    startAnimation()
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
        // Duration must exceed fade-out timing (4.0s + 0.5s fade) so letters keep moving while fading
        let duration = Double.random(in: 5.5...7.5)

        // Random drift direction
        let horizontalDrift = CGFloat.random(in: -200...200)
        let verticalDrift = CGFloat.random(in: -screenSize.height * 1.2 ... -screenSize.height * 0.6)
        let finalRotation = Double.random(in: -60...60)

        withAnimation(.easeInOut(duration: duration).delay(delay)) {
            offset = CGSize(width: horizontalDrift, height: verticalDrift)
            rotation = finalRotation
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
            textColor: AppearanceManager().theme.text,
            lineWidth: 300,
            isAnimating: false,
            fadeOutTrigger: false,
            screenSize: CGSize(width: 393, height: 852),
            visibleHeight: 300,
            scrollOffset: 0
        )
        .padding()
    }
}
