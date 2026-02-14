import Foundation

struct HNUser: Codable {
    let id: String
    let created: Int
    let karma: Int
    let about: String?
    let submitted: [Int]

    enum CodingKeys: String, CodingKey {
        case id
        case created
        case karma
        case about
        case submitted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        created = try container.decodeIfPresent(Int.self, forKey: .created) ?? 0
        karma = try container.decodeIfPresent(Int.self, forKey: .karma) ?? 0
        about = try container.decodeIfPresent(String.self, forKey: .about)
        submitted = try container.decodeIfPresent([Int].self, forKey: .submitted) ?? []
    }
}

struct HNUserSubmission: Codable, Identifiable {
    let id: Int
    let by: String?
    let type: String?
    let time: Int?
    let title: String?
    let text: String?
    let url: String?
    let score: Int?
}

struct HNAPIClient {
    private let defaultBaseURL = URL(string: "https://hacker-news.firebaseio.com/v0")!
#if DEBUG
    private let debugForceBadBaseURL = false
    private let debugBadBaseURL = URL(string: "https://example.invalid")!
#endif
    private let session: URLSession
    private let decoder: JSONDecoder

    /// A shared, optimized URLSession for HN Firebase API calls.
    /// - httpMaximumConnectionsPerHost = 12 (up from default 4-6) to allow
    ///   more concurrent story fetches against hacker-news.firebaseio.com.
    /// - timeoutIntervalForRequest = 15s for faster failure detection.
    /// - waitsForConnectivity = true so requests queue instead of failing
    ///   immediately when the network is momentarily unreachable.
    static let optimizedSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 12
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    private var baseURL: URL {
#if DEBUG
        if debugForceBadBaseURL {
            return debugBadBaseURL
        }
#endif
        return defaultBaseURL
    }

    init(session: URLSession = HNAPIClient.optimizedSession) {
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

    func fetchUser(id: String) async throws -> HNUser {
        let url = baseURL.appendingPathComponent("user/\(id).json")
        let (data, _) = try await session.data(from: url)
        guard let user = try decoder.decode(HNUser?.self, from: data) else {
            throw URLError(.resourceUnavailable)
        }
        return user
    }

    func fetchUserSubmission(id: Int) async throws -> HNUserSubmission? {
        let url = baseURL.appendingPathComponent("item/\(id).json")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(HNUserSubmission?.self, from: data)
    }
    
    /// Fetches stories for the given IDs with bounded concurrency.
    /// Uses a sliding-window TaskGroup: up to `maxConcurrent` requests in
    /// flight at once. This keeps connection pressure manageable while
    /// being much faster than sequential chunk processing.
    /// Time: O(n) network calls with O(maxConcurrent) parallelism.
    func fetchStories(ids: [Int], maxConcurrent: Int = 20) async throws -> [Story] {
        guard !ids.isEmpty else { return [] }
        return try await withThrowingTaskGroup(of: Story.self) { group in
            var results: [Story] = []
            results.reserveCapacity(ids.count)
            var iterator = ids.makeIterator()

            // Seed the group with up to maxConcurrent tasks
            for _ in 0..<min(maxConcurrent, ids.count) {
                guard let id = iterator.next() else { break }
                group.addTask { try await self.fetchStory(id: id) }
            }

            // As each task completes, add the next one (sliding window)
            for try await story in group {
                results.append(story)
                if let id = iterator.next() {
                    group.addTask { try await self.fetchStory(id: id) }
                }
            }

            return results
        }
    }
}
