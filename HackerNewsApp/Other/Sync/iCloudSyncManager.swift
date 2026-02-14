import Foundation

actor iCloudSyncManager {
    static let shared = iCloudSyncManager()

    struct SettingsRecord: Codable {
        let settings: Settings
        let updatedAt: Date
    }

    struct ReadStateRecord: Codable {
        let readIDs: [Int]
        let hideReadByFeed: [String: Bool]
        let filtersByFeed: [String: FeedFilter]
        let updatedAt: Date
    }

    struct BookmarksRecord: Codable {
        let bookmarks: [Bookmark]
        let updatedAt: Date
    }

    private enum Key {
        static let settings = "sync.settings"
        static let readState = "sync.read_state"
        static let bookmarks = "sync.bookmarks"
    }

    private let store = NSUbiquitousKeyValueStore.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func pushSettings(_ settings: Settings, updatedAt: Date = Date()) {
        guard let data = try? encoder.encode(SettingsRecord(settings: settings, updatedAt: updatedAt)) else { return }
        store.set(data, forKey: Key.settings)
        store.synchronize()
    }

    func fetchSettingsRecord() -> SettingsRecord? {
        guard let data = store.data(forKey: Key.settings) else { return nil }
        return try? decoder.decode(SettingsRecord.self, from: data)
    }

    func pushReadState(readIDs: Set<Int>, hideReadByFeed: [String: Bool], filtersByFeed: [String: FeedFilter], updatedAt: Date = Date()) {
        let record = ReadStateRecord(
            readIDs: Array(readIDs),
            hideReadByFeed: hideReadByFeed,
            filtersByFeed: filtersByFeed,
            updatedAt: updatedAt
        )
        guard let data = try? encoder.encode(record) else { return }
        store.set(data, forKey: Key.readState)
        store.synchronize()
    }

    func fetchReadStateRecord() -> ReadStateRecord? {
        guard let data = store.data(forKey: Key.readState) else { return nil }
        return try? decoder.decode(ReadStateRecord.self, from: data)
    }

    func pushBookmarks(_ bookmarks: [Bookmark], updatedAt: Date = Date()) {
        let record = BookmarksRecord(bookmarks: bookmarks, updatedAt: updatedAt)
        guard let data = try? encoder.encode(record) else { return }
        store.set(data, forKey: Key.bookmarks)
        store.synchronize()
    }

    func fetchBookmarksRecord() -> BookmarksRecord? {
        guard let data = store.data(forKey: Key.bookmarks) else { return nil }
        return try? decoder.decode(BookmarksRecord.self, from: data)
    }

    func mergeReadState(local: ReadStateRecord, remote: ReadStateRecord) -> ReadStateRecord {
        let mergedReadIDs = Set(local.readIDs).union(remote.readIDs)
        let preferRemote = remote.updatedAt >= local.updatedAt

        return ReadStateRecord(
            readIDs: Array(mergedReadIDs),
            hideReadByFeed: preferRemote ? remote.hideReadByFeed : local.hideReadByFeed,
            filtersByFeed: preferRemote ? remote.filtersByFeed : local.filtersByFeed,
            updatedAt: max(local.updatedAt, remote.updatedAt)
        )
    }

    func mergeBookmarks(local: BookmarksRecord, remote: BookmarksRecord) -> BookmarksRecord {
        var mergedByStoryID: [Int: Bookmark] = [:]

        for bookmark in local.bookmarks {
            mergedByStoryID[bookmark.story.id] = bookmark
        }

        for bookmark in remote.bookmarks {
            if let existing = mergedByStoryID[bookmark.story.id] {
                mergedByStoryID[bookmark.story.id] = bookmark.date > existing.date ? bookmark : existing
            } else {
                mergedByStoryID[bookmark.story.id] = bookmark
            }
        }

        let merged = mergedByStoryID.values.sorted { $0.date > $1.date }
        return BookmarksRecord(bookmarks: merged, updatedAt: max(local.updatedAt, remote.updatedAt))
    }
}
