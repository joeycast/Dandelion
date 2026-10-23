//
//  DandelionUITests.swift
//  DandelionUITests
//
//  Smoke tests for the core iOS flows: prompt, writing, settings, and history
//

import XCTest

final class DandelionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // The idle wind animation redraws the dandelion continuously, which keeps the app from
        // ever going idle for XCUITest. Turn it off through the argument domain of UserDefaults.
        app.launchArguments += ["-com.dandelion.windAnimationEnabled", "NO"]

        // Dismiss any system alert (notifications, microphone) that appears mid-test.
        addUIInterruptionMonitor(withDescription: "System alert") { alert in
            for label in ["Don’t Allow", "Don't Allow", "Not Now", "OK"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }

        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testLaunchShowsBeginWriting() throws {
        let beginWriting = app.buttons["Begin Writing"]
        XCTAssertTrue(
            beginWriting.waitForExistence(timeout: 15),
            "Prompt screen should offer Begin Writing. Hierarchy:\n\(app.debugDescription)"
        )
        XCTAssertTrue(app.buttons["Settings"].exists, "Settings button should be on the prompt screen")
        XCTAssertTrue(app.buttons["Release history"].exists, "History button should be on the prompt screen")
    }

    func testBeginWritingShowsEditorAndEnablesLetGo() throws {
        let beginWriting = app.buttons["Begin Writing"]
        XCTAssertTrue(beginWriting.waitForExistence(timeout: 15))
        waitUntilHittable(beginWriting)
        beginWriting.tap()

        let letGo = app.buttons["Let Go"]
        XCTAssertTrue(letGo.waitForExistence(timeout: 10), "Writing screen should show the Let Go button")

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "Writing screen should show a text editor")
        editor.tap()
        editor.typeText("Letting this go")

        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: letGo)
        waitForExpectations(timeout: 5)
    }

    func testSettingsOpensAndDismisses() throws {
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        waitUntilHittable(settings)
        settings.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10), "Settings sheet should appear")

        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()

        XCTAssertTrue(app.buttons["Begin Writing"].waitForExistence(timeout: 10), "Dismissing settings returns to the prompt")
    }

    func testReleaseHistoryOpens() throws {
        let history = app.buttons["Release history"]
        XCTAssertTrue(history.waitForExistence(timeout: 15))
        waitUntilHittable(history)
        history.tap()

        let previousYear = app.buttons["Previous year"]
        XCTAssertTrue(previousYear.waitForExistence(timeout: 10), "History sheet should show the year navigator")

        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()

        XCTAssertTrue(app.buttons["Begin Writing"].waitForExistence(timeout: 10), "Closing history returns to the prompt")
    }

    // MARK: - Helpers

    /// Prompt controls fade in after launch; wait until they accept taps.
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 10) {
        let hittable = NSPredicate(format: "isHittable == true")
        expectation(for: hittable, evaluatedWith: element)
        waitForExpectations(timeout: timeout)
    }
}
