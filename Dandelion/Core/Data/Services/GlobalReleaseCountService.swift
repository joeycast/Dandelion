import CloudKit
import Foundation

struct GlobalReleaseCounts: Codable, Equatable {
    let dayKey: String
    let total: Int
    let today: Int
    let totalWords: Int
    let todayWords: Int
    let updatedAt: Date

    init(dayKey: String, total: Int, today: Int, totalWords: Int, todayWords: Int, updatedAt: Date) {
        self.dayKey = dayKey
        self.total = total
        self.today = today
        self.totalWords = totalWords
        self.todayWords = todayWords
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dayKey = try container.decode(String.self, forKey: .dayKey)
        total = try container.decode(Int.self, forKey: .total)
        today = try container.decode(Int.self, forKey: .today)
        totalWords = try container.decodeIfPresent(Int.self, forKey: .totalWords) ?? 0
        todayWords = try container.decodeIfPresent(Int.self, forKey: .todayWords) ?? 0
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func incremented(wordCount: Int, now: Date = Date(), calendar: Calendar = .current) -> GlobalReleaseCounts {
        let safeWordCount = max(0, wordCount)
        let sameLocalDay = calendar.isDate(now, inSameDayAs: updatedAt)
        if sameLocalDay {
            return GlobalReleaseCounts(
                dayKey: dayKey,
                total: total + 1,
                today: today + 1,
                totalWords: totalWords + safeWordCount,
                todayWords: todayWords + safeWordCount,
                updatedAt: now
            )
        }
        return GlobalReleaseCounts(
            dayKey: GlobalReleaseCountService.dayKey(for: now),
            total: total + 1,
            today: 1,
            totalWords: totalWords + safeWordCount,
            todayWords: safeWordCount,
            updatedAt: now
        )
    }
}

final class GlobalReleaseCountService {
    private let containerProvider: () -> CKContainer
    private lazy var container: CKContainer = containerProvider()
    private lazy var database: CKDatabase = container.publicCloudDatabase

    init(
        containerProvider: @escaping () -> CKContainer = { CKContainer.default() }
    ) {
        self.containerProvider = containerProvider
    }

    func loadCounts(forceRefresh _: Bool = false) async -> GlobalReleaseCounts? {
        if isRunningTests { return nil }
        do {
            return try await fetchCounts()
        } catch {
            logCloudKitError("loadCounts failed", error: error)
            return nil
        }
    }

    func incrementCountsIfEnabled(_ isEnabled: Bool, wordCount: Int) async {
        debugLog("[GlobalReleaseCount] incrementCountsIfEnabled called: isEnabled=\(isEnabled) wordCount=\(wordCount)")
        if isRunningTests { return }
        guard isEnabled else {
            debugLog("[GlobalReleaseCount] skipped: not enabled")
            return
        }
        do {
            let canContribute = try await canContributeToGlobalStats()
            debugLog("[GlobalReleaseCount] canContribute=\(canContribute)")
            guard canContribute else {
                debugLog("[GlobalReleaseCount] contribution skipped: requires iCloud account")
                return
            }
            debugLog("[GlobalReleaseCount] incrementing counts...")
            try await incrementCounts(wordCount: wordCount)
            debugLog("[GlobalReleaseCount] increment succeeded")
        } catch {
            logCloudKitError("incrementCountsIfEnabled failed", error: error)
            return
        }
    }

    // MARK: - Private

    private func fetchCounts() async throws -> GlobalReleaseCounts {
        let now = Date()
        let globalRecord = try await fetchRecord(recordType: "GlobalReleaseStats", recordName: "global")
        let hourlyTotals = try await fetchLocalTodayHourlyTotals(now: now)

        let total = intValue(globalRecord["count"])
        let totalWords = intValue(globalRecord["wordCount"])
        return GlobalReleaseCounts(
            dayKey: Self.dayKey(for: now),
            total: total,
            today: hourlyTotals.releases,
            totalWords: totalWords,
            todayWords: hourlyTotals.words,
            updatedAt: now
        )
    }

    private func fetchLocalTodayHourlyTotals(now: Date) async throws -> (releases: Int, words: Int) {
        let hourKeys = Self.hourKeysForLocalToday(now: now)
        guard !hourKeys.isEmpty else { return (0, 0) }

        let recordIDs = hourKeys.map { CKRecord.ID(recordName: $0) }
        let results = try await database.records(for: recordIDs)

        var releases = 0
        var words = 0
        for (_, result) in results {
            switch result {
            case .success(let record):
                releases += intValue(record["count"])
                words += intValue(record["wordCount"])
            case .failure(let error):
                if let ckError = error as? CKError, ckError.code == .unknownItem {
                    continue
                }
                throw error
            }
        }
        return (releases, words)
    }

