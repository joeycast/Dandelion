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

        // Calculate end position (drifting upward and outward)
        let horizontalDrift = CGFloat.random(in: -150...150)
        let verticalDrift = CGFloat.random(in: -screenSize.height * 0.8 ... -screenSize.height * 0.4)

        self.endPosition = CGPoint(
            x: startPosition.x + horizontalDrift,
            y: startPosition.y + verticalDrift
        )

        self.endRotation = startRotation + Double.random(in: -45...45)
        self.driftDelay = Double.random(in: 0...0.1)
        self.duration = Double.random(in: 5.0...7.2)
    }
}

// MARK: - Text Parsing

extension Pappus {
    /// Parse text into individual pappuses (one per letter)
    static func fromText(
        _ text: String,
        screenSize: CGSize,
        textRect: CGRect? = nil
    ) -> [Pappus] {
        // Use provided rect or fall back to approximate writing area position
        let layoutRect: CGRect
        if let rect = textRect, rect.width > 0 && rect.height > 0 {
            layoutRect = rect
        } else {
            layoutRect = CGRect(x: 0, y: screenSize.height * 0.35, width: screenSize.width, height: screenSize.height * 0.5)
        }

        // Font metrics for 22pt serif
        let lineHeight: CGFloat = 30
        let charWidth: CGFloat = 11
        let textInsetX: CGFloat = 4
        let textInsetY: CGFloat = 10
        let layoutWidth = max(1, layoutRect.width - textInsetX * 2)
        let startX: CGFloat = layoutRect.minX + textInsetX
        let startY: CGFloat = layoutRect.minY + textInsetY

        var pappuses: [Pappus] = []
        var currentX: CGFloat = startX
        var currentY: CGFloat = startY

        for char in text {
            if char == "\n" {
                currentX = startX
                currentY += lineHeight
            } else if char.isWhitespace {
                currentX += charWidth
                if currentX > layoutRect.minX + layoutWidth {
                    currentX = startX
                    currentY += lineHeight
                }
            } else {
                if currentX + charWidth > layoutRect.minX + layoutWidth {
                    currentX = startX
                    currentY += lineHeight
                }

                let position = CGPoint(
                    x: currentX + CGFloat.random(in: -2...2),
                    y: currentY + CGFloat.random(in: -1...1)
                )

                pappuses.append(Pappus(
                    text: String(char),
                    startPosition: position,
                    screenSize: screenSize
                ))

                currentX += charWidth
            }
        }

        return pappuses
    }
}
