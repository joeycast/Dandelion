//
//  HintResetManagerTests.swift
//  DandelionTests
//
//  Tests for the hint reset logic for returning users
//

import XCTest
@testable import Dandelion

final class HintResetManagerTests: XCTestCase {
    var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "HintResetManagerTests")!
        testDefaults.removePersistentDomain(forName: "HintResetManagerTests")
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "HintResetManagerTests")
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - Reset After Inactivity

    func testHintsResetAfterFourWeeksOfInactivity() {
        // Set up: user has used hints and last opened 5 weeks ago
        testDefaults.set(true, forKey: HintResetManager.hasUsedPromptTapKey)
        testDefaults.set(true, forKey: HintResetManager.hasSeenLetGoHintKey)

        let fiveWeeksAgo = Date().addingTimeInterval(-60 * 60 * 24 * 7 * 5)
        testDefaults.set(fiveWeeksAgo.timeIntervalSince1970, forKey: HintResetManager.lastAppOpenDateKey)

        let manager = HintResetManager(defaults: testDefaults)
        let didReset = manager.checkAndResetHintsIfNeeded()

        XCTAssertTrue(didReset, "Should reset hints after 4+ weeks")
        XCTAssertFalse(testDefaults.bool(forKey: HintResetManager.hasUsedPromptTapKey))
        XCTAssertFalse(testDefaults.bool(forKey: HintResetManager.hasSeenLetGoHintKey))
    }

    func testHintsNotResetBeforeFourWeeks() {
        // Set up: user has used hints and last opened 3 weeks ago
        testDefaults.set(true, forKey: HintResetManager.hasUsedPromptTapKey)
        testDefaults.set(true, forKey: HintResetManager.hasSeenLetGoHintKey)

        let threeWeeksAgo = Date().addingTimeInterval(-60 * 60 * 24 * 7 * 3)
        testDefaults.set(threeWeeksAgo.timeIntervalSince1970, forKey: HintResetManager.lastAppOpenDateKey)

        let manager = HintResetManager(defaults: testDefaults)
        let didReset = manager.checkAndResetHintsIfNeeded()

        XCTAssertFalse(didReset, "Should not reset hints before 4 weeks")
        XCTAssertTrue(testDefaults.bool(forKey: HintResetManager.hasUsedPromptTapKey))
        XCTAssertTrue(testDefaults.bool(forKey: HintResetManager.hasSeenLetGoHintKey))
    }

    func testHintsNotResetOnFirstLaunch() {
        // No last open date set (first launch)
        let manager = HintResetManager(defaults: testDefaults)
        let didReset = manager.checkAndResetHintsIfNeeded()

        XCTAssertFalse(didReset, "Should not reset on first launch")
    }

    func testHintsResetAtExactlyFourWeeks() {
        // Set up: exactly 4 weeks + 1 second ago
        testDefaults.set(true, forKey: HintResetManager.hasUsedPromptTapKey)

        let fourWeeksAndOneSecond = Date().addingTimeInterval(-HintResetManager.resetThresholdSeconds - 1)
        testDefaults.set(fourWeeksAndOneSecond.timeIntervalSince1970, forKey: HintResetManager.lastAppOpenDateKey)

        let manager = HintResetManager(defaults: testDefaults)
        let didReset = manager.checkAndResetHintsIfNeeded()

        XCTAssertTrue(didReset, "Should reset hints at threshold")
    }

    // MARK: - Last Open Date

    func testLastOpenDateUpdated() {
        let now = Date()
        let manager = HintResetManager(defaults: testDefaults, currentDate: { now })
        manager.checkAndResetHintsIfNeeded()

        let savedDate = testDefaults.double(forKey: HintResetManager.lastAppOpenDateKey)
        XCTAssertEqual(savedDate, now.timeIntervalSince1970, accuracy: 1.0)
    }

    func testLastOpenDateUpdatedEvenWithoutReset() {
        // Last opened 1 week ago (no reset needed)
        let oneWeekAgo = Date().addingTimeInterval(-60 * 60 * 24 * 7)
        testDefaults.set(oneWeekAgo.timeIntervalSince1970, forKey: HintResetManager.lastAppOpenDateKey)

        let now = Date()
        let manager = HintResetManager(defaults: testDefaults, currentDate: { now })
        manager.checkAndResetHintsIfNeeded()

        let savedDate = testDefaults.double(forKey: HintResetManager.lastAppOpenDateKey)
        XCTAssertEqual(savedDate, now.timeIntervalSince1970, accuracy: 1.0)
    }

    // MARK: - Manual Reset

    func testResetAllHints() {
        testDefaults.set(true, forKey: HintResetManager.hasUsedPromptTapKey)
        testDefaults.set(true, forKey: HintResetManager.hasSeenLetGoHintKey)

        let manager = HintResetManager(defaults: testDefaults)
        manager.resetAllHints()

        XCTAssertFalse(testDefaults.bool(forKey: HintResetManager.hasUsedPromptTapKey))
        XCTAssertFalse(testDefaults.bool(forKey: HintResetManager.hasSeenLetGoHintKey))
    }
}
