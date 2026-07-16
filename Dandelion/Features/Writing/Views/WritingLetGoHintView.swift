//
//  WritingLetGoHintView.swift
//  Dandelion
//
//  First-run / help overlay explaining how to release writing.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct WritingLetGoHintView: View {
    @Environment(AppearanceManager.self) private var appearance
    @Environment(\.openURL) private var openURL

    let permissionDetermined: Bool
    let hasMicrophonePermission: Bool
    let onRequestMicrophone: () -> Void
    let onDismiss: () -> Void

    private var theme: DandelionTheme { appearance.theme }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        onDismiss()
                    }
                }

            VStack(spacing: DandelionSpacing.lg) {
                Text("When you're ready,\nlet go")
                    .font(.system(size: 26, weight: .medium, design: .serif))
                    .foregroundColor(theme.text)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                VStack(alignment: .leading, spacing: DandelionSpacing.md) {
                    HStack(alignment: .top, spacing: DandelionSpacing.sm) {
                        Image(systemName: "wind")
                            .font(.system(size: 16))
                            .foregroundColor(theme.accent)
                            .frame(width: 20)
                        Text("Tap **Let Go** or blow gently into the microphone.")
                            .font(.system(size: 16, design: .serif))
                            .foregroundColor(theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(alignment: .top, spacing: DandelionSpacing.sm) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(theme.accent)
                            .frame(width: 20)
                        Text("Your words will drift away—never saved, never shared.")
                            .font(.system(size: 16, design: .serif))
                            .foregroundColor(theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if permissionDetermined && !hasMicrophonePermission {
                    HStack(spacing: 4) {
                        Text("Microphone is off.")
                        Button("Open Settings") {
                            openAppSettings()
                        }
                        .foregroundColor(theme.accent)
                        .buttonStyle(.plain)
                    }
                    .font(.system(size: 13, design: .serif))
                    .foregroundColor(theme.secondary)
                } else if !permissionDetermined {
                    HStack(spacing: 4) {
                        Text("Microphone required to blow.")
                        Button("Enable") {
                            onRequestMicrophone()
                        }
                        .foregroundColor(theme.accent)
                        .buttonStyle(.plain)
                    }
                    .font(.system(size: 13, design: .serif))
                    .foregroundColor(theme.secondary)
                }

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        onDismiss()
                    }
                } label: {
                    Text("Got it")
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .foregroundColor(theme.background)
                        .padding(.horizontal, DandelionSpacing.xl)
                        .padding(.vertical, DandelionSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(theme.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Got it")
                .accessibilityHint("Dismiss this help dialog")
            }
            .padding(.horizontal, DandelionSpacing.xl)
            .padding(.vertical, DandelionSpacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.card)
            )
            .frame(maxWidth: 340)
            .padding(.horizontal, DandelionSpacing.lg)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityLabel("How to let go of your writing")
        }
        .transition(.opacity)
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
