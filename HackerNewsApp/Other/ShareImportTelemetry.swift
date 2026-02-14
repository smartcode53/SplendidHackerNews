import Foundation

enum ShareImportTelemetry {
    struct Snapshot {
        let failureCount: Int
        let lastFailureAt: Date?
        let lastFailureMessage: String?
        let lastSuccessAt: Date?
        let lastImportedCount: Int
        let pendingCount: Int
    }

    private static let suiteName = "group.com.hackerpillar.shared"
    private static let fallbackDefaults = UserDefaults.standard
    private static let failureCountKey = "share.import.failure.count"
    private static let lastFailureAtKey = "share.import.failure.lastAt"
    private static let lastFailureMessageKey = "share.import.failure.lastMessage"
    private static let lastSuccessAtKey = "share.import.success.lastAt"
    private static let lastImportedCountKey = "share.import.success.lastImportedCount"
    private static let pendingURLsKey = "share.pending.urls"

    static func recordFailure(stage: String, message: String) {
        let defaults = telemetryDefaults()
        let current = defaults.integer(forKey: failureCountKey)
        defaults.set(current + 1, forKey: failureCountKey)
        defaults.set(Date().timeIntervalSince1970, forKey: lastFailureAtKey)
        defaults.set("[\(stage)] \(message)", forKey: lastFailureMessageKey)
    }

    static func recordSuccess(importedCount: Int) {
        let defaults = telemetryDefaults()
        defaults.set(Date().timeIntervalSince1970, forKey: lastSuccessAtKey)
        defaults.set(importedCount, forKey: lastImportedCountKey)
    }

    static func snapshot() -> Snapshot {
        let defaults = telemetryDefaults()
        let failureCount = defaults.integer(forKey: failureCountKey)
        let lastFailureTimestamp = defaults.double(forKey: lastFailureAtKey)
        let lastSuccessTimestamp = defaults.double(forKey: lastSuccessAtKey)
        let lastFailureAt = lastFailureTimestamp > 0 ? Date(timeIntervalSince1970: lastFailureTimestamp) : nil
        let lastSuccessAt = lastSuccessTimestamp > 0 ? Date(timeIntervalSince1970: lastSuccessTimestamp) : nil
        let pending = defaults.stringArray(forKey: pendingURLsKey) ?? []
        return Snapshot(
            failureCount: failureCount,
            lastFailureAt: lastFailureAt,
            lastFailureMessage: defaults.string(forKey: lastFailureMessageKey),
            lastSuccessAt: lastSuccessAt,
            lastImportedCount: defaults.integer(forKey: lastImportedCountKey),
            pendingCount: pending.count
        )
    }

    static func clearFailures() {
        let defaults = telemetryDefaults()
        defaults.set(0, forKey: failureCountKey)
        defaults.removeObject(forKey: lastFailureAtKey)
        defaults.removeObject(forKey: lastFailureMessageKey)
    }

    private static func telemetryDefaults() -> UserDefaults {
        UserDefaults(suiteName: suiteName) ?? fallbackDefaults
    }
}
