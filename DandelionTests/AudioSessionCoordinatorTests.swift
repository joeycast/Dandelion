import XCTest
@testable import Dandelion

final class AudioSessionCoordinatorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AudioSessionCoordinator.resetForTesting()
    }

    override func tearDown() {
        AudioSessionCoordinator.resetForTesting()
        super.tearDown()
    }

    func testAcquireAndReleaseTrackClients() {
        AudioSessionCoordinator.acquireAmbient()
        AudioSessionCoordinator.acquireAmbient()
        var counts = AudioSessionCoordinator.clientCountsForTesting()
        XCTAssertEqual(counts.ambient, 2)
        XCTAssertEqual(counts.blow, 0)

        AudioSessionCoordinator.releaseAmbient()
        counts = AudioSessionCoordinator.clientCountsForTesting()
        XCTAssertEqual(counts.ambient, 1)

        AudioSessionCoordinator.releaseAmbient()
        counts = AudioSessionCoordinator.clientCountsForTesting()
        XCTAssertEqual(counts.ambient, 0)
    }

    func testReleaseDoesNotUnderflow() {
        AudioSessionCoordinator.releaseAmbient()
        AudioSessionCoordinator.releaseBlowDetection()
        let counts = AudioSessionCoordinator.clientCountsForTesting()
        XCTAssertEqual(counts.ambient, 0)
        XCTAssertEqual(counts.blow, 0)
    }

    func testBlowAndAmbientCanBeHeldTogether() throws {
        try AudioSessionCoordinator.acquireBlowDetection()
        AudioSessionCoordinator.acquireAmbient()
        let counts = AudioSessionCoordinator.clientCountsForTesting()
        XCTAssertEqual(counts.ambient, 1)
        XCTAssertEqual(counts.blow, 1)

        AudioSessionCoordinator.releaseBlowDetection()
        let afterBlow = AudioSessionCoordinator.clientCountsForTesting()
        XCTAssertEqual(afterBlow.ambient, 1)
        XCTAssertEqual(afterBlow.blow, 0)

        AudioSessionCoordinator.releaseAmbient()
        let afterAll = AudioSessionCoordinator.clientCountsForTesting()
        XCTAssertEqual(afterAll.ambient, 0)
        XCTAssertEqual(afterAll.blow, 0)
    }
}
