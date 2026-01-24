//
//  BloomUnlockCallout.swift
//  Dandelion
//
//  Bloom upgrade callout styled after BloomUnlockRow
//

import SwiftUI

struct BloomUnlockCallout: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let action: () -> Void

    @Environment(AppearanceManager.self) private var appearance
    @State private var isGlowing = false

    init(
        title: String,
        subtitle: String,
        buttonTitle: String = "Unlock Dandelion Bloom",
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
        self.action = action
    }

    var body: some View {
        let theme = appearance.theme
        let iconSize: CGFloat = 44

        VStack(spacing: DandelionSpacing.md) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(isGlowing ? 0.3 : 0.15))
                    .frame(width: iconSize, height: iconSize)
                    .blur(radius: isGlowing ? 8 : 4)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(theme.accent)
            }
            .frame(width: iconSize, height: iconSize)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundColor(theme.text)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.dandelionSecondary)
                    .foregroundColor(theme.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(buttonTitle) {
                action()
            }
            .buttonStyle(.dandelion)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(DandelionSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.accent.opacity(0.18),
                            theme.accent.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.accent.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                isGlowing = true
            }
        }
    }
}

#Preview {
    BloomUnlockCallout(
        title: "Discover your patterns",
        subtitle: "Unlock Bloom to see trends, streaks, and insights about your writing journey.",
        action: {}
    )
    .padding()
    .background(Color.black)
    .environment(AppearanceManager())
}
