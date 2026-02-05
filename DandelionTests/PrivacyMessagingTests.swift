import XCTest
@testable import Dandelion

final class PrivacyMessagingTests: XCTestCase {
    func testLetGoHintIncludesPrivacyCopy() {
        XCTAssertEqual(
            WritingView.privacyHintText,
            "Your words are never saved or shared. Only release counts and dates stay on your device (and in iCloud if enabled)."
        )
    }
}
