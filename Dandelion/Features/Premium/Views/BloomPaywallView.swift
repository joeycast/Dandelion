//
//  BloomPaywallView.swift
//  Dandelion
//
//  Premium upgrade screen for Dandelion Bloom
//

import SwiftUI

struct BloomPaywallView: View {
    let title: String
    let subtitle: String
    let bodyText: String?
    let showsClose: Bool
    let onClose: (() -> Void)?

    @Environment(PremiumManager.self) private var premium
    @Environment(AppearanceManager.self) private var appearance

    @State private var showError: Bool = false

    init(
        title: String = "Dandelion Bloom",
        subtitle: String = "Grow your practice",
        bodyText: String? = nil,
        showsClose: Bool = true,
        onClose: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.bodyText = bodyText
        self.showsClose = showsClose
        self.onClose = onClose
    }

    var body: some View {
        let theme = appearance.theme

        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                // Dandelion illustration
                DandelionBloomView(
                    seedCount: 90,
                    filamentsPerSeed: 16,
                    windStrength: 0.5,
                    style: appearance.style
                )
                .frame(height: 160)

                // Title
                VStack(spacing: DandelionSpacing.xs) {
                    Text(title)
                        .font(.system(size: 32, weight: .semibold, design: .serif))
                        .foregroundColor(theme.text)

                    Text(subtitle)
                        .font(.dandelionSecondary)
                        .foregroundColor(theme.secondary)
                }
                .padding(.top, DandelionSpacing.sm)

                // Optional body text
                if let bodyText {
                    Text(bodyText)
                        .font(.dandelionCaption)
                        .foregroundColor(theme.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DandelionSpacing.xl)
                        .padding(.top, DandelionSpacing.sm)
                }

                // Features list
                VStack(spacing: 0) {
                    FeatureRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Insights",
                        description: "Track streaks, trends, and patterns in your release history"
                    )
                    FeatureRow(
                        icon: "text.quote",
                        title: "Custom Prompts",
                        description: "Create your own prompts and customize which ones appear"
                    )
                    FeatureRow(
                        icon: "paintpalette",
                        title: "Color Palettes",
                        description: "Dawn, Twilight, and Forest themes to match your mood"
                    )
                    FeatureRow(
                        icon: "speaker.wave.2",
                        title: "Ambient Sounds",
                        description: "Calming soundscapes to accompany your writing"
                    )
                    FeatureRow(
                        icon: "app.badge",
                        title: "App Icons",
                        description: "Choose from alternate icons to personalize your home screen"
                    )
                    FeatureRow(
                        icon: "square.and.arrow.up",
                        title: "Export",
                        description: "Share or export your release history"
                    )
                }
                .padding(.top, DandelionSpacing.lg)
                .padding(.horizontal, DandelionSpacing.lg)

                // Privacy note
                HStack(spacing: DandelionSpacing.sm) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 16))
                        .foregroundColor(theme.secondary)

                    Text("Your words stay with you. We never store what you write—only dates and counts, saved locally and in iCloud.")
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, DandelionSpacing.lg)
                .padding(.horizontal, DandelionSpacing.xl)

                // Purchase section
                VStack(spacing: DandelionSpacing.md) {
                    // Pricing card
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lifetime Access")
                                .font(.system(size: 18, weight: .medium, design: .serif))
                                .foregroundColor(theme.text)
                            Text("Pay once, yours forever")
                                .font(.dandelionCaption)
                                .foregroundColor(theme.secondary)
                        }

                        Spacer()

                        Text(premium.priceDisplay)
                            .font(.system(size: 28, weight: .semibold, design: .serif))
                            .foregroundColor(theme.text)
                    }
                    .padding(DandelionSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(theme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(theme.accent.opacity(0.5), lineWidth: 2)
                    )

                    Button {
                        Task { await premium.purchase() }
                    } label: {
                        HStack {
                            if premium.isLoading {
                                ProgressView()
                                    .tint(theme.background)
                            } else {
                                Text("Unlock Dandelion Bloom")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.dandelion)
                    .disabled(premium.isLoading)

                    Button("Restore Purchases") {
                        Task { await premium.restorePurchases() }
                    }
                    .font(.dandelionCaption)
                    .foregroundColor(theme.secondary)
                }
                .padding(.top, DandelionSpacing.xl)
                .padding(.horizontal, DandelionSpacing.lg)

                // Error message
                if let errorMessage = premium.errorMessage, showError {
                    Text(errorMessage)
                        .font(.dandelionCaption)
                        .foregroundColor(theme.accent)
                        .multilineTextAlignment(.center)
                        .padding(.top, DandelionSpacing.md)
                        .padding(.horizontal, DandelionSpacing.lg)
                }

                    Spacer(minLength: DandelionSpacing.xxl)
                }
            }
            .background(theme.background.ignoresSafeArea())
            .toolbar {
                if showsClose {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            onClose?()
                        }
                    }
                }
            }
            .onAppear {
                Task { await premium.refreshEntitlement() }
            }
            .onChange(of: premium.errorMessage) { _, newValue in
                showError = newValue != nil
            }
        }
        .toolbar(showsClose ? .visible : .hidden, for: .navigationBar)
        .toolbarBackground(theme.background, for: .navigationBar)
        .toolbarColorScheme(appearance.colorScheme, for: .navigationBar)
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    @Environment(AppearanceManager.self) private var appearance

    var body: some View {
        let theme = appearance.theme

        HStack(alignment: .top, spacing: DandelionSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(theme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundColor(theme.text)

                Text(description)
                    .font(.dandelionCaption)
                    .foregroundColor(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.vertical, DandelionSpacing.sm)
    }
}

#Preview {
    BloomPaywallView()
        .environment(PremiumManager.shared)
        .environment(AppearanceManager())
}
