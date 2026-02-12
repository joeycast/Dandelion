//
//  AppStoreConfiguration.swift
//  Dandelion
//
//  App Store IDs and URLs for sharing/rating.
//

import Foundation

enum AppStoreConfiguration {
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
