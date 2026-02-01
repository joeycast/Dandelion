//
//  Prompt.swift
//  Dandelion
//
//  Models for pre-writing prompts and post-release messages
//

import Foundation

/// A prompt shown before writing to inspire reflection
struct WritingPrompt: Identifiable, Codable, Equatable {
    let id: String
    let text: String

    init(id: String = UUID().uuidString, text: String) {
        self.id = id
        self.text = text
    }
}

/// A message shown after releasing writing
struct ReleaseMessage: Identifiable, Codable, Equatable {
    let id: String
    let text: String

    init(id: String = UUID().uuidString, text: String) {
        self.id = id
        self.text = text
    }
}

/// Container for all prompts and messages
struct PromptsData: Codable {
    let writingPrompts: [WritingPrompt]
    let releaseMessages: [ReleaseMessage]
}

// MARK: - Default Prompts

extension WritingPrompt {
    /// Default writing prompts for free users
    static let defaults: [WritingPrompt] = [
        WritingPrompt(id: "1", text: "What's weighing on your mind right now?"),
        WritingPrompt(id: "2", text: "What would you like to let go of today?"),
        WritingPrompt(id: "3", text: "Write about something you can't control."),
        WritingPrompt(id: "4", text: "What conversation keeps replaying in your head?"),
        WritingPrompt(id: "5", text: "Describe a worry you're ready to release."),
        WritingPrompt(id: "6", text: "What's something you wish you could say?"),
        WritingPrompt(id: "7", text: "Write about a feeling you're holding onto."),
        WritingPrompt(id: "8", text: "What expectation is causing you stress?"),
        WritingPrompt(id: "9", text: "Describe a thought that keeps returning."),
        WritingPrompt(id: "10", text: "What are you overthinking right now?"),
        WritingPrompt(id: "11", text: "Write about something you need to forgive."),
        WritingPrompt(id: "12", text: "What's making your mind feel busy?"),
        WritingPrompt(id: "13", text: "Describe a fear you'd like to acknowledge."),
        WritingPrompt(id: "14", text: "What unfinished thought needs completing?"),
        WritingPrompt(id: "15", text: "Write without judgment. Just let it flow."),
    ]
}

extension ReleaseMessage {
    /// Default post-release messages
    static let defaults: [ReleaseMessage] = [
        ReleaseMessage(id: "1", text: "Released."),
        ReleaseMessage(id: "2", text: "Let it drift away."),
        ReleaseMessage(id: "3", text: "Gone with the wind."),
        ReleaseMessage(id: "4", text: "You've let go."),
        ReleaseMessage(id: "5", text: "Breathe."),
        ReleaseMessage(id: "6", text: "It's no longer yours to carry."),
        ReleaseMessage(id: "7", text: "Like seeds in the wind."),
        ReleaseMessage(id: "8", text: "Free."),
        ReleaseMessage(id: "9", text: "The thought has passed."),
        ReleaseMessage(id: "10", text: "You are lighter now."),
        ReleaseMessage(id: "11", text: "May it find peace elsewhere."),
        ReleaseMessage(id: "12", text: "Released into the sky."),
    ]
}

// MARK: - Prompts Manager

@Observable
final class PromptsManager {
    private(set) var customPrompts: [WritingPrompt]
    private(set) var disabledDefaultIds: Set<String>
    private(set) var isPremiumUnlocked: Bool
    private(set) var releaseMessages: [ReleaseMessage]
    private var usedPromptIds: Set<String> = []
    private var usedPromptOrder: [String] = []
    private var usedMessageIds: Set<String> = []
    private var usedMessageOrder: [String] = []
    private var lastPromptId: String?

    /// Active default prompts (excluding disabled ones)
    private var activeDefaultPrompts: [WritingPrompt] {
        WritingPrompt.defaults.filter { !disabledDefaultIds.contains($0.id) }
    }

    /// All available prompts based on current configuration
    var availablePrompts: [WritingPrompt] {
        if isPremiumUnlocked {
            return activeDefaultPrompts + customPrompts
        } else {
            return WritingPrompt.defaults  // Non-premium users see all defaults
        }
    }

    /// Number of available prompts for the current configuration
    var availablePromptCount: Int {
        availablePrompts.count
    }

    init(isPremiumUnlocked: Bool = false) {
        self.customPrompts = []
        self.disabledDefaultIds = []
        self.isPremiumUnlocked = isPremiumUnlocked
        self.releaseMessages = ReleaseMessage.defaults
    }

    /// Get a random writing prompt, avoiding recent repeats
    /// Returns nil if no prompts are available
    /// Never returns the same prompt twice in a row (unless it's the only option)
    func randomPrompt() -> WritingPrompt? {
        let prompts = availablePrompts
        guard !prompts.isEmpty else {
            lastPromptId = nil
            return nil
        }

        // If only one prompt, return it (even if same as last)
        if prompts.count == 1 {
            let prompt = prompts[0]
            lastPromptId = prompt.id
            return prompt
        }

        // Exclude the last shown prompt to ensure variety
        let eligiblePrompts = prompts.filter { $0.id != lastPromptId }
        let unusedPrompts = eligiblePrompts.filter { !usedPromptIds.contains($0.id) }

        let prompt: WritingPrompt
        if unusedPrompts.isEmpty {
            // Reset tracking if we've used all eligible prompts
            usedPromptIds.removeAll()
            usedPromptOrder.removeAll()
            prompt = eligiblePrompts.randomElement() ?? prompts[0]
        } else {
            prompt = unusedPrompts.randomElement() ?? eligiblePrompts[0]
        }

        if usedPromptIds.insert(prompt.id).inserted {
            usedPromptOrder.append(prompt.id)
        }
        lastPromptId = prompt.id

        // Keep only last 5 to allow some variety
        while usedPromptOrder.count > 5 {
            let evictedId = usedPromptOrder.removeFirst()
            usedPromptIds.remove(evictedId)
        }

        return prompt
    }

    /// Get a random release message, avoiding recent repeats
    func randomReleaseMessage() -> ReleaseMessage {
        let availableMessages = releaseMessages.filter { !usedMessageIds.contains($0.id) }

        // Reset if we've used them all
        if availableMessages.isEmpty {
            usedMessageIds.removeAll()
            usedMessageOrder.removeAll()
            return releaseMessages.randomElement() ?? ReleaseMessage(text: "Released.")
        }

        let message = availableMessages.randomElement() ?? releaseMessages[0]
        if usedMessageIds.insert(message.id).inserted {
            usedMessageOrder.append(message.id)
        }

        // Keep only last 3 to allow some variety
        while usedMessageOrder.count > 3 {
            let evictedId = usedMessageOrder.removeFirst()
            usedMessageIds.remove(evictedId)
        }

        return message
    }

    /// Update the prompts configuration
    func updatePrompts(
        customPrompts: [WritingPrompt],
        disabledDefaultIds: Set<String>,
        isPremiumUnlocked: Bool
    ) {
        self.customPrompts = customPrompts
        self.disabledDefaultIds = disabledDefaultIds
        self.isPremiumUnlocked = isPremiumUnlocked
        usedPromptIds.removeAll()
        usedPromptOrder.removeAll()
    }
}
