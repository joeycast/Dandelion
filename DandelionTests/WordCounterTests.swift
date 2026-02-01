//
//  WordCounterTests.swift
//  DandelionTests
//
//  Tests for word counting utility
//

import XCTest
@testable import Dandelion

final class WordCounterTests: XCTestCase {
    func testCountsWordsWithWhitespaceAndPunctuation() {
        let text = "Hello, world!\nThis\tis  a test."
        XCTAssertEqual(WordCounter.count(text), 6)
    }

    func testCountsApostrophes() {
        let text = "It's time to write."
        XCTAssertEqual(WordCounter.count(text), 4)
    }

    func testEmptyStringIsZero() {
        XCTAssertEqual(WordCounter.count(""), 0)
    }
}
