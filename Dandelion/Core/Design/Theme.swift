//
//  Theme.swift
//  Dandelion
//
//  Design system for Dandelion - colors, typography, and spacing
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Colors

extension Color {
    /// Soft cream/white background
//    static let dandelionBackground = Color(red: 0.99, green: 0.98, blue: 0.95)
    static let dandelionBackground = Color(red: 0, green: 0, blue: 0)

    /// Pale yellow - primary dandelion color
    static let dandelionPrimary = Color(red: 0.98, green: 0.93, blue: 0.75)

    /// Gentle gold accent
    static let dandelionAccent = Color(red: 0.85, green: 0.75, blue: 0.45)

    /// Warm dark gray for text
//    static let dandelionText = Color(red: 0.25, green: 0.24, blue: 0.22)
    static let dandelionText = Color(red: 0.98, green: 0.93, blue: 0.75)

    /// Light gray for secondary text and hints
    static let dandelionSecondary = Color(red: 0.55, green: 0.53, blue: 0.50)

    /// Very light gray for subtle elements
    static let dandelionSubtle = Color(red: 0.88, green: 0.86, blue: 0.82)

    /// Pappus color - slightly off-white for floating seeds
    static let dandelionPappus = Color(red: 0.97, green: 0.95, blue: 0.90)
}

// MARK: - Typography

extension Font {
    /// Large title for prompts and messages - serif
    static let dandelionTitle = Font.system(.largeTitle, design: .serif)

    /// Main writing font - serif for elegance
    static let dandelionBody = Font.system(.title2, design: .serif)

    /// Writing text - larger size for comfortable writing
    static let dandelionWriting = Font.system(size: 22, weight: .regular, design: .serif)

    /// Secondary text - prompts, hints
    static let dandelionSecondary = Font.system(.body, design: .serif)

    /// Small caption text
    static let dandelionCaption = Font.system(.caption, design: .serif)

    /// Button text
    static let dandelionButton = Font.system(.headline, design: .serif)
}

#if canImport(UIKit)
extension UIFont {
    static var dandelionWriting: UIFont {
        let base = UIFont.systemFont(ofSize: 22, weight: .regular)
        let descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
        return UIFont(descriptor: descriptor, size: 22)
    }

    static var dandelionTitle: UIFont {
        let base = UIFont.preferredFont(forTextStyle: .largeTitle)
        let descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
        return UIFont(descriptor: descriptor, size: base.pointSize)
    }

    static var dandelionCaption: UIFont {
        let base = UIFont.preferredFont(forTextStyle: .caption1)
        let descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
        return UIFont(descriptor: descriptor, size: base.pointSize)
    }
}
#elseif canImport(AppKit)
extension NSFont {
    static var dandelionWriting: NSFont {
        let base = NSFont.systemFont(ofSize: 22, weight: .regular)
        let descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
        return NSFont(descriptor: descriptor, size: 22) ?? base
    }

    static var dandelionTitle: NSFont {
        let base = NSFont.preferredFont(forTextStyle: .largeTitle)
        let descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
        return NSFont(descriptor: descriptor, size: base.pointSize) ?? base
    }

    static var dandelionCaption: NSFont {
        let base = NSFont.preferredFont(forTextStyle: .caption1)
        let descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
        return NSFont(descriptor: descriptor, size: base.pointSize) ?? base
    }
}
#endif

// MARK: - Spacing

enum DandelionSpacing {
    /// Extra small: 4pt
    static let xs: CGFloat = 4

    /// Small: 8pt
    static let sm: CGFloat = 8

    /// Medium: 16pt
    static let md: CGFloat = 16

    /// Large: 24pt
    static let lg: CGFloat = 24

    /// Extra large: 32pt
    static let xl: CGFloat = 32

    /// Extra extra large: 48pt
    static let xxl: CGFloat = 48
    
    /// extra extra extra large: 96pt
    static let xxxl: CGFloat = 96

    /// Screen edge padding
    static let screenEdge: CGFloat = 24
}

// MARK: - Animation

enum DandelionAnimation {
    /// Standard gentle animation
    static let gentle = Animation.easeInOut(duration: 0.4)

    /// Slow, intentional animation
    static let slow = Animation.easeInOut(duration: 0.8)

    /// Very slow for meaningful transitions
    static let meaningful = Animation.easeInOut(duration: 1.2)

    /// Pappus floating animation base duration
    static let pappusFloat: Double = 3.0

    /// Spring animation for subtle bounces
    static let gentleSpring = Animation.spring(response: 0.6, dampingFraction: 0.8)
}

// MARK: - Shadows

extension View {
    /// Subtle shadow for elevated elements
    func dandelionShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(0.06),
            radius: 12,
            x: 0,
            y: 4
        )
    }

    /// Very subtle shadow for text elements
    func dandelionTextShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(0.03),
            radius: 2,
            x: 0,
            y: 1
        )
    }
}

// MARK: - Button Styles

struct DandelionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dandelionButton)
            .foregroundColor(.dandelionBackground)
            .padding(.horizontal, DandelionSpacing.lg)
            .padding(.vertical, DandelionSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dandelionPrimary)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DandelionAnimation.gentle, value: configuration.isPressed)
    }
}

struct DandelionSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dandelionButton)
            .foregroundColor(.dandelionSecondary)
            .padding(.horizontal, DandelionSpacing.lg)
            .padding(.vertical, DandelionSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.dandelionSubtle, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(DandelionAnimation.gentle, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == DandelionButtonStyle {
    static var dandelion: DandelionButtonStyle { DandelionButtonStyle() }
}

extension ButtonStyle where Self == DandelionSecondaryButtonStyle {
    static var dandelionSecondary: DandelionSecondaryButtonStyle { DandelionSecondaryButtonStyle() }
}
