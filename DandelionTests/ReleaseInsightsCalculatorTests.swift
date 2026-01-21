//
//  ReleaseInsightsCalculatorTests.swift
//  DandelionTests
//
//  Unit tests for premium insights calculations
//

import XCTest
@testable import Dandelion

final class ReleaseInsightsCalculatorTests: XCTestCase {
    func testCalculatesTotals() {
        let releases = [
            Release(timestamp: Date(), wordCount: 10),
            Release(timestamp: Date(), wordCount: 20)
        ]

        let insights = ReleaseInsightsCalculator.calculate(releases: releases)

        XCTAssertEqual(insights.totalReleases, 2)
        XCTAssertEqual(insights.totalWords, 30)
        XCTAssertEqual(insights.longestRelease, 20)
        XCTAssertEqual(insights.shortestRelease, 10)
        XCTAssertEqual(insights.averageWordsPerRelease, 15, accuracy: 0.001)
    }

    func testMedianWordCount() {
        let releases = [
            Release(timestamp: Date(), wordCount: 5),
            Release(timestamp: Date(), wordCount: 15),
            Release(timestamp: Date(), wordCount: 25)
        ]

        let insights = ReleaseInsightsCalculator.calculate(releases: releases)
        XCTAssertEqual(insights.medianWordsPerRelease, 15)
    }
}
