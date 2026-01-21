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
    @Environment(AppearanceManager.self) private var appearance

    var body: some View {
        let theme = appearance.theme
        VStack(spacing: DandelionSpacing.xs) {
            Text("\(value)")
                .font(.system(size: 36, weight: .light, design: .serif))
                .foregroundColor(theme.primary)

            Text(label)
                .font(.dandelionCaption)
                .foregroundColor(theme.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DandelionSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.primary.opacity(0.08))
        )
    }
}

#Preview {
    HStack(spacing: DandelionSpacing.lg) {
        StatBox(value: 42, label: "Day Streak")
        StatBox(value: 156, label: "This Year")
    }
    .padding()
    .background(AppearanceManager().theme.background)
    .environment(AppearanceManager())
}
