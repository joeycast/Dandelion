//
//  DefaultPromptSetting.swift
//  Dandelion
//
//  SwiftData model for tracking which default prompts are enabled/disabled
//

import Foundation
import SwiftData

@Model
final class DefaultPromptSetting {
    /// The ID of the default prompt (matches WritingPrompt.defaults IDs)
    @Attribute(.unique) var promptId: String

    /// Whether this prompt is enabled (shown in rotation)
    var isEnabled: Bool

    init(promptId: String, isEnabled: Bool = true) {
        self.promptId = promptId
        self.isEnabled = isEnabled
    }
}
