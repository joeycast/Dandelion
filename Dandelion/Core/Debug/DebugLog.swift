//
//  DebugLog.swift
//  Dandelion
//
//  Lightweight debug logging utility
//

import Foundation

/// Prints debug logs only in DEBUG builds.
func debugLog(_ message: String) {
#if DEBUG
    print(message)
#endif
}
