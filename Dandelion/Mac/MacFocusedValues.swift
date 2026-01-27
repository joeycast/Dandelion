//
//  MacFocusedValues.swift
//  Dandelion
//
//  FocusedValue keys for bridging panel toggle actions to Commands.
//

import SwiftUI

#if os(macOS)
/// Panel types for the inspector sidebar
enum MacPanelType: Equatable {
    case history
    case insights
}

/// Key for passing panel toggle actions from views to Commands.
struct TogglePanelActionKey: FocusedValueKey {
    typealias Value = (MacPanelType) -> Void
}

extension FocusedValues {
    var togglePanelAction: TogglePanelActionKey.Value? {
        get { self[TogglePanelActionKey.self] }
        set { self[TogglePanelActionKey.self] = newValue }
    }
}
#endif
