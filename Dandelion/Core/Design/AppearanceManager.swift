//
//  AppearanceManager.swift
//  Dandelion
//
//  Manages palettes, dandelion styles, and appearance persistence
//

import SwiftUI

enum DandelionPalette: String, CaseIterable, Identifiable {
    case dark
    case dawn
    case twilight
    case forest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .dawn: return "Dawn"
        case .twilight: return "Twilight"
        case .forest: return "Forest"
        }
    }
}

struct DandelionTheme: Equatable {
    let background: Color
    let card: Color          // Elevated surface for list rows, cards
    let primary: Color
    let accent: Color
    let text: Color
    let secondary: Color
    let subtle: Color
    let pappus: Color
}

enum DandelionStyle: String, CaseIterable, Identifiable {
    case procedural
    case watercolor
    case pencil

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .procedural: return "Procedural"
        case .watercolor: return "Watercolor"
        case .pencil: return "Pencil Art"
        }
    }
}

@MainActor
@Observable
final class AppearanceManager {
    private enum Keys {
        static let palette = "com.dandelion.palette"
        static let style = "com.dandelion.style"
    }

    var palette: DandelionPalette {
        didSet {
            UserDefaults.standard.set(palette.rawValue, forKey: Keys.palette)
        }
    }

    var style: DandelionStyle {
        didSet {
            UserDefaults.standard.set(style.rawValue, forKey: Keys.style)
        }
    }

    var theme: DandelionTheme {
        Self.theme(for: palette)
    }

    /// The appropriate color scheme for system UI elements based on the current palette
    var colorScheme: ColorScheme {
        switch palette {
        case .dawn:
            return .light
        case .dark, .twilight, .forest:
            return .dark
        }
    }

    static func theme(for palette: DandelionPalette) -> DandelionTheme {
        switch palette {
        case .dark:
            return DandelionTheme(
                background: Color(red: 0, green: 0, blue: 0),
                card: Color(red: 0.11, green: 0.11, blue: 0.12),
                primary: Color(red: 0.98, green: 0.93, blue: 0.75),
                accent: Color(red: 0.85, green: 0.75, blue: 0.45),
                text: Color(red: 0.98, green: 0.93, blue: 0.75),
                secondary: Color(red: 0.55, green: 0.53, blue: 0.50),
                subtle: Color(red: 0.22, green: 0.22, blue: 0.23),
                pappus: Color(red: 0.97, green: 0.95, blue: 0.90)
            )
        case .dawn:
            return DandelionTheme(
                background: Color(red: 0.97, green: 0.94, blue: 0.91),
                card: Color(red: 1.0, green: 0.98, blue: 0.96),
                primary: Color(red: 0.62, green: 0.44, blue: 0.36),
                accent: Color(red: 0.78, green: 0.54, blue: 0.46),
                text: Color(red: 0.36, green: 0.24, blue: 0.20),
                secondary: Color(red: 0.55, green: 0.38, blue: 0.34),
                subtle: Color(red: 0.85, green: 0.76, blue: 0.72),
                pappus: Color(red: 0.70, green: 0.56, blue: 0.50)
            )
        case .twilight:
            return DandelionTheme(
                background: Color(red: 0.10, green: 0.09, blue: 0.16),
                card: Color(red: 0.16, green: 0.15, blue: 0.24),
                primary: Color(red: 0.80, green: 0.78, blue: 0.92),
                accent: Color(red: 0.70, green: 0.70, blue: 0.80),
                text: Color(red: 0.92, green: 0.90, blue: 0.97),
                secondary: Color(red: 0.62, green: 0.60, blue: 0.72),
                subtle: Color(red: 0.26, green: 0.24, blue: 0.34),
                pappus: Color(red: 0.93, green: 0.92, blue: 0.98)
            )
        case .forest:
            return DandelionTheme(
                background: Color(red: 0.07, green: 0.10, blue: 0.07),
                card: Color(red: 0.13, green: 0.17, blue: 0.13),
                primary: Color(red: 0.80, green: 0.86, blue: 0.72),
                accent: Color(red: 0.54, green: 0.70, blue: 0.48),
                text: Color(red: 0.90, green: 0.94, blue: 0.86),
                secondary: Color(red: 0.58, green: 0.64, blue: 0.54),
                subtle: Color(red: 0.22, green: 0.28, blue: 0.22),
                pappus: Color(red: 0.92, green: 0.95, blue: 0.88)
            )
        }
    }

    init() {
        if let rawPalette = UserDefaults.standard.string(forKey: Keys.palette),
           let palette = DandelionPalette(rawValue: rawPalette) {
            self.palette = palette
        } else {
            self.palette = .dark
        }

        if let rawStyle = UserDefaults.standard.string(forKey: Keys.style),
           let style = DandelionStyle(rawValue: rawStyle) {
            self.style = style
        } else {
            self.style = .procedural
        }
    }
}
