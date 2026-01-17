//
//  Platform.swift
//  Dandelion
//
//  Cross-platform UIKit/AppKit typealiases used by shared SwiftUI code.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

typealias PlatformFont = UIFont
typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit

typealias PlatformFont = NSFont
typealias PlatformColor = NSColor

extension NSFont {
    var lineHeight: CGFloat {
        ascender - descender + leading
    }
}
#endif

