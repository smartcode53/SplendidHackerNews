import Foundation

actor FeedScrollStore {
    static let shared = FeedScrollStore()

    private var lastSeenStoryIDByFeed: [String: Int] = [:]
    private var lastUpdatedAtByFeed: [String: Date] = [:]

    func setLastSeen(feed: StoryType, storyID: Int) {
        lastSeenStoryIDByFeed[feed.rawValue] = storyID
        lastUpdatedAtByFeed[feed.rawValue] = Date()
    }

    func getLastSeen(feed: StoryType) -> Int? {
        lastSeenStoryIDByFeed[feed.rawValue]
    }

    func clear(feed: StoryType) {
        lastSeenStoryIDByFeed.removeValue(forKey: feed.rawValue)
        lastUpdatedAtByFeed.removeValue(forKey: feed.rawValue)
    }

    func clearAll() {
        lastSeenStoryIDByFeed.removeAll()
        lastUpdatedAtByFeed.removeAll()
    }
}
