import Foundation

actor StoryCache {
    private let ttl: TimeInterval = 10 * 60
    private var storage: [Int: (story: Story, expiresAt: Date)] = [:]
    
    func story(for id: Int) -> Story? {
        guard let entry = storage[id] else { return nil }
        if Date() > entry.expiresAt {
            storage[id] = nil
            return nil
        }
        return entry.story
    }
    
    func set(_ story: Story) {
        storage[story.id] = (story, Date().addingTimeInterval(ttl))
    }
    
    func clear() {
        storage.removeAll()
    }
}

struct StoryRepository {
    private let client: HNAPIClient
    private let cache: StoryCache

    /// Maximum concurrent network requests for story fetching.
    /// HNAPIClient now handles the sliding-window concurrency internally,
    /// so we pass all missing IDs in a single call instead of chunking.
    private let maxConcurrent = 20

    init(client: HNAPIClient = HNAPIClient(), cache: StoryCache = StoryCache()) {
        self.client = client
        self.cache = cache
    }

    func fetchIDs(type: StoryType) async throws -> [Int] {
        try await client.fetchStoryIDs(type: type)
    }

    /// Fetches stories for the given IDs, using the actor-based TTL cache.
    /// Cache hits are served immediately; cache misses are fetched in a
    /// single concurrent pass (bounded by maxConcurrent in HNAPIClient).
    /// Previously: 4 sequential round-trips for 30 stories (chunks of 8).
    /// Now: 1-2 concurrent waves via sliding-window TaskGroup.
    func fetchStories(ids: [Int]) async throws -> [Story] {
        var results: [Int: Story] = [:]
        results.reserveCapacity(ids.count)
        var missing: [Int] = []

        for id in ids {
            if let cached = await cache.story(for: id) {
                results[id] = cached
            } else {
                missing.append(id)
            }
        }

        if !missing.isEmpty {
            // Single call: HNAPIClient.fetchStories handles concurrency limiting internally
            let fetched = try await client.fetchStories(ids: missing, maxConcurrent: maxConcurrent)
            for story in fetched {
                results[story.id] = story
                await cache.set(story)
            }
        }

        return ids.compactMap { results[$0] }
    }

    func clearCache() async {
        await cache.clear()
    }
}
