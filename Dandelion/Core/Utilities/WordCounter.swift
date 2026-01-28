//
//  WordCounter.swift
//  Dandelion
//
//  Robust word counting utility
//

import Foundation

enum WordCounter {
    /// Counts words in the given text using proper linguistic tokenization
    /// Handles multiple spaces, tabs, newlines, and punctuation correctly
    nonisolated static func count(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }

        var wordCount = 0
        text.enumerateSubstrings(
            in: text.startIndex...,
            options: [.byWords, .localized]
        ) { substring, _, _, _ in
            if substring != nil {
                wordCount += 1
            }
        }
        return wordCount
    }
}
