//
//  WordAnimatedTextView.swift
//  Dandelion
//
//  A text view that reveals words sequentially.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct WordAnimatedTextView: View {
    let text: String
    let font: Font
    let uiFont: PlatformFont
    let textColor: Color
    let lineWidth: CGFloat
    let isAnimating: Bool
    let maxLines: Int?
    let lineBreakMode: NSLineBreakMode
    let layoutIDPrefix: String

    private let lineFragmentPadding: CGFloat = 0

    init(
        text: String,
        font: Font,
        uiFont: PlatformFont,
        textColor: Color,
        lineWidth: CGFloat,
        isAnimating: Bool,
        maxLines: Int? = nil,
        lineBreakMode: NSLineBreakMode = .byWordWrapping,
        layoutIDPrefix: String = "prompt"
    ) {
        self.text = text
        self.font = font
        self.uiFont = uiFont
        self.textColor = textColor
        self.lineWidth = lineWidth
        self.isAnimating = isAnimating
        self.maxLines = maxLines
        self.lineBreakMode = lineBreakMode
        self.layoutIDPrefix = layoutIDPrefix
    }

    var body: some View {
        let layout = wordLayout
        ZStack(alignment: .topLeading) {
            ForEach(layout.words) { word in
                WordView(
                    text: word.text,
                    font: font,
                    textColor: textColor,
                    isAnimating: isAnimating,
                    wordIndex: word.wordIndex
                )
                .position(x: word.rect.midX, y: word.rect.midY)
            }
        }
        .frame(width: lineWidth, height: layout.totalHeight, alignment: .topLeading)
    }

    private struct WordLayout {
        let words: [Word]
        let totalHeight: CGFloat
    }

    private struct Word: Identifiable {
        let id: String
        let text: String
        let rect: CGRect
        let wordIndex: Int
    }

    private var wordLayout: WordLayout {
        guard !text.isEmpty else {
            return WordLayout(words: [], totalHeight: 0)
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = lineBreakMode

        let attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: uiFont,
                .paragraphStyle: paragraphStyle
            ]
        )
        let textStorage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            size: CGSize(width: max(lineWidth, 0), height: .greatestFiniteMagnitude)
        )
        textContainer.lineFragmentPadding = lineFragmentPadding
        textContainer.lineBreakMode = lineBreakMode
        textContainer.maximumNumberOfLines = maxLines ?? 0

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)

        let nsText = text as NSString
        let wordRanges = nonWhitespaceRanges(in: nsText)
        var words: [Word] = []
        var wordIndex = 0

        for range in wordRanges {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            if glyphRange.length == 0 {
                continue
            }
            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            let wordText = nsText.substring(with: range)
            words.append(
                Word(
                    id: "\(layoutIDPrefix)-\(range.location)-\(range.length)",
                    text: wordText,
                    rect: rect,
                    wordIndex: wordIndex
                )
            )
            wordIndex += 1
        }

        var totalHeight = layoutManager.usedRect(for: textContainer).height
        if text.hasSuffix("\n") {
            totalHeight += uiFont.lineHeight
        }

        return WordLayout(words: words, totalHeight: totalHeight)
    }

    private func nonWhitespaceRanges(in text: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        var startIndex: Int?
        let whitespaceSet = CharacterSet.whitespacesAndNewlines

        for index in 0..<text.length {
            let character = text.character(at: index)
            let isWhitespace: Bool
            if let scalar = UnicodeScalar(character) {
                isWhitespace = whitespaceSet.contains(scalar)
            } else {
                isWhitespace = false
            }

            if isWhitespace {
                if let startIndex, index > startIndex {
                    ranges.append(NSRange(location: startIndex, length: index - startIndex))
                }
                startIndex = nil
            } else if startIndex == nil {
                startIndex = index
            }
        }

        if let startIndex, text.length > startIndex {
            ranges.append(NSRange(location: startIndex, length: text.length - startIndex))
        }

        return ranges
    }
}

private struct WordView: View {
    let text: String
    let font: Font
    let textColor: Color
    let isAnimating: Bool
    let wordIndex: Int

    @State private var opacity: Double = 0
    @State private var offset: CGSize = CGSize(width: 0, height: 8)

    init(
        text: String,
        font: Font,
        textColor: Color,
        isAnimating: Bool,
        wordIndex: Int
    ) {
        self.text = text
        self.font = font
        self.textColor = textColor
        self.isAnimating = isAnimating
        self.wordIndex = wordIndex
        _opacity = State(initialValue: isAnimating ? 0 : 1)
        _offset = State(initialValue: isAnimating ? CGSize(width: 0, height: 8) : .zero)
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(textColor)
            .opacity(opacity)
            .offset(offset)
            .onAppear {
                if isAnimating {
                    startAnimation()
                }
            }
            .onChange(of: isAnimating) { _, newValue in
                if newValue {
                    resetForAnimation()
                    startAnimation()
                } else {
                    setVisible(animated: false)
                }
            }
    }

    private func resetForAnimation() {
        opacity = 0
        offset = CGSize(width: 0, height: 8)
    }

    private func setVisible() {
        setVisible(animated: false)
    }

    private func setVisible(animated: Bool) {
        let updates = {
            opacity = 1
            offset = .zero
        }
        if animated {
            withAnimation(.easeOut(duration: 0.45)) {
                updates()
            }
        } else {
            withAnimation(nil) {
                updates()
            }
        }
    }

    private func startAnimation() {
        let delay = Double(wordIndex) * 0.05
        withAnimation(.easeOut(duration: 0.45).delay(delay)) {
            opacity = 1
            offset = .zero
        }
    }
}
