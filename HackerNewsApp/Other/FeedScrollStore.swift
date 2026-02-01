import Foundation

actor FeedScrollStore {
    static let shared = FeedScrollStore()

    private struct PersistedState: Codable {
        var lastSeenStoryIDByFeed: [String: Int]
        var lastUpdatedAtByFeed: [String: Date]
    }

    private var lastSeenStoryIDByFeed: [String: Int] = [:]
    private var lastUpdatedAtByFeed: [String: Date] = [:]
    private let fileUrl = FileManager.default.documentsDirectory.appending(component: "feed_scroll.json")

    init() {
        if let decoded = Self.loadFromDisk(fileUrl: fileUrl) {
            lastSeenStoryIDByFeed = decoded.lastSeenStoryIDByFeed
            lastUpdatedAtByFeed = decoded.lastUpdatedAtByFeed
        }
    }

    func setLastSeen(feed: StoryType, storyID: Int) {
        lastSeenStoryIDByFeed[feed.rawValue] = storyID
        lastUpdatedAtByFeed[feed.rawValue] = Date()
        saveToDisk()
    }

    func getLastSeen(feed: StoryType) -> Int? {
        lastSeenStoryIDByFeed[feed.rawValue]
    }

    func clear(feed: StoryType) {
        lastSeenStoryIDByFeed.removeValue(forKey: feed.rawValue)
        lastUpdatedAtByFeed.removeValue(forKey: feed.rawValue)
        saveToDisk()
    }

    func clearAll() {
        lastSeenStoryIDByFeed.removeAll()
        lastUpdatedAtByFeed.removeAll()
        saveToDisk()
    }

    nonisolated private static func loadFromDisk(fileUrl: URL) -> PersistedState? {
        guard let data = try? Data(contentsOf: fileUrl) else { return nil }
        return try? JSONDecoder().decode(PersistedState.self, from: data)
    }

    private func saveToDisk() {
        let payload = PersistedState(
            lastSeenStoryIDByFeed: lastSeenStoryIDByFeed,
            lastUpdatedAtByFeed: lastUpdatedAtByFeed
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileUrl, options: [.atomic])
    }
}
