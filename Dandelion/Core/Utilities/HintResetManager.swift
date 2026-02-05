//
//  HintResetManager.swift
//  Dandelion
//
//  Manages automatic hint reset for returning users
//

import Foundation

struct HintResetManager {
    static let hasUsedPromptTapKey = "hasUsedPromptTap"
    static let hasSeenLetGoHintKey = "hasSeenLetGoHint"
    static let lastAppOpenDateKey = "lastAppOpenDate"
    static let resetThresholdSeconds: Double = 60 * 60 * 24 * 7 * 4 // 4 weeks

    let defaults: UserDefaults
    let currentDate: () -> Date

    init(defaults: UserDefaults = .standard, currentDate: @escaping () -> Date = { Date() }) {
        self.defaults = defaults
        self.currentDate = currentDate
    }

    /// Checks if user has been away for 4+ weeks and resets hints if so.
    /// Always updates the last open date.
    /// Returns true if hints were reset.
    @discardableResult
    func checkAndResetHintsIfNeeded() -> Bool {
        let now = currentDate().timeIntervalSince1970
        let lastOpen = defaults.double(forKey: Self.lastAppOpenDateKey)

        var didReset = false
        if lastOpen > 0 && (now - lastOpen) > Self.resetThresholdSeconds {
            defaults.set(false, forKey: Self.hasUsedPromptTapKey)
            defaults.set(false, forKey: Self.hasSeenLetGoHintKey)
            didReset = true
        }

        defaults.set(now, forKey: Self.lastAppOpenDateKey)
        return didReset
    }

    /// Resets all hints (for manual reset from Settings)
    func resetAllHints() {
        defaults.set(false, forKey: Self.hasUsedPromptTapKey)
        defaults.set(false, forKey: Self.hasSeenLetGoHintKey)
    }
}
