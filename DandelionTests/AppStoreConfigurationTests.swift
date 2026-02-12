import XCTest
@testable import Dandelion

final class AppStoreConfigurationTests: XCTestCase {
    func testInfoURLReturnsValueForValidURLString() {
        let infoDictionary: [String: Any] = [
            "MacDownloadLandingURL": "https://example.com/download"
        ]

        let url = AppStoreConfiguration.infoURL(
            forKey: "MacDownloadLandingURL",
            in: infoDictionary
        )

        XCTAssertEqual(url?.absoluteString, "https://example.com/download")
    }

    func testInfoURLReturnsNilForMissingKey() {
        let infoDictionary: [String: Any] = [:]

        let url = AppStoreConfiguration.infoURL(
            forKey: "MacDownloadLandingURL",
            in: infoDictionary
        )

        XCTAssertNil(url)
    }

    func testInfoURLReturnsNilForEmptyString() {
        let infoDictionary: [String: Any] = [
            "MacDownloadLandingURL": "   "
        ]

        let url = AppStoreConfiguration.infoURL(
            forKey: "MacDownloadLandingURL",
            in: infoDictionary
        )

        XCTAssertNil(url)
    }

    func testInfoURLReturnsNilForMalformedURLString() {
        let infoDictionary: [String: Any] = [
            "MacDownloadLandingURL": "not a url"
        ]

        let url = AppStoreConfiguration.infoURL(
            forKey: "MacDownloadLandingURL",
            in: infoDictionary
        )

        XCTAssertNil(url)
    }
}
