//
//  AppStoreConfiguration.swift
//  Dandelion
//
//  App Store IDs and URLs for sharing/rating.
//

import Foundation

enum AppStoreConfiguration {
    struct ExternalAppLink: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let url: URL
    }

    static var iosAppStoreID: String? {
        nonEmptyInfoString(forKey: "iOSAppStoreID")
    }

    static var macAppStoreID: String? {
        nonEmptyInfoString(forKey: "MacAppStoreID")
    }

    static var appStoreID: String? {
        nonEmptyInfoString(forKey: "AppStoreID")
    }

    static var appStoreURL: URL? {
        guard let appStoreID, !appStoreID.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)")
    }

    static var reviewURL: URL? {
        guard let appStoreID, !appStoreID.isEmpty else { return nil }
#if os(iOS)
        return URL(string: "itms-apps://itunes.apple.com/app/id\(appStoreID)?action=write-review")
#elseif os(macOS)
        return URL(string: "macappstore://itunes.apple.com/app/id\(appStoreID)?action=write-review")
#else
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
#endif
    }

    static var macDownloadLandingURL: URL? {
        infoURL(forKey: "MacDownloadLandingURL")
    }

    static var shareMessage: String {
        let baseMessage = "Check out Dandelion — a mindful writing app for letting go."
        guard let appStoreURL else { return baseMessage }
        return "\(baseMessage) \(appStoreURL.absoluteString)"
    }

    static var moreFromBrink13Labs: [ExternalAppLink] {
        [
            ExternalAppLink(
                id: "movemates",
                title: "Movemates: Move Together",
                symbol: "figure.run",
                url: URL(string: "https://apps.apple.com/us/app/movemates-move-together/id6748308903")!
            ),
            ExternalAppLink(
                id: "bitlocal",
                title: "BitLocal: BTC-Friendly Shops",
                symbol: "bitcoinsign.circle",
                url: URL(string: "https://apps.apple.com/us/app/bitlocal-btc-friendly-shops/id6447485666")!
            ),
            ExternalAppLink(
                id: "bitcoin-live-price-chart-tv",
                title: "Bitcoin Live Price Chart for Apple TV",
                symbol: "chart.line.uptrend.xyaxis",
                url: URL(string: "https://brink13labs.com")!
            )
        ]
    }

    static func nonEmptyInfoString(
        forKey key: String,
        in infoDictionary: [String: Any]? = Bundle.main.infoDictionary
    ) -> String? {
        guard
            let value = infoDictionary?[key] as? String,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        return value
    }

    static func infoURL(
        forKey key: String,
        in infoDictionary: [String: Any]? = Bundle.main.infoDictionary
    ) -> URL? {
        guard let value = nonEmptyInfoString(forKey: key, in: infoDictionary) else {
            return nil
        }

        guard let url = URL(string: value) else {
            return nil
        }

        guard
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            url.host?.isEmpty == false
        else {
            return nil
        }

        return url
    }
}
