import CloudKit
import Foundation

struct GlobalReleaseCounts: Codable, Equatable {
    let dayKey: String
    let total: Int
    let today: Int
    let updatedAt: Date

    func incremented(now: Date = Date()) -> GlobalReleaseCounts {
        let currentDayKey = GlobalReleaseCountService.dayKey(for: now)
        if currentDayKey == dayKey {
            return GlobalReleaseCounts(dayKey: dayKey, total: total + 1, today: today + 1, updatedAt: now)
        }
        return GlobalReleaseCounts(dayKey: currentDayKey, total: total + 1, today: 1, updatedAt: now)
    }
}

final class GlobalReleaseCountService {
    private let containerProvider: () -> CKContainer
    private lazy var container: CKContainer = containerProvider()
    private lazy var database: CKDatabase = container.publicCloudDatabase
    private let userDefaults: UserDefaults
    private let cacheInterval: TimeInterval

    private let cacheKey = "globalReleaseCountsCache"
    private let cacheDateKey = "globalReleaseCountsCacheDate"

    init(
        containerProvider: @escaping () -> CKContainer = { CKContainer.default() },
        userDefaults: UserDefaults = .standard,
        cacheInterval: TimeInterval = 60 * 30
    ) {
        self.containerProvider = containerProvider
        self.userDefaults = userDefaults
        self.cacheInterval = cacheInterval
    }

    func loadCounts(forceRefresh: Bool = false) async -> GlobalReleaseCounts? {
        if isRunningTests {
            return cachedCounts()
        }
        if !forceRefresh, let cached = cachedCounts(), isCacheFresh() {
            return cached
        }

        do {
            let counts = try await fetchCounts()
            cacheCounts(counts)
            return counts
        } catch {
            return cachedCounts()
        }
    }

    func incrementCountsIfEnabled(_ isEnabled: Bool) async {
        if isRunningTests { return }
        guard isEnabled else { return }
        do {
            guard try await isCloudKitAvailable() else { return }
            try await incrementCounts()
        } catch {
            return
        }
    }

    func updateCachedCounts(_ counts: GlobalReleaseCounts) {
        cacheCounts(counts)
    }

    // MARK: - Private

    private func isCloudKitAvailable() async throws -> Bool {
        let status = try await container.accountStatus()
        return status == .available
    }

    private func fetchCounts() async throws -> GlobalReleaseCounts {
        guard try await isCloudKitAvailable() else {
            throw CKError(.notAuthenticated)
        }
        let globalRecord = try await fetchRecord(recordType: "GlobalReleaseStats", recordName: "global")
        let dailyRecordName = Self.dayKey(for: Date())
        let dailyRecord = try await fetchRecord(recordType: "DailyReleaseStats", recordName: dailyRecordName)

        let total = (globalRecord["count"] as? Int) ?? 0
        let today = (dailyRecord["count"] as? Int) ?? 0
        return GlobalReleaseCounts(dayKey: dailyRecordName, total: total, today: today, updatedAt: Date())
    }

    private func incrementCounts() async throws {
        let now = Date()
        let globalRecord = try await fetchRecord(recordType: "GlobalReleaseStats", recordName: "global")
        let dailyRecordName = Self.dayKey(for: now)
        let dailyRecord = try await fetchRecord(recordType: "DailyReleaseStats", recordName: dailyRecordName)

        try await saveIncrementedRecord(globalRecord)
        try await saveIncrementedRecord(dailyRecord)

        if let cached = cachedCounts() {
            cacheCounts(cached.incremented(now: now))
        }
    }

    private func fetchRecord(recordType: String, recordName: String) async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: recordName)
        do {
            return try await database.record(for: recordID)
        } catch let error as CKError {
            if error.code == .unknownItem {
                return CKRecord(recordType: recordType, recordID: recordID)
            }
            throw error
        }
    }

    private func saveIncrementedRecord(_ record: CKRecord) async throws {
        var recordToSave = record
        var attemptsRemaining = 3

        while attemptsRemaining > 0 {
            attemptsRemaining -= 1
            let currentCount = (recordToSave["count"] as? Int) ?? 0
            recordToSave["count"] = currentCount + 1
            do {
                _ = try await database.save(recordToSave)
                return
            } catch let error as CKError {
                if error.code == .serverRecordChanged, let serverRecord = error.serverRecord {
                    recordToSave = serverRecord
                    continue
                }
                if attemptsRemaining == 0 {
                    throw error
                }
            }
        }
    }

    private func cacheCounts(_ counts: GlobalReleaseCounts) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(counts) {
            userDefaults.set(data, forKey: cacheKey)
            userDefaults.set(Date(), forKey: cacheDateKey)
        }
    }

    private func cachedCounts() -> GlobalReleaseCounts? {
        guard let data = userDefaults.data(forKey: cacheKey) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(GlobalReleaseCounts.self, from: data)
    }

    private func isCacheFresh() -> Bool {
        guard let cachedDate = userDefaults.object(forKey: cacheDateKey) as? Date else { return false }
        return Date().timeIntervalSince(cachedDate) < cacheInterval
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
