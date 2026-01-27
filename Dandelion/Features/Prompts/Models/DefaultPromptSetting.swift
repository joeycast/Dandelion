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
    var promptId: String = ""

    /// Whether this prompt is enabled (shown in rotation)
    var isEnabled: Bool = true

    init(promptId: String, isEnabled: Bool = true) {
        self.promptId = promptId
        self.isEnabled = isEnabled
    }
}
