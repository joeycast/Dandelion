//
//  PappusTests.swift
//  DandelionTests
//
//  Unit tests for the Pappus model
//

import XCTest
@testable import Dandelion

final class PappusTests: XCTestCase {

    // MARK: - Initialization Tests

    func testPappusCreatesWithText() {
        let pappus = Pappus(
            text: "h",
            startPosition: CGPoint(x: 100, y: 100),
            screenSize: CGSize(width: 400, height: 800)
        )

        XCTAssertEqual(pappus.text, "h", "Pappus should store the text")
    }

    func testPappusHasUniqueID() {
        let pappus1 = Pappus(
            text: "a",
            startPosition: CGPoint(x: 100, y: 100),
            screenSize: CGSize(width: 400, height: 800)
        )
        let pappus2 = Pappus(
            text: "a",
            startPosition: CGPoint(x: 100, y: 100),
            screenSize: CGSize(width: 400, height: 800)
        )

        XCTAssertNotEqual(pappus1.id, pappus2.id, "Each pappus should have a unique ID")
    }

    func testPappusStoresStartPosition() {
        let startPosition = CGPoint(x: 150, y: 200)
        let pappus = Pappus(
            text: "t",
            startPosition: startPosition,
            screenSize: CGSize(width: 400, height: 800)
        )

        XCTAssertEqual(pappus.startPosition, startPosition, "Should store start position")
    }

    // MARK: - Animation Properties Tests

    func testPappusEndPositionIsAboveStart() {
        let startY: CGFloat = 400
        let pappus = Pappus(
            text: "x",
            startPosition: CGPoint(x: 200, y: startY),
            screenSize: CGSize(width: 400, height: 800)
        )

        // End position should be above start (lower y value)
        XCTAssertLessThan(pappus.endPosition.y, startY, "End position should be above start position")
    }

    func testPappusDriftDelayIsPositive() {
        let pappus = Pappus(
            text: "a",
            startPosition: CGPoint(x: 200, y: 200),
            screenSize: CGSize(width: 400, height: 800)
        )

        XCTAssertGreaterThanOrEqual(pappus.driftDelay, 0, "Drift delay should be non-negative")
        XCTAssertLessThanOrEqual(pappus.driftDelay, 0.3, "Drift delay should be at most 0.3 seconds")
    }

    func testPappusDurationIsReasonable() {
        let pappus = Pappus(
            text: "b",
            startPosition: CGPoint(x: 200, y: 200),
            screenSize: CGSize(width: 400, height: 800)
        )

        XCTAssertGreaterThanOrEqual(pappus.duration, 2.5, "Duration should be at least 2.5 seconds")
        XCTAssertLessThanOrEqual(pappus.duration, 4.0, "Duration should be at most 4.0 seconds")
    }

    // MARK: - Text Parsing Tests (Letter-based)

    func testFromTextCreatesOnePerLetter() {
        let text = "hello"
        let screenSize = CGSize(width: 400, height: 800)

        let pappuses = Pappus.fromText(text, screenSize: screenSize)

        XCTAssertEqual(pappuses.count, 5, "Should create one pappus per letter")
    }

    func testFromTextSkipsWhitespace() {
        let text = "hello world"  // Space should be skipped
        let screenSize = CGSize(width: 400, height: 800)

        let pappuses = Pappus.fromText(text, screenSize: screenSize)

        // "hello world" without space = 10 letters
        XCTAssertEqual(pappuses.count, 10, "Should skip whitespace")
    }

    func testFromTextHandlesNewlines() {
        let text = "hi\nthere"
        let screenSize = CGSize(width: 400, height: 800)

        let pappuses = Pappus.fromText(text, screenSize: screenSize)

        // "hithere" = 7 letters (newline skipped)
        XCTAssertEqual(pappuses.count, 7, "Should skip newlines")
    }

    func testFromTextPreservesLetterOrder() {
        let text = "abc"
        let screenSize = CGSize(width: 400, height: 800)

        let pappuses = Pappus.fromText(text, screenSize: screenSize)

        XCTAssertEqual(pappuses[0].text, "a")
        XCTAssertEqual(pappuses[1].text, "b")
        XCTAssertEqual(pappuses[2].text, "c")
    }

    func testFromTextHandlesEmptyInput() {
        let text = ""
        let screenSize = CGSize(width: 400, height: 800)

        let pappuses = Pappus.fromText(text, screenSize: screenSize)

        XCTAssertTrue(pappuses.isEmpty, "Empty text should produce no pappuses")
    }

    func testFromTextHandlesWhitespaceOnlyInput() {
        let text = "   \n\t  "
        let screenSize = CGSize(width: 400, height: 800)

        let pappuses = Pappus.fromText(text, screenSize: screenSize)

        XCTAssertTrue(pappuses.isEmpty, "Whitespace-only text should produce no pappuses")
    }

    func testFromTextIncludesNumbers() {
        let text = "a1b2"
        let screenSize = CGSize(width: 400, height: 800)

        let pappuses = Pappus.fromText(text, screenSize: screenSize)

        XCTAssertEqual(pappuses.count, 4, "Should include numbers")
        XCTAssertEqual(pappuses[1].text, "1")
        XCTAssertEqual(pappuses[3].text, "2")
    }

    // MARK: - Equatable Tests

    func testPappusEquatable() {
        let pappus1 = Pappus(
            text: "x",
            startPosition: CGPoint(x: 100, y: 100),
            screenSize: CGSize(width: 400, height: 800)
        )

        // Same instance should be equal
        XCTAssertEqual(pappus1, pappus1, "Pappus should equal itself")
    }

    func testDifferentPappusesNotEqual() {
        let pappus1 = Pappus(
            text: "x",
            startPosition: CGPoint(x: 100, y: 100),
            screenSize: CGSize(width: 400, height: 800)
        )
        let pappus2 = Pappus(
            text: "x",
            startPosition: CGPoint(x: 100, y: 100),
            screenSize: CGSize(width: 400, height: 800)
        )

        // Different instances should not be equal (different UUIDs)
        XCTAssertNotEqual(pappus1, pappus2, "Different pappuses should not be equal")
    }
}
