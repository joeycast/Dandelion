import XCTest

final class PromptLayoutSettingsTests: XCTestCase {
    private let promptLayoutKey = "promptLayoutStyle"
    private var previousValue: Any?

    override func setUp() {
        super.setUp()
        previousValue = UserDefaults.standard.object(forKey: promptLayoutKey)
    }

    override func tearDown() {
        if let previousValue {
            UserDefaults.standard.set(previousValue, forKey: promptLayoutKey)
        } else {
            UserDefaults.standard.removeObject(forKey: promptLayoutKey)
        }
        super.tearDown()
    }

    func testPromptLayoutSettingPersists() {
        UserDefaults.standard.set(1, forKey: promptLayoutKey)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: promptLayoutKey), 1)

        UserDefaults.standard.set(0, forKey: promptLayoutKey)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: promptLayoutKey), 0)
    }
}
