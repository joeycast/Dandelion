//
//  CustomPrompt.swift
//  Dandelion
//
//  SwiftData model for custom prompts
//

import Foundation
import SwiftData

@Model
final class CustomPrompt {
    var id: UUID
    var text: String
    var createdAt: Date
    var isActive: Bool

    init(id: UUID = UUID(), text: String, createdAt: Date = .now, isActive: Bool = true) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.isActive = isActive
    }
}