    private func incrementCounts(wordCount: Int) async throws {
        let safeWordCount = max(0, wordCount)
        let now = Date()
        let globalRecord = try await fetchRecord(recordType: "GlobalReleaseStats", recordName: "global")
        let hourlyRecordName = Self.hourKey(for: now)
        let hourlyRecord = try await fetchRecord(recordType: "HourlyReleaseStats", recordName: hourlyRecordName)

        try await saveIncrementedRecord(globalRecord, releaseIncrement: 1, wordIncrement: safeWordCount)
        try await saveIncrementedRecord(hourlyRecord, releaseIncrement: 1, wordIncrement: safeWordCount)
    }

    private func fetchRecord(recordType: String, recordName: String) async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: recordName)
        do {
            return try await database.record(for: recordID)
        } catch let error as CKError {
            if error.code == .unknownItem {
                return CKRecord(recordType: recordType, recordID: recordID)
            }
            debugLog("[GlobalReleaseCount] fetchRecord failed type=\(recordType) record=\(recordName) code=\(error.code.rawValue)")
            throw error
        } catch {
            logCloudKitError("fetchRecord failed type=\(recordType) record=\(recordName)", error: error)
            throw error
        }
    }

    private func saveIncrementedRecord(
        _ record: CKRecord,
        releaseIncrement: Int,
        wordIncrement: Int
    ) async throws {
        var baseRecord = record
        var attemptsRemaining = 3

        while attemptsRemaining > 0 {
            attemptsRemaining -= 1
            guard let recordToSave = baseRecord.copy() as? CKRecord else {
                throw CKError(.internalError)
            }
            let currentCount = intValue(baseRecord["count"])
            let currentWordCount = intValue(baseRecord["wordCount"])
            recordToSave["count"] = currentCount + releaseIncrement
            recordToSave["wordCount"] = currentWordCount + wordIncrement
            do {
                _ = try await database.save(recordToSave)
                return
            } catch let error as CKError {
                if error.code == .serverRecordChanged, let serverRecord = error.serverRecord {
                    baseRecord = serverRecord
                    continue
                }
                if attemptsRemaining > 0, let delay = retryDelay(for: error) {
                    try? await Task.sleep(for: .seconds(delay))
                    continue
                }
                if attemptsRemaining == 0 {
                    debugLog(
                        "[GlobalReleaseCount] save failed code=\(error.code.rawValue) " +
                        "releaseIncrement=\(releaseIncrement) wordIncrement=\(wordIncrement)"
                    )
                }
                throw error
            } catch {
                logCloudKitError(
                    "save failed releaseIncrement=\(releaseIncrement) wordIncrement=\(wordIncrement)",
                    error: error
                )
                throw error
            }
        }
    }

    private func canContributeToGlobalStats() async throws -> Bool {
        let status = try await container.accountStatus()
        return status == .available
    }

    private func retryDelay(for error: CKError) -> TimeInterval? {
        if let retryAfter = error.userInfo[CKErrorRetryAfterKey] as? TimeInterval {
            return max(0.25, min(2.0, retryAfter))
        }
        switch error.code {
        case .networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return 0.5
        default:
            return nil
        }
    }

    private func intValue(_ value: Any?) -> Int {
        if let intValue = value as? Int {
            return intValue
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return 0
    }

    private func logCloudKitError(_ context: String, error: Error) {
        let nsError = error as NSError
        debugLog(
            "[GlobalReleaseCount] \(context) " +
            "domain=\(nsError.domain) code=\(nsError.code) localized=\(nsError.localizedDescription)"
        )
        if !nsError.userInfo.isEmpty {
            debugLog("[GlobalReleaseCount] userInfo=\(nsError.userInfo)")
        }
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

    static func hourKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HH"
        return formatter.string(from: date)
    }

    static func hourKeysForLocalToday(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [String] {
        let startOfDay = calendar.startOfDay(for: now)
        let utcCalendar: Calendar = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(secondsFromGMT: 0)!
            return cal
        }()
        let hoursBetween = utcCalendar.dateComponents([.hour], from: startOfDay, to: now).hour ?? 0

        return (0...hoursBetween).compactMap { offset in
            guard let hour = utcCalendar.date(byAdding: .hour, value: offset, to: startOfDay) else {
                return nil
            }
            return hourKey(for: hour)
        }
    }
}
