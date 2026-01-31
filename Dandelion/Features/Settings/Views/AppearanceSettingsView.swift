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
#if os(macOS)
        appearanceForm
#else
        appearanceList
#endif
    }

#if os(macOS)
    private var appearanceForm: some View {
        let reduceMotionBinding = Binding<Bool>(
            get: { !appearance.isWindAnimationEnabled },
            set: { appearance.isWindAnimationEnabled = !$0 }
        )
        return Form {
            Section {
                ForEach(DandelionPalette.allCases) { palette in
                    Button {
                        selectPalette(palette)
                    } label: {
                        MacPaletteRow(palette: palette, isSelected: appearance.palette == palette)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Color Palette")
            } footer: {
                if !premium.isBloomUnlocked {
                    Text("Custom palettes included with Dandelion Bloom.")
                }
            }

            Section {
                Toggle(isOn: reduceMotionBinding) {
                    Text("Reduce Motion")
                }
            } header: {
                Text("Motion")
            } footer: {
                Text("Disables the dandelion wind animation to reduce motion and battery usage. Automatically enabled when system Reduce Motion or Low Power Mode is on.")
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showPaywall) {
            BloomPaywallView(onClose: { showPaywall = false })
        }
    }
#endif

    private var appearanceList: some View {
        let theme = appearance.theme
        let reduceMotionBinding = Binding<Bool>(
            get: { !appearance.isWindAnimationEnabled },
            set: { appearance.isWindAnimationEnabled = !$0 }
        )

        return List {
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
            } footer: {
                if !premium.isBloomUnlocked {
                    (Text("Custom palettes included with ") +
                    Text("Dandelion Bloom")
                        .foregroundColor(theme.accent) +
                    Text("."))
                    .onTapGesture { showPaywall = true }
                }
            }

            Section {
                Toggle(isOn: reduceMotionBinding) {
                    Text("Reduce Motion")
                        .foregroundColor(theme.text)
                }
                .toggleStyle(SwitchToggleStyle(tint: theme.accent))
                .listRowBackground(theme.card)
            } header: {
                Text("Motion")
                    .foregroundColor(theme.secondary)
            } footer: {
                Text("Disables the dandelion wind animation to reduce motion and battery usage. Automatically enabled when system Reduce Motion or Low Power Mode is on.")
            }
        }
        .dandelionListStyle()
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .navigationTitle("Appearance")
        .dandelionNavigationBarStyle(background: theme.background, colorScheme: appearance.colorScheme)
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

#if os(macOS)
private struct MacPaletteRow: View {
    let palette: DandelionPalette
    let isSelected: Bool
    @Environment(PremiumManager.self) private var premium

    var body: some View {
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
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )

            Text(palette.displayName)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)
            } else if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}
#endif

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
