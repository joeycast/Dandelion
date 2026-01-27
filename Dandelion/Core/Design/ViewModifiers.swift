//
//  ViewModifiers.swift
//  Dandelion
//
//  Reusable view modifiers for consistent styling across the app.
//

import SwiftUI

/// Applies liquid glass effect to toolbar buttons on iOS 26+/macOS 26+.
/// Falls back to standard appearance on older systems.
struct LiquidGlassToolbarButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(.regular.interactive())
        } else {
            content
        }
    }
}
