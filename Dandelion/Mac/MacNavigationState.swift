//
//  MacNavigationState.swift
//  Dandelion
//
//  Shared navigation state for macOS-only UI.
//

import SwiftUI

#if os(macOS)
@MainActor
@Observable
final class MacNavigationState {
    enum Destination: Hashable {
        case writing
        case history
        case insights
    }

    var selection: Destination = .writing
}
#endif
