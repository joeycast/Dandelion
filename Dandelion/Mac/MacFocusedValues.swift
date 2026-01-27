//
//  MacFocusedValues.swift
//  Dandelion
//
//  FocusedValue keys for bridging window-opening actions to Commands.
//

import SwiftUI

#if os(macOS)
/// Key for passing window-opening actions from views to Commands.
/// This is needed because Commands don't have direct access to @Environment(\.openWindow).
struct OpenWindowActionKey: FocusedValueKey {
    typealias Value = (String) -> Void
}

extension FocusedValues {
    var openWindowAction: OpenWindowActionKey.Value? {
        get { self[OpenWindowActionKey.self] }
        set { self[OpenWindowActionKey.self] = newValue }
    }
}
#endif
