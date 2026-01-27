//
//  MacCommands.swift
//  Dandelion
//
//  Native macOS menu commands.
//

import SwiftUI

#if os(macOS)
struct MacCommands: Commands {
    @Environment(\.openSettings) private var openSettings
    @FocusedValue(\.openWindowAction) var openWindowAction

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandMenu("View") {
            Button("Show History") {
                openWindowAction?("history")
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            .disabled(openWindowAction == nil)

            Button("Show Insights") {
                openWindowAction?("insights")
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(openWindowAction == nil)
        }
    }
}
#endif
