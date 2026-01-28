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
// Colors now come from AppearanceManager.theme to support palettes.

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

// MARK: - Dandelion Layout System

/// Centralized layout calculations for positioning the dandelion and text elements.
/// Ensures consistent spacing across all device sizes from iPhone SE to 13" iPad.
enum DandelionLayout {

    // MARK: - Fixed Layout Constants

    /// Dandelion size when showing prompt (large)
    static let dandelionLargeHeight: CGFloat = 220

    /// Dandelion size during writing (small)
    static let dandelionSmallHeight: CGFloat = 80

    /// Fixed spacing between dandelion visual bottom and text content.
    /// This is the actual visual gap the user sees, consistent across all devices.
    static let dandelionToTextSpacing: CGFloat = 16

    /// Minimum top margin above dandelion (below safe area)
    static let minTopMargin: CGFloat = 16

    /// Top safe area inset offset used for buttons (history/settings)
    static let topButtonsHeight: CGFloat = 32

    /// Maximum writing line width on macOS to keep text readable in wide windows.
    static let maxWritingWidth: CGFloat = 720

    // MARK: - Positioning Helpers

    /// Calculate the proportional offset used to center the dandelion on prompt/release states.
    /// iOS: Capped at 80pt to prevent excessive offset on large screens (iPads).
    /// macOS: Uses larger offset to better center content on spacious desktop windows.
    static func proportionalOffset(screenHeight: CGFloat) -> CGFloat {
#if os(macOS)
        // On macOS, push content down more to center it in larger windows
        return min(screenHeight * 0.15, 180)
#else
        return min(screenHeight * 0.08, 80)
#endif
    }
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

    @ViewBuilder
    func dandelionListStyle() -> some View {
#if os(iOS)
        self.listStyle(.insetGrouped)
#else
        self.listStyle(.inset)
#endif
    }

    @ViewBuilder
    func dandelionNavigationBarStyle(background: Color, colorScheme: ColorScheme) -> some View {
#if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(background, for: .navigationBar)
            .toolbarColorScheme(colorScheme, for: .navigationBar)
#else
        self
#endif
    }

    @ViewBuilder
    func dandelionSettingsSheetDetents() -> some View {
#if os(iOS)
        self.presentationDetents([.large])
#else
        self
#endif
    }
}

// MARK: - Button Styles

struct DandelionButtonStyle: ButtonStyle {
    @Environment(AppearanceManager.self) private var appearance

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dandelionButton)
            .foregroundColor(appearance.theme.background)
            .padding(.horizontal, DandelionSpacing.lg)
            .padding(.vertical, DandelionSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(appearance.theme.primary)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DandelionAnimation.gentle, value: configuration.isPressed)
    }
}

struct DandelionSecondaryButtonStyle: ButtonStyle {
    @Environment(AppearanceManager.self) private var appearance

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dandelionButton)
            .foregroundColor(appearance.theme.secondary)
            .padding(.horizontal, DandelionSpacing.lg)
            .padding(.vertical, DandelionSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(appearance.theme.subtle, lineWidth: 1)
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
