//
//  StatBox.swift
//  Dandelion
//
//  Stats display component for release history
//

import SwiftUI

struct StatBox: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: DandelionSpacing.xs) {
            Text("\(value)")
                .font(.system(size: 36, weight: .light, design: .serif))
                .foregroundColor(.dandelionPrimary)

            Text(label)
                .font(.dandelionCaption)
                .foregroundColor(.dandelionSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DandelionSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dandelionPrimary.opacity(0.08))
        )
    }
}

#Preview {
    HStack(spacing: DandelionSpacing.lg) {
        StatBox(value: 42, label: "Day Streak")
        StatBox(value: 156, label: "This Year")
    }
    .padding()
    .background(Color.dandelionBackground)
}
