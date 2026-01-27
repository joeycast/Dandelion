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
    @FocusedValue(\.togglePanelAction) var togglePanelAction

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandMenu("View") {
            Button("Toggle History") {
                togglePanelAction?(.history)
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            .disabled(togglePanelAction == nil)

            Button("Toggle Insights") {
                togglePanelAction?(.insights)
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(togglePanelAction == nil)
        }
    }
}
#endif
