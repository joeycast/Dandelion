//
//  SettingsFooterView.swift
//  Dandelion
//

import SwiftUI

struct SettingsFooterView: View {
    @Environment(AppearanceManager.self) private var appearance
    let useThemeColors: Bool
    let useAppFont: Bool
    let usePrimaryColor: Bool
    let alignment: HorizontalAlignment
    let textAlignment: TextAlignment
    let useSmallText: Bool

    init(
        useThemeColors: Bool = true,
        useAppFont: Bool = true,
        usePrimaryColor: Bool = false,
        alignment: HorizontalAlignment = .leading,
        textAlignment: TextAlignment = .leading,
        useSmallText: Bool = false
    ) {
        self.useThemeColors = useThemeColors
        self.useAppFont = useAppFont
        self.usePrimaryColor = usePrimaryColor
        self.alignment = alignment
        self.textAlignment = textAlignment
        self.useSmallText = useSmallText
    }

    var body: some View {
        let theme = appearance.theme
        let baseColor: Color = {
            if usePrimaryColor {
                return useThemeColors ? theme.text : .primary
            }
            return useThemeColors ? theme.secondary : .secondary
        }()
        let accentColor: Color = useThemeColors ? theme.accent : .accentColor

        VStack(alignment: alignment, spacing: DandelionSpacing.xs) {
            let versionView = Text(versionText)
                .foregroundColor(baseColor)

            let attributionView = Text(
                .init("Made with love by [Brink 13 Labs, LLC](https://brink13labs.com/) in Nashville, TN.")
            )
            .foregroundColor(baseColor)
            .tint(accentColor)

            if useAppFont {
                if useSmallText {
                    versionView.font(.caption)
                    attributionView.font(.caption)
                } else {
                    versionView.font(.dandelionSecondary)
                    attributionView.font(.dandelionSecondary)
                }
            } else {
                if useSmallText {
                    versionView.font(.caption)
                    attributionView.font(.caption)
                } else {
                    versionView
                    attributionView
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
        .multilineTextAlignment(textAlignment)
    }

    private var versionText: String {
        let shortVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.0"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        if let buildNumber, !buildNumber.isEmpty, buildNumber != shortVersion {
            return "Version \(shortVersion) (\(buildNumber))"
        }

        return "Version \(shortVersion)"
    }
}

#Preview {
    SettingsFooterView()
        .environment(AppearanceManager())
}
