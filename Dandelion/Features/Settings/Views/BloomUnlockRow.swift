//
//  BloomUnlockRow.swift
//  Dandelion
//
//  Bloom unlock row for Settings
//

import SwiftUI

struct BloomUnlockRow: View {
    let action: () -> Void
    @Environment(AppearanceManager.self) private var appearance
    @State private var isGlowing = false

    var body: some View {
        let theme = appearance.theme

        Button(action: action) {
            HStack(spacing: DandelionSpacing.md) {
                // Icon with glow effect
                ZStack {
                    // Glow background
                    Circle()
                        .fill(theme.accent.opacity(isGlowing ? 0.3 : 0.15))
                        .frame(width: 40, height: 40)
                        .blur(radius: isGlowing ? 8 : 4)

                    // Icon
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(theme.accent)
                }
                .frame(width: 40, height: 40)

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock Dandelion Bloom")
                        .font(.system(size: 20, weight: .medium, design: .serif))
                        .foregroundColor(theme.text)

                    Text("The full Dandelion experience")
                        .font(.system(size: 16, design: .serif))
                        .foregroundColor(theme.secondary)
                }

                Spacer()

//                // Chevron
//                Image(systemName: "chevron.right")
//                    .font(.system(size: 14, weight: .semibold))
//                    .foregroundColor(theme.accent)
            }
            .padding(.horizontal, DandelionSpacing.md)
            .padding(.vertical, DandelionSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.accent.opacity(0.15),
                                theme.accent.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.accent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
    BloomUnlockRow(action: {})
        .padding()
        .background(Color.black)
        .environment(AppearanceManager())
}
