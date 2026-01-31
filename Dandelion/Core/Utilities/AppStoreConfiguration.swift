//
//  AppStoreConfiguration.swift
//  Dandelion
//
//  App Store IDs and URLs for sharing/rating.
//

import Foundation

enum AppStoreConfiguration {
    static var appStoreID: String? {
        if let infoValue = Bundle.main.object(forInfoDictionaryKey: "AppStoreID") as? String,
           !infoValue.isEmpty {
            return infoValue
        }

        return nil
    }

    static var appStoreURL: URL? {
        guard let appStoreID, !appStoreID.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)")
    }

    static var reviewURL: URL? {
        guard let appStoreID, !appStoreID.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    static var shareMessage: String {
        let baseMessage = "Check out Dandelion — a mindful writing app for letting go."
        guard let appStoreURL else { return baseMessage }
        return "\(baseMessage) \(appStoreURL.absoluteString)"
    }
}
