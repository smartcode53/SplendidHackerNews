import Foundation

struct SmartFeedRanker {
    struct AffinitySnapshot {
        let domainOpenCounts: [String: Int]
        let authorOpenCounts: [String: Int]
        let keywordOpenCounts: [String: Int]
    }

    static func rank(stories: [Story], affinity: AffinitySnapshot) -> [Story] {
        let maxDomain = max(affinity.domainOpenCounts.values.max() ?? 1, 1)
        let maxAuthor = max(affinity.authorOpenCounts.values.max() ?? 1, 1)
        let maxKeyword = max(affinity.keywordOpenCounts.values.max() ?? 1, 1)

        return stories.sorted { lhs, rhs in
            let lhsScore = score(lhs, affinity: affinity, maxDomain: maxDomain, maxAuthor: maxAuthor, maxKeyword: maxKeyword)
            let rhsScore = score(rhs, affinity: affinity, maxDomain: maxDomain, maxAuthor: maxAuthor, maxKeyword: maxKeyword)

            if lhsScore == rhsScore {
                return lhs.time > rhs.time
            }
            return lhsScore > rhsScore
        }
    }

    private static func score(
        _ story: Story,
        affinity: AffinitySnapshot,
        maxDomain: Int,
        maxAuthor: Int,
        maxKeyword: Int
    ) -> Double {
        let base = max(Double(story.score), 1)

        let domain = normalizedDomain(from: story.url)
        let domainAffinity = Double(affinity.domainOpenCounts[domain] ?? 0) / Double(maxDomain)

        let authorAffinity = Double(affinity.authorOpenCounts[story.by.lowercased()] ?? 0) / Double(maxAuthor)

        let storyKeywords = extractKeywords(from: story.title)
        let keywordCount = storyKeywords.reduce(into: 0) { partial, word in
            partial += affinity.keywordOpenCounts[word] ?? 0
        }
        let keywordAffinity = Double(keywordCount) / Double(maxKeyword)

        return base * (1 + (0.45 * domainAffinity) + (0.35 * authorAffinity) + (0.2 * keywordAffinity))
    }

    private static func normalizedDomain(from rawURL: String?) -> String {
        guard
            let rawURL,
            let url = URL(string: rawURL),
            let host = url.host
        else {
            return ""
        }
        return host.lowercased().replacingOccurrences(of: "www.", with: "")
    }

    private static func extractKeywords(from text: String) -> [String] {
        let stopWords: Set<String> = [
            "the", "and", "for", "with", "this", "that", "from", "your", "have", "into", "about",
            "what", "when", "where", "why", "how", "are", "was", "were", "will", "would", "could"
        ]

        let parts = text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 3 }
            .filter { !stopWords.contains($0) }

        return Array(Set(parts))
    }
}
