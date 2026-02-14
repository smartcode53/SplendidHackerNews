import Foundation

struct FeedFilter: Codable, Equatable {
    enum DateRange: String, Codable, CaseIterable {
        case any
        case last24Hours
        case last7Days
        case last30Days

        var title: String {
            switch self {
            case .any:
                return "All"
            case .last24Hours:
                return "24h"
            case .last7Days:
                return "7d"
            case .last30Days:
                return "30d"
            }
        }

        func thresholdDate(reference: Date = Date()) -> Date? {
            switch self {
            case .any:
                return nil
            case .last24Hours:
                return Calendar.current.date(byAdding: .hour, value: -24, to: reference)
            case .last7Days:
                return Calendar.current.date(byAdding: .day, value: -7, to: reference)
            case .last30Days:
                return Calendar.current.date(byAdding: .day, value: -30, to: reference)
            }
        }
    }

    var dateRange: DateRange
    var domains: [String]
    var excludeDomains: [String]
    var minScore: Int?
    var keywords: [String]

    static let empty = FeedFilter(
        dateRange: .any,
        domains: [],
        excludeDomains: [],
        minScore: nil,
        keywords: []
    )

    var isActive: Bool {
        dateRange != .any
        || !domains.isEmpty
        || !excludeDomains.isEmpty
        || (minScore ?? 0) > 0
        || !keywords.isEmpty
    }

    func matches(_ story: Story, now: Date = Date()) -> Bool {
        if let threshold = dateRange.thresholdDate(reference: now) {
            let storyDate = Date(timeIntervalSince1970: TimeInterval(story.time))
            if storyDate < threshold {
                return false
            }
        }

        if let minScore, story.score < minScore {
            return false
        }

        let normalizedDomain = story.url.flatMap(Self.domain(from:)) ?? ""

        if !domains.isEmpty {
            let included = domains.contains { target in
                normalizedDomain == target || normalizedDomain.hasSuffix("." + target)
            }
            if !included {
                return false
            }
        }

        if !excludeDomains.isEmpty {
            let excluded = excludeDomains.contains { target in
                normalizedDomain == target || normalizedDomain.hasSuffix("." + target)
            }
            if excluded {
                return false
            }
        }

        if !keywords.isEmpty {
            let haystack = story.title.lowercased()
            let matchedKeyword = keywords.contains { keyword in
                haystack.localizedCaseInsensitiveContains(keyword)
            }
            if !matchedKeyword {
                return false
            }
        }

        return true
    }

    func normalized() -> FeedFilter {
        FeedFilter(
            dateRange: dateRange,
            domains: Self.normalize(domains),
            excludeDomains: Self.normalize(excludeDomains),
            minScore: (minScore ?? 0) > 0 ? minScore : nil,
            keywords: Self.normalize(keywords)
        )
    }

    private static func normalize(_ values: [String]) -> [String] {
        Array(
            Set(
                values
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            )
        ).sorted()
    }

    private static func domain(from rawURL: String) -> String? {
        guard let url = URL(string: rawURL) else { return nil }
        return url.host?
            .lowercased()
            .replacingOccurrences(of: "www.", with: "")
    }
}
