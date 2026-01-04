//
//  Pappus.swift
//  Dandelion
//
//  Model for a single floating pappus (dandelion seed)
//

import SwiftUI

/// Represents a single pappus (dandelion seed) carrying text
struct Pappus: Identifiable, Equatable {
    let id: UUID
    let text: String
    let startPosition: CGPoint
    let startRotation: Double

    // Animation properties
    var endPosition: CGPoint
    var endRotation: Double
    var driftDelay: Double
    var duration: Double

    init(
        text: String,
        startPosition: CGPoint,
        screenSize: CGSize
    ) {
        self.id = UUID()
        self.text = text
        self.startPosition = startPosition
        self.startRotation = Double.random(in: -5...5)

        // Calculate random end position (drifting upward and outward)
        let horizontalDrift = CGFloat.random(in: -150...150)
        let verticalDrift = CGFloat.random(in: -screenSize.height * 0.8 ... -screenSize.height * 0.4)

        self.endPosition = CGPoint(
            x: startPosition.x + horizontalDrift,
            y: startPosition.y + verticalDrift
        )

        self.endRotation = startRotation + Double.random(in: -45...45)
        self.driftDelay = Double.random(in: 0...0.3)
        self.duration = Double.random(in: 2.5...4.0)
    }
}

// MARK: - Text Parsing

extension Pappus {
    /// Parse text into individual pappuses (one per letter)
    static func fromText(
        _ text: String,
        screenSize: CGSize
    ) -> [Pappus] {
        // Filter to just letters and numbers (skip whitespace)
        let characters = text.filter { !$0.isWhitespace }

        // Estimate character layout based on typical text flow
        let charsPerLine = Int(screenSize.width / 16) // Approximate chars per line
        let lineHeight: CGFloat = 35
        let charWidth: CGFloat = 14
        let startX: CGFloat = 24 // Left margin
        let startY: CGFloat = screenSize.height * 0.15 // Start near top

        return characters.enumerated().map { index, char in
            // Calculate approximate position based on character index
            let lineNumber = index / charsPerLine
            let charInLine = index % charsPerLine

            let position = CGPoint(
                x: startX + CGFloat(charInLine) * charWidth + CGFloat.random(in: -5...5),
                y: startY + CGFloat(lineNumber) * lineHeight + CGFloat.random(in: -3...3)
            )

            return Pappus(
                text: String(char),
                startPosition: position,
                screenSize: screenSize
            )
        }
    }
}
