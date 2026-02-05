import XCTest
@testable import Dandelion

@MainActor
final class BlowDetectionServiceTests: XCTestCase {
    private var originalSensitivity: Any?
    private var originalEnabled: Any?

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        originalSensitivity = defaults.object(forKey: BlowDetectionSensitivity.settingsKey)
        originalEnabled = defaults.object(forKey: BlowDetectionSensitivity.enabledKey)
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        if let originalSensitivity {
            defaults.set(originalSensitivity, forKey: BlowDetectionSensitivity.settingsKey)
        } else {
            defaults.removeObject(forKey: BlowDetectionSensitivity.settingsKey)
        }
        if let originalEnabled {
            defaults.set(originalEnabled, forKey: BlowDetectionSensitivity.enabledKey)
        } else {
            defaults.removeObject(forKey: BlowDetectionSensitivity.enabledKey)
        }
        super.tearDown()
    }

    func testBlowProgressAdvancesAndResets() {
        let service = BlowDetectionService()
        var now = Date(timeIntervalSinceReferenceDate: 0)
        service.nowProvider = { now }

        service.debugUpdateBlowState(isBlowDetected: true, level: 0.5)
        XCTAssertEqual(service.blowProgress, 0)

        now = Date(timeIntervalSinceReferenceDate: 0.2)
        service.debugUpdateBlowState(isBlowDetected: true, level: 0.5)
        XCTAssertGreaterThan(service.blowProgress, 0)
        XCTAssertLessThan(service.blowProgress, 1)

        now = Date(timeIntervalSinceReferenceDate: 0.35)
        service.debugUpdateBlowState(isBlowDetected: true, level: 0.5)
        XCTAssertLessThan(service.blowProgress, 1)

        now = Date(timeIntervalSinceReferenceDate: 0.5)
        service.debugUpdateBlowState(isBlowDetected: true, level: 0.5)
        XCTAssertEqual(service.blowProgress, 1)

        service.debugUpdateBlowState(isBlowDetected: false, level: 0.1)
        XCTAssertEqual(service.blowProgress, 0)
    }

    func testStartListeningDoesNotStartWhenDisabled() async {
        UserDefaults.standard.set(false, forKey: BlowDetectionSensitivity.enabledKey)

        let service = BlowDetectionService()
        var didStartListening = false
        service.permissionRequestOverride = { true }
        service.startListeningOverride = { didStartListening = true }

        _ = await service.requestPermission()
        service.startListening()

        XCTAssertFalse(didStartListening)
        XCTAssertFalse(service.isListening)
    }

    func testDisablingSettingStopsListening() async {
        UserDefaults.standard.set(true, forKey: BlowDetectionSensitivity.enabledKey)

        let service = BlowDetectionService()
        var didStartListening = false
        service.permissionRequestOverride = { true }
        service.startListeningOverride = { didStartListening = true }

        _ = await service.requestPermission()
        service.startListening()
        XCTAssertTrue(didStartListening)
        XCTAssertTrue(service.isListening)

        UserDefaults.standard.set(false, forKey: BlowDetectionSensitivity.enabledKey)

        let expectation = expectation(description: "Observer applies disabled state")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(service.isEnabled)
            XCTAssertFalse(service.isListening)
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
