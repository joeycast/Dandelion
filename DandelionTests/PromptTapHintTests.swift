import XCTest
@testable import Dandelion

final class PromptTapHintTests: XCTestCase {
    func testPromptTapHintFlagPersists() {
        let key = "hasSeenPromptTapHint"
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: key)
        defer {
            if let previous {
                defaults.set(previous, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.set(true, forKey: key)
        XCTAssertTrue(defaults.bool(forKey: key))

        defaults.set(false, forKey: key)
        XCTAssertFalse(defaults.bool(forKey: key))
    }
}
