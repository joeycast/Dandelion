//
//  BloomLockedCard.swift
//  Dandelion
//
//  Reusable Bloom lockup for gated features
//

import SwiftUI

struct BloomLockedCard: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let isCompact: Bool
    let action: () -> Void

    @Environment(AppearanceManager.self) private var appearance

    init(
        title: String,
        subtitle: String,
        buttonTitle: String = "Unlock Dandelion Bloom",
        isCompact: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
        self.isCompact = isCompact
        self.action = action
    }

    var body: some View {
        let theme = appearance.theme
        let iconSize: CGFloat = isCompact ? 18 : 26
        let titleFont: Font = isCompact
            ? .system(size: 22, weight: .semibold, design: .serif)
            : .dandelionTitle
        let verticalPadding: CGFloat = isCompact ? DandelionSpacing.lg : DandelionSpacing.xl
        let spacing: CGFloat = isCompact ? DandelionSpacing.sm : DandelionSpacing.md

        VStack(spacing: spacing) {
            Image(systemName: "lock.fill")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(theme.secondary)

            Text(title)
                .font(titleFont)
                .foregroundColor(theme.text)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.dandelionCaption)
                .foregroundColor(theme.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DandelionSpacing.lg)

            Button(buttonTitle) {
                action()
            }
            .buttonStyle(.dandelion)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.subtle, lineWidth: 1)
        )
    }
}
