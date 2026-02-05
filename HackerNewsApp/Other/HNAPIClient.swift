import Foundation

struct HNAPIClient {
    private let defaultBaseURL = URL(string: "https://hacker-news.firebaseio.com/v0")!
#if DEBUG
    private let debugForceBadBaseURL = false
    private let debugBadBaseURL = URL(string: "https://example.invalid")!
#endif
    private let session: URLSession
    private let decoder: JSONDecoder

    private var baseURL: URL {
#if DEBUG
        if debugForceBadBaseURL {
            return debugBadBaseURL
        }
#endif
        return defaultBaseURL
    }
    
    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }
    
    func fetchStoryIDs(type: StoryType) async throws -> [Int] {
        let url = baseURL.appendingPathComponent("\(type.endpoint).json")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode([Int].self, from: data)
    }
    
    func fetchStory(id: Int) async throws -> Story {
        let url = baseURL.appendingPathComponent("item/\(id).json")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(Story.self, from: data)
    }
    
    func fetchStories(ids: [Int]) async throws -> [Story] {
        try await withThrowingTaskGroup(of: Story.self) { group in
            for id in ids {
                group.addTask {
                    try await fetchStory(id: id)
                }
            }
            var results: [Story] = []
            for try await story in group {
                results.append(story)
            }
            return results
        }
    }
}
