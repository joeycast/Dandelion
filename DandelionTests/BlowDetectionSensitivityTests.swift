import XCTest
@testable import Dandelion

final class BlowDetectionSensitivityTests: XCTestCase {
    func testPresetMappingAcrossAllFiveLevels() {
        let values: [Double] = [0.8, 0.9, 1.0, 1.1, 1.2]
        let labels = ["Lowest", "Low", "Default", "High", "Highest"]
        let durations: [TimeInterval] = [0.5, 0.45, 0.4, 0.35, 0.3]
        let frames = [4, 3, 3, 2, 2]

        for index in 0...BlowDetectionSensitivity.maxIndex {
            XCTAssertEqual(BlowDetectionSensitivity.value(for: index), values[index], accuracy: 0.0001)
            XCTAssertEqual(BlowDetectionSensitivity.presetIndex(for: values[index]), index)
            XCTAssertEqual(BlowDetectionSensitivity.label(for: values[index]), labels[index])
            XCTAssertEqual(BlowDetectionSensitivity.duration(for: values[index]), durations[index], accuracy: 0.0001)
            XCTAssertEqual(BlowDetectionSensitivity.frames(for: values[index]), frames[index])
        }
    }

    func testSnappedClampedAndIndexBoundaries() {
        XCTAssertEqual(BlowDetectionSensitivity.clamped(0.1), 0.8, accuracy: 0.0001)
        XCTAssertEqual(BlowDetectionSensitivity.clamped(2.0), 1.2, accuracy: 0.0001)

        XCTAssertEqual(BlowDetectionSensitivity.snapped(0.84), 0.8, accuracy: 0.0001)
        XCTAssertEqual(BlowDetectionSensitivity.snapped(0.86), 0.9, accuracy: 0.0001)
        XCTAssertEqual(BlowDetectionSensitivity.snapped(1.24), 1.2, accuracy: 0.0001)

        XCTAssertEqual(BlowDetectionSensitivity.value(for: -5), 0.8, accuracy: 0.0001)
        XCTAssertEqual(BlowDetectionSensitivity.value(for: 99), 1.2, accuracy: 0.0001)
        XCTAssertEqual(BlowDetectionSensitivity.presetIndex(for: 0.1), 0)
        XCTAssertEqual(BlowDetectionSensitivity.presetIndex(for: 2.0), 4)
    }
}
