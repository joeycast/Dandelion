//
//  DandelionLayoutTests.swift
//  DandelionTests
//
//  Tests for readable-width layout helpers used on wide displays
//

import XCTest
@testable import Dandelion

final class DandelionLayoutTests: XCTestCase {
    func testNarrowContainerUsesMinimumPadding() {
        // iPhone / iPhone Duo outer display widths stay edge-padded.
        let padding = DandelionLayout.readableHorizontalPadding(containerWidth: 402, minimum: 19)
        XCTAssertEqual(padding, 19)
    }

    func testWideContainerCentersReadableColumn() {
        let padding = DandelionLayout.readableHorizontalPadding(containerWidth: 1000, minimum: 19)
        XCTAssertEqual(padding, 140)
        XCTAssertEqual(1000 - padding * 2, DandelionLayout.maxWritingWidth)
    }

    func testCustomMaxContentWidth() {
        let padding = DandelionLayout.readableHorizontalPadding(
            containerWidth: 800,
            minimum: 32,
            maxContentWidth: DandelionLayout.maxPromptWidth
        )
        XCTAssertEqual(800 - padding * 2, DandelionLayout.maxPromptWidth)
    }
}
