//
//  AppearanceSettingsView.swift
//  Dandelion
//
//  Bloom appearance customization
//

import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(AppearanceManager.self) private var appearance
    @Environment(PremiumManager.self) private var premium

    @State private var showPaywall: Bool = false

    var body: some View {
        let theme = appearance.theme

        List {
            Section {
                ForEach(DandelionPalette.allCases) { palette in
                    Button {
                        selectPalette(palette)
                    } label: {
                        PaletteRow(palette: palette, isSelected: appearance.palette == palette)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.card)
                }
            } header: {
                Text("Color Palette")
                    .foregroundColor(theme.secondary)
            }

            Section {
                ForEach(DandelionStyle.allCases) { style in
                    Button {
                        selectStyle(style)
                    } label: {
                        HStack {
                            Text(style.displayName)
                                .foregroundColor(theme.text)
                            Spacer()
                            if appearance.style == style {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(theme.accent)
                            } else if isStyleLocked(style) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.card)
                }
            } header: {
                Text("Dandelion Style")
                    .foregroundColor(theme.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.primary)
        .toolbarBackground(theme.background, for: .navigationBar)
        .toolbarColorScheme(appearance.colorScheme, for: .navigationBar)
        .sheet(isPresented: $showPaywall) {
            BloomPaywallView(onClose: { showPaywall = false })
        }
    }

    private func selectPalette(_ palette: DandelionPalette) {
        if palette == .dark || premium.isBloomUnlocked {
            withAnimation(.easeInOut(duration: 0.3)) {
                appearance.palette = palette
            }
        } else {
            showPaywall = true
        }
    }

    private func selectStyle(_ style: DandelionStyle) {
        if style == .procedural || premium.isBloomUnlocked {
            appearance.style = style
        } else {
            showPaywall = true
        }
    }

    private func isStyleLocked(_ style: DandelionStyle) -> Bool {
        !premium.isBloomUnlocked && style != .procedural
    }
}

private struct PaletteRow: View {
    let palette: DandelionPalette
    let isSelected: Bool
    @Environment(AppearanceManager.self) private var appearance
    @Environment(PremiumManager.self) private var premium

    var body: some View {
        let theme = appearance.theme
        let previewTheme = AppearanceManager.theme(for: palette)
        let isLocked = palette != .dark && !premium.isBloomUnlocked

        HStack(spacing: DandelionSpacing.md) {
            // Color preview chip
            HStack(spacing: 0) {
                Rectangle().fill(previewTheme.background)
                Rectangle().fill(previewTheme.card)
                Rectangle().fill(previewTheme.primary)
            }
            .frame(width: 48, height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(theme.subtle, lineWidth: 1)
            )

            Text(palette.displayName)
                .foregroundColor(theme.text)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.accent)
            } else if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
    .environment(PremiumManager.shared)
    .environment(AppearanceManager())
}
