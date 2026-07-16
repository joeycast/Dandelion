//
//  AnimatableTextView.swift
//  Dandelion
//
//  A text view that renders each character so they can animate independently.
//  Uses Canvas + TimelineView on all platforms for performance.
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cachedLayout: GlyphLayout = GlyphLayout(glyphs: [], totalHeight: 0)
    @State private var cachedKey: LayoutKey?
    @State private var containerOpacity: Double = 1
    @State private var animationStartTime: Date?
    @State private var glyphAnimations: [GlyphAnimation] = []

    private struct GlyphAnimation {
        let delay: Double
        let duration: Double
        let horizontalDrift: CGFloat
        let verticalDrift: CGFloat
        let finalRotation: Double
    }

    /// Extra space above text so characters can fly upward without clipping.
    /// macOS uses a larger overflow because the overlay is positioned higher.
#if os(macOS)
    private let topOverflowForAnimation: CGFloat = 500
#else
    private let topOverflowForAnimation: CGFloat = 0
#endif

    var body: some View {
        // Compute layout synchronously on first render to avoid frame jumps
        let layout: GlyphLayout = {
            if cachedLayout.glyphs.isEmpty && !text.isEmpty {
                return computeGlyphLayout()
            }
            return cachedLayout
        }()

        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isAnimating || reduceMotion)) { timeline in
            Canvas { context, _ in
                let elapsed = animationStartTime.map { timeline.date.timeIntervalSince($0) } ?? 0

                for (index, glyph) in layout.glyphs.enumerated() {
                    if reduceMotion || !isAnimating {
                        drawCharacter(
                            context: context,
                            glyph: glyph,
                            offset: CGSize(width: 0, height: topOverflowForAnimation),
                            rotation: 0,
                            opacity: 1
                        )
                        continue
                    }

                    guard index < glyphAnimations.count else {
                        drawCharacter(
                            context: context,
                            glyph: glyph,
                            offset: CGSize(width: 0, height: topOverflowForAnimation),
                            rotation: 0,
                            opacity: 1
                        )
                        continue
                    }
                    let anim = glyphAnimations[index]

                    let timeSinceStart = elapsed - anim.delay
                    guard timeSinceStart > 0 else {
                        drawCharacter(
                            context: context,
                            glyph: glyph,
                            offset: CGSize(width: 0, height: topOverflowForAnimation),
                            rotation: 0,
                            opacity: 1
                        )
                        continue
                    }

                    let progress = min(timeSinceStart / anim.duration, 1.0)
                    let easedProgress = easeInOut(progress)

                    let currentOffset = CGSize(
                        width: anim.horizontalDrift * easedProgress,
                        height: topOverflowForAnimation + anim.verticalDrift * easedProgress
                    )
                    let currentRotation = anim.finalRotation * easedProgress

                    drawCharacter(
                        context: context,
                        glyph: glyph,
                        offset: currentOffset,
                        rotation: currentRotation,
                        opacity: 1
                    )
                }
            }
        }
        .frame(height: layout.totalHeight + topOverflowForAnimation, alignment: .topLeading)
        .opacity(containerOpacity)
        .onAppear {
            if cachedLayout.glyphs.isEmpty {
                cachedLayout = layout
                cachedKey = layoutKey
            }
            if isAnimating && glyphAnimations.isEmpty && !reduceMotion {
                prepareAnimations(for: cachedLayout)
                animationStartTime = Date()
            }
        }
        .onChange(of: layoutKey) { _, _ in
            updateLayoutIfNeeded()
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                if reduceMotion {
                    // Simple collective dissolve instead of per-character flight.
                    withAnimation(.easeIn(duration: 0.9)) {
                        containerOpacity = 0
                    }
                    animationStartTime = nil
                    glyphAnimations = []
                } else {
                    prepareAnimations(for: cachedLayout)
                    animationStartTime = Date()
                }
            } else {
                animationStartTime = nil
                containerOpacity = 1
            }
        }
        .onChange(of: fadeOutTrigger) { _, newValue in
            if newValue {
                let duration = reduceMotion ? 0.35 : 0.5
                withAnimation(.easeIn(duration: duration)) {
                    containerOpacity = 0
                }
            } else if !isAnimating {
                containerOpacity = 1
            }
        }
    }

    private func prepareAnimations(for layout: GlyphLayout) {
        let maxHorizontalDrift = screenSize.width * 0.4
        glyphAnimations = layout.glyphs.map { _ in
            GlyphAnimation(
                delay: Double.random(in: 0...0.3),
                // Duration must exceed fade-out timing so letters keep moving while fading
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

    private func drawCharacter(
        context: GraphicsContext,
        glyph: Glyph,
        offset: CGSize,
        rotation: Double,
        opacity: Double
    ) {
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
        let actualVisibleHeight = visibleHeight - textContainerTopInset - textContainerBottomInset

        let bottomBleed = max(2, ceil(abs(uiFont.descender)) + 2)
        let clampedVisibleHeight = max(0, min(actualVisibleHeight + bottomBleed, totalHeight))
        let isCropped = clampedVisibleHeight > 0 && clampedVisibleHeight < totalHeight

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
