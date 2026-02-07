import XCTest
import UserNotifications
@testable import Dandelion

@MainActor
final class ReminderNotificationServiceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var center: FakeReminderNotificationCenter!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "ReminderNotificationServiceTests")!
        defaults.removePersistentDomain(forName: "ReminderNotificationServiceTests")
        center = FakeReminderNotificationCenter()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "ReminderNotificationServiceTests")
        defaults = nil
        center = nil
        super.tearDown()
    }

    func testDefaultsAreDisabledAt8PM() {
        let sut = makeService()

        XCTAssertFalse(sut.isEnabled)
        XCTAssertEqual(sut.hour, 20)
        XCTAssertEqual(sut.minute, 0)
    }

    func testReminderTimeRoundTripsHourAndMinute() async {
        let sut = makeService()
        center.status = .authorized
        await sut.refreshPermissionStatus()

        var components = DateComponents()
        components.hour = 6
        components.minute = 45
        let date = Calendar.current.date(from: components) ?? Date()

        await sut.updateReminderTime(date, releases: [])

        XCTAssertEqual(sut.hour, 6)
        XCTAssertEqual(sut.minute, 45)
    }

    func testEnableSchedulesAndDisableCancels() async {
        let sut = makeService()
        center.status = .authorized
        await sut.refreshPermissionStatus()

        let now = makeDate(year: 2026, month: 2, day: 7, hour: 10, minute: 0)
        await sut.setEnabled(true, releases: [], now: now)
        XCTAssertFalse(center.requests.isEmpty)

        await sut.setEnabled(false, releases: [], now: now)
        XCTAssertTrue(center.requests.isEmpty)
        XCTAssertFalse(center.removedIdentifiers.isEmpty)
    }

    func testTimeChangeReschedulesWithUpdatedTriggerHour() async throws {
        let sut = makeService()
        center.status = .authorized
        await sut.refreshPermissionStatus()

        let now = makeDate(year: 2026, month: 2, day: 7, hour: 10, minute: 0)
        await sut.setEnabled(true, releases: [], now: now)

        var components = DateComponents()
        components.hour = 22
        components.minute = 30
        let updatedTime = Calendar.current.date(from: components) ?? Date()
        await sut.updateReminderTime(updatedTime, releases: [], now: now)

        let first = try XCTUnwrap(center.requests.first)
        let trigger = try XCTUnwrap(first.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.hour, 22)
        XCTAssertEqual(trigger.dateComponents.minute, 30)
    }

    func testSkippingTodayWhenReleasedToday() async {
        let sut = makeService()
        center.status = .authorized
        await sut.refreshPermissionStatus()

        let now = makeDate(year: 2026, month: 2, day: 7, hour: 10, minute: 0)
        let release = Release(timestamp: now, wordCount: 12)
        await sut.setEnabled(true, releases: [release], now: now)

        XCTAssertFalse(center.requests.contains { $0.identifier.contains("2026-02-07") })
    }

    func testScheduledBodiesIncludePromptsAndEncouragements() async {
        let sut = makeService()
        center.status = .authorized
        await sut.refreshPermissionStatus()

        let now = makeDate(year: 2026, month: 2, day: 7, hour: 10, minute: 0)
        await sut.setEnabled(true, releases: [], now: now)

        let bodies = center.requests.map(\.content.body)
        XCTAssertTrue(bodies.contains(where: { ReminderMessageLibrary.curatedPromptMessages.contains($0) }))
        XCTAssertTrue(bodies.contains(where: { ReminderMessageLibrary.encouragingMessages.contains($0) }))
    }

    private func makeService() -> ReminderNotificationService {
        ReminderNotificationService(center: center, userDefaults: defaults)
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date ?? Date()
    }
}

private final class FakeReminderNotificationCenter: ReminderNotificationCenter {
    var status: UNAuthorizationStatus = .notDetermined
    var requests: [UNNotificationRequest] = []
    var removedIdentifiers: [[String]] = []

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        if status == .notDetermined {
            status = .authorized
        }
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        requests
    }

    func add(_ request: UNNotificationRequest) async throws {
        requests.removeAll(where: { $0.identifier == request.identifier })
        requests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(identifiers)
        let set = Set(identifiers)
        requests.removeAll(where: { set.contains($0.identifier) })
    }
}
