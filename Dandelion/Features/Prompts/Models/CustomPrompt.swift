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
    var id: UUID = UUID()
    var text: String = ""
    var createdAt: Date = Date()
    var isActive: Bool = true

    init(id: UUID = UUID(), text: String, createdAt: Date = Date(), isActive: Bool = true) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.isActive = isActive
    }
}
