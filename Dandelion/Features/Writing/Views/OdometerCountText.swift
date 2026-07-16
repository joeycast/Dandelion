//
//  OdometerCountText.swift
//  Dandelion
//
//  Formatted numeric count with odometer-style transitions.
//

import SwiftUI

struct OdometerCountText: View {
    let value: Int

    var body: some View {
        Text(Self.formatted(value))
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(value)))
            .animation(.easeInOut(duration: 0.8), value: value)
    }

    static func formatted(_ value: Int) -> String {
        countFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let countFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}
