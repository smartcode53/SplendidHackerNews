import Foundation

actor ReadStateStore {
    static let shared = ReadStateStore()
    
    private struct PersistedState: Codable {
        var readIDs: [Int]
        var hideReadByFeed: [String: Bool]
        var filtersByFeed: [String: FeedFilter]
        var lastUpdatedAt: Date

        init(readIDs: [Int], hideReadByFeed: [String: Bool], filtersByFeed: [String: FeedFilter], lastUpdatedAt: Date) {
            self.readIDs = readIDs
            self.hideReadByFeed = hideReadByFeed
            self.filtersByFeed = filtersByFeed
            self.lastUpdatedAt = lastUpdatedAt
        }

        enum CodingKeys: String, CodingKey {
            case readIDs
            case hideReadByFeed
            case filtersByFeed
            case lastUpdatedAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            readIDs = try container.decodeIfPresent([Int].self, forKey: .readIDs) ?? []
            hideReadByFeed = try container.decodeIfPresent([String: Bool].self, forKey: .hideReadByFeed) ?? [:]
            filtersByFeed = try container.decodeIfPresent([String: FeedFilter].self, forKey: .filtersByFeed) ?? [:]
            lastUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt) ?? Date()
        }
    }
    
    private var readIDs: Set<Int> = []
    private var hideReadByFeed: [String: Bool] = [:]
    private var filtersByFeed: [String: FeedFilter] = [:]
    private var iCloudSyncEnabled = false
    private let syncManager = iCloudSyncManager.shared
    private var lastSyncedAt: Date = .distantPast
    private let fileUrl = FileManager.default.documentsDirectory.appending(component: "read_state.json")
    private let defaults = UserDefaults.standard
    private let hideReadDefaultsKey = "feed.hideRead.defaultsApplied"
    
    init() {
        if let decoded = Self.loadFromDisk(fileUrl: fileUrl) {
            readIDs = Set(decoded.readIDs)
            hideReadByFeed = decoded.hideReadByFeed
            filtersByFeed = decoded.filtersByFeed
        }

        if !defaults.bool(forKey: hideReadDefaultsKey) {
            hideReadByFeed = Dictionary(uniqueKeysWithValues: StoryType.allCases.map { ($0.rawValue, false) })
            defaults.set(true, forKey: hideReadDefaultsKey)
            let payload = PersistedState(
                readIDs: Array(readIDs),
                hideReadByFeed: hideReadByFeed,
                filtersByFeed: filtersByFeed,
                lastUpdatedAt: Date()
            )
            Self.saveToDisk(payload, to: fileUrl)
        }
    }
    
    func markRead(storyID: Int) {
        readIDs.insert(storyID)
        saveToDisk()
        syncToICloudIfNeeded()
    }
    
    func isRead(_ storyID: Int) -> Bool {
        readIDs.contains(storyID)
    }
    
    func readIDsSnapshot() -> Set<Int> {
        readIDs
    }
    
    func hideRead(for feed: StoryType) -> Bool {
        hideReadByFeed[feed.rawValue] ?? false
    }
    
    func setHideRead(for feed: StoryType, value: Bool) {
        hideReadByFeed[feed.rawValue] = value
        saveToDisk()
        syncToICloudIfNeeded()
    }

    func filter(for feed: StoryType) -> FeedFilter? {
        filtersByFeed[feed.rawValue]
    }

    func setFilter(for feed: StoryType, value: FeedFilter?) {
        filtersByFeed[feed.rawValue] = value
        saveToDisk()
        syncToICloudIfNeeded()
    }
    
    func clear() {
        readIDs.removeAll()
        hideReadByFeed.removeAll()
        filtersByFeed.removeAll()
        saveToDisk()
        syncToICloudIfNeeded()
    }

    func configureICloudSync(enabled: Bool) async {
        iCloudSyncEnabled = enabled
        guard enabled else { return }
        await pullFromICloudIfNeeded()
        syncToICloudIfNeeded()
    }

    func pullFromICloudIfNeeded() async {
        guard iCloudSyncEnabled else { return }

        let localRecord = iCloudSyncManager.ReadStateRecord(
            readIDs: Array(readIDs),
            hideReadByFeed: hideReadByFeed,
            filtersByFeed: filtersByFeed,
            updatedAt: lastSyncedAt
        )

        guard let remoteRecord = await syncManager.fetchReadStateRecord() else { return }
        let merged = await syncManager.mergeReadState(local: localRecord, remote: remoteRecord)

        readIDs = Set(merged.readIDs)
        hideReadByFeed = merged.hideReadByFeed
        filtersByFeed = merged.filtersByFeed
        lastSyncedAt = merged.updatedAt
        saveToDisk()
    }
    
    nonisolated private static func loadFromDisk(fileUrl: URL) -> PersistedState? {
        guard let data = try? Data(contentsOf: fileUrl) else { return nil }
        return try? JSONDecoder().decode(PersistedState.self, from: data)
    }
    
    private func saveToDisk() {
        let payload = PersistedState(
            readIDs: Array(readIDs),
            hideReadByFeed: hideReadByFeed,
            filtersByFeed: filtersByFeed,
            lastUpdatedAt: Date()
        )
        Self.saveToDisk(payload, to: fileUrl)
    }

    private func syncToICloudIfNeeded() {
        guard iCloudSyncEnabled else { return }
        let snapshotReadIDs = readIDs
        let snapshotHideRead = hideReadByFeed
        let snapshotFilters = filtersByFeed
        let now = Date()
        lastSyncedAt = now

        Task {
            await syncManager.pushReadState(
                readIDs: snapshotReadIDs,
                hideReadByFeed: snapshotHideRead,
                filtersByFeed: snapshotFilters,
                updatedAt: now
            )
        }
    }

    nonisolated private static func saveToDisk(_ payload: PersistedState, to fileUrl: URL) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileUrl, options: [.atomic])
    }
}
