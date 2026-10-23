//
//  AppearanceManagerTests.swift
//  DandelionTests
//
//  Tests for palette, style, and animation preferences
//

import XCTest
import SwiftUI
@testable import Dandelion

@MainActor
final class AppearanceManagerTests: XCTestCase {
    private let keys = [
        "com.dandelion.palette",
        "com.dandelion.style",
        "com.dandelion.windAnimationEnabled"
    ]
    private var savedValues: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        for key in keys {
            savedValues[key] = UserDefaults.standard.object(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in keys {
            if let value = savedValues[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        savedValues = [:]
        super.tearDown()
    }

    func testDefaultsWhenNothingStored() {
        let manager = AppearanceManager()
        XCTAssertEqual(manager.palette, .dark)
        XCTAssertEqual(manager.style, .procedural)
        XCTAssertTrue(manager.isWindAnimationEnabled)
    }

    func testChangesPersistAcrossInstances() {
        let manager = AppearanceManager()
        manager.palette = .forest
        manager.style = .pencil
        manager.isWindAnimationEnabled = false

        let reloaded = AppearanceManager()
        XCTAssertEqual(reloaded.palette, .forest)
        XCTAssertEqual(reloaded.style, .pencil)
        XCTAssertFalse(reloaded.isWindAnimationEnabled)
    }

    func testUnknownStoredValuesFallBackToDefaults() {
        UserDefaults.standard.set("neon", forKey: "com.dandelion.palette")
        UserDefaults.standard.set("crayon", forKey: "com.dandelion.style")

        let manager = AppearanceManager()
        XCTAssertEqual(manager.palette, .dark)
        XCTAssertEqual(manager.style, .procedural)
    }

    func testOnlyDawnUsesLightColorScheme() {
        let manager = AppearanceManager()
        for palette in DandelionPalette.allCases {
            manager.palette = palette
            XCTAssertEqual(manager.colorScheme, palette == .dawn ? .light : .dark, "Unexpected scheme for \(palette)")
        }
    }

    func testThemeMatchesPalette() {
        let manager = AppearanceManager()
        for palette in DandelionPalette.allCases {
            manager.palette = palette
            XCTAssertEqual(manager.theme, AppearanceManager.theme(for: palette))
        }
    }

    func testEachPaletteHasADistinctTheme() {
        let palettes = DandelionPalette.allCases
        for (index, palette) in palettes.enumerated() {
            for other in palettes[(index + 1)...] {
                XCTAssertNotEqual(
                    AppearanceManager.theme(for: palette),
                    AppearanceManager.theme(for: other),
                    "\(palette) and \(other) should not share a theme"
                )
            }
        }
    }

    func testWindAnimationAllowedRespectsToggle() {
        let manager = AppearanceManager()
        manager.isWindAnimationEnabled = false
        XCTAssertFalse(manager.isWindAnimationAllowed, "Disabled wind animation should never be allowed")

        manager.isWindAnimationEnabled = true
        XCTAssertEqual(manager.isWindAnimationAllowed, !ProcessInfo.processInfo.isLowPowerModeEnabled)
    }

    func testDisplayNamesAreUnique() {
        XCTAssertEqual(Set(DandelionPalette.allCases.map(\.displayName)).count, DandelionPalette.allCases.count)
        XCTAssertEqual(Set(DandelionStyle.allCases.map(\.displayName)).count, DandelionStyle.allCases.count)
        XCTAssertEqual(DandelionPalette.dark.id, "dark")
        XCTAssertEqual(DandelionStyle.watercolor.id, "watercolor")
    }
}
