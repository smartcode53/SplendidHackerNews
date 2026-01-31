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
    private let maxConcurrent = 8
    
    init(client: HNAPIClient = HNAPIClient(), cache: StoryCache = StoryCache()) {
        self.client = client
        self.cache = cache
    }
    
    func fetchIDs(type: StoryType) async throws -> [Int] {
        try await client.fetchStoryIDs(type: type)
    }
    
    func fetchStories(ids: [Int]) async throws -> [Story] {
        var results: [Int: Story] = [:]
        var missing: [Int] = []
        
        for id in ids {
            if let cached = await cache.story(for: id) {
                results[id] = cached
            } else {
                missing.append(id)
            }
        }
        
        if !missing.isEmpty {
            for chunk in missing.chunked(into: maxConcurrent) {
                let fetched = try await client.fetchStories(ids: chunk)
                for story in fetched {
                    results[story.id] = story
                    await cache.set(story)
                }
            }
        }
        
        return ids.compactMap { results[$0] }
    }
    
    func clearCache() async {
        await cache.clear()
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var chunks: [[Element]] = []
        var index = startIndex
        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(Array(self[index..<end]))
            index = end
        }
        return chunks
    }
}
