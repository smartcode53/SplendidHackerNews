import Foundation

actor SmartFeedStore {
    static let shared = SmartFeedStore()

    private struct PersistedAffinity: Codable {
        var domainOpenCounts: [String: Int]
        var authorOpenCounts: [String: Int]
        var keywordOpenCounts: [String: Int]
    }

    private var domainOpenCounts: [String: Int] = [:]
    private var authorOpenCounts: [String: Int] = [:]
    private var keywordOpenCounts: [String: Int] = [:]

    private let fileURL = FileManager.default.documentsDirectory.appending(component: "smart_feed_affinity.json")

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(PersistedAffinity.self, from: data) {
            domainOpenCounts = decoded.domainOpenCounts
            authorOpenCounts = decoded.authorOpenCounts
            keywordOpenCounts = decoded.keywordOpenCounts
        }
    }

    func recordOpen(story: Story) {
        if let domain = normalizedDomain(from: story.url), !domain.isEmpty {
            domainOpenCounts[domain, default: 0] += 1
        }

        let author = story.by.lowercased()
        authorOpenCounts[author, default: 0] += 1

        for keyword in extractKeywords(from: story.title) {
            keywordOpenCounts[keyword, default: 0] += 1
        }

        persist()
    }

    func snapshot() -> SmartFeedRanker.AffinitySnapshot {
        SmartFeedRanker.AffinitySnapshot(
            domainOpenCounts: domainOpenCounts,
            authorOpenCounts: authorOpenCounts,
            keywordOpenCounts: keywordOpenCounts
        )
    }

    private func persist() {
        let payload = PersistedAffinity(
            domainOpenCounts: domainOpenCounts,
            authorOpenCounts: authorOpenCounts,
            keywordOpenCounts: keywordOpenCounts
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func normalizedDomain(from rawURL: String?) -> String? {
        guard let rawURL, let url = URL(string: rawURL), let host = url.host else { return nil }
        return host.lowercased().replacingOccurrences(of: "www.", with: "")
    }

    private func extractKeywords(from text: String) -> [String] {
        let stopWords: Set<String> = [
            "the", "and", "for", "with", "this", "that", "from", "your", "have", "into", "about",
            "what", "when", "where", "why", "how", "are", "was", "were", "will", "would", "could"
        ]

        let words = text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 3 }
            .filter { !stopWords.contains($0) }

        return Array(Set(words))
    }
}
