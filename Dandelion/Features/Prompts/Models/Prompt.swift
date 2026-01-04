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
    private(set) var writingPrompts: [WritingPrompt]
    private(set) var releaseMessages: [ReleaseMessage]
    private var usedPromptIds: Set<String> = []
    private var usedMessageIds: Set<String> = []

    init() {
        self.writingPrompts = WritingPrompt.defaults
        self.releaseMessages = ReleaseMessage.defaults
    }

    /// Get a random writing prompt, avoiding recent repeats
    func randomPrompt() -> WritingPrompt {
        let availablePrompts = writingPrompts.filter { !usedPromptIds.contains($0.id) }

        // Reset if we've used them all
        if availablePrompts.isEmpty {
            usedPromptIds.removeAll()
            return writingPrompts.randomElement() ?? WritingPrompt(text: "What's on your mind?")
        }

        let prompt = availablePrompts.randomElement() ?? writingPrompts[0]
        usedPromptIds.insert(prompt.id)

        // Keep only last 5 to allow some variety
        if usedPromptIds.count > 5 {
            usedPromptIds.removeFirst()
        }

        return prompt
    }

    /// Get a random release message, avoiding recent repeats
    func randomReleaseMessage() -> ReleaseMessage {
        let availableMessages = releaseMessages.filter { !usedMessageIds.contains($0.id) }

        // Reset if we've used them all
        if availableMessages.isEmpty {
            usedMessageIds.removeAll()
            return releaseMessages.randomElement() ?? ReleaseMessage(text: "Released.")
        }

        let message = availableMessages.randomElement() ?? releaseMessages[0]
        usedMessageIds.insert(message.id)

        // Keep only last 3 to allow some variety
        if usedMessageIds.count > 3 {
            usedMessageIds.removeFirst()
        }

        return message
    }
}
