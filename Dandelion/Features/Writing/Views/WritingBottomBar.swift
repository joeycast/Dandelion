//
//  WritingBottomBar.swift
//  Dandelion
//
//  Writing-state bottom chrome: blow progress, ambient toggle, Let Go.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct WritingBottomBar: View {
    @Environment(AppearanceManager.self) private var appearance
    @Environment(PremiumManager.self) private var premium
    @Environment(AmbientSoundService.self) private var ambientSound
    @Environment(\.openURL) private var openURL

    let isWriting: Bool
    let isReleasing: Bool
    let isTextEditorFocused: Bool
    let bottomInset: CGFloat
    let canRelease: Bool
    let showBlowIndicator: Bool
    let blowDetection: BlowDetectionService
    let onShowHelp: () -> Void
    let onLetGo: () -> Void
    let onAmbientChanged: () -> Void
    let onShowPaywall: () -> Void
    let onRequestMicrophone: () -> Void

    private var theme: DandelionTheme { appearance.theme }

    var body: some View {
        VStack(spacing: 0) {
            // Single blow cue: progress label flips to "Keep blowing…" (no extra chip).
            if isWriting && blowDetection.isEnabled {
                Group {
                    if blowDetection.hasPermission {
                        blowProgressBar
                    } else {
                        WritingMicrophoneStatusView(
                            permissionDetermined: blowDetection.permissionDetermined,
                            hasPermission: blowDetection.hasPermission,
                            onRequestPermission: onRequestMicrophone
                        )
                    }
                }
                .padding(.bottom, DandelionSpacing.md)
                .animation(.easeOut(duration: 0.2), value: showBlowIndicator)
                .animation(.easeOut(duration: 0.2), value: blowDetection.hasPermission)
            }

            ZStack {
                theme.background
                    .ignoresSafeArea(edges: .bottom)

                HStack(spacing: DandelionSpacing.md) {
                    ambientToggleButton

                    Spacer()

                    Button(action: onShowHelp) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 20))
                            .foregroundColor(theme.secondary)
                    }
                    .accessibilityLabel("Help")
                    .accessibilityHint("Learn how to release your writing")
#if os(macOS)
                    .buttonStyle(.plain)
#endif

                    Button(action: onLetGo) {
                        HStack(spacing: 6) {
                            Image(systemName: "wind")
                                .font(.system(size: 15))
                            Text("Let Go")
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                        }
                        .foregroundColor(theme.background)
                        .padding(.horizontal, DandelionSpacing.md)
                        .padding(.vertical, DandelionSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(theme.primary)
                        )
                    }
                    .accessibilityLabel("Let Go")
                    .accessibilityHint("Release your writing and watch it drift away like dandelion seeds")
                    .accessibilityAddTraits(canRelease ? [] : .isStaticText)
                    .disabled(!canRelease)
                    .opacity(canRelease ? 1.0 : 0.5)
#if os(macOS)
                    .buttonStyle(.plain)
#endif
                }
                .padding(.horizontal, DandelionSpacing.md)
                .opacity(isWriting ? 1 : 0)
            }
            .frame(height: 56)
            .padding(.bottom, isTextEditorFocused ? DandelionSpacing.sm : bottomInset)
            .animation(nil, value: isTextEditorFocused)
        }
        .opacity((isWriting || isReleasing) ? 1 : 0)
        .allowsHitTesting(isWriting)
    }

    private var blowProgressBar: some View {
        let progress = CGFloat(max(0, min(1, blowDetection.blowProgress)))
        let label = showBlowIndicator ? "Keep blowing…" : "Blow to release"
        return VStack(spacing: DandelionSpacing.xs) {
            Text(label)
                .font(.dandelionSecondary)
                .foregroundColor(theme.secondary)
                .accessibilityLabel(
                    showBlowIndicator
                        ? "Keep blowing into the microphone to release your writing"
                        : "Blow to release"
                )

            GeometryReader { geometry in
                let width = max(0, geometry.size.width)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.primary.opacity(0.2))
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: width * progress)
                        .animation(.easeOut(duration: 0.15), value: progress)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: 240)
        .opacity(progress > 0 || showBlowIndicator ? 1 : 0.6)
        .transition(.opacity)
        .accessibilityLabel("Blow progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }

    private var ambientToggleButton: some View {
        Button {
            if premium.isBloomUnlocked {
                ambientSound.isEnabled.toggle()
                onAmbientChanged()
            } else {
                onShowPaywall()
            }
        } label: {
            Image(systemName: ambientSound.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(premium.isBloomUnlocked ? theme.secondary : theme.subtle)
        }
        .accessibilityLabel("Ambient sound")
        .accessibilityValue(ambientSound.isEnabled ? "On" : "Off")
        .accessibilityHint(
            premium.isBloomUnlocked
                ? "Toggle calming background sounds"
                : "Unlock Dandelion Bloom for ambient sounds"
        )
        .buttonStyle(.plain)
    }
}

/// Mic enable / denied status used by writing chrome (and progressive-blow PR).
struct WritingMicrophoneStatusView: View {
    @Environment(AppearanceManager.self) private var appearance
    @Environment(\.openURL) private var openURL

    let permissionDetermined: Bool
    let hasPermission: Bool
    let onRequestPermission: () -> Void

    private var theme: DandelionTheme { appearance.theme }

    var body: some View {
        if !permissionDetermined {
            Button(action: onRequestPermission) {
                HStack(spacing: DandelionSpacing.xs) {
                    Image(systemName: "mic")
                    Text("Enable blow")
                }
                .font(.dandelionCaption)
                .foregroundColor(theme.secondary)
            }
        } else if hasPermission {
            HStack(spacing: 4) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 11))
                    .foregroundColor(theme.accent)
                Text("Or blow gently into your microphone")
                    .font(.system(size: 13))
                    .foregroundColor(theme.secondary)
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "mic.slash")
                    .font(.system(size: 11))
                    .foregroundColor(theme.secondary)
                Text("Microphone access is off.")
                    .font(.system(size: 13))
                    .foregroundColor(theme.secondary)
                Button("Open Settings") {
                    openAppSettings()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.accent)
                .buttonStyle(.plain)
            }
        }
    }

    private func openAppSettings() {
#if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
#elseif os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            openURL(url)
        }
#endif
    }
}
