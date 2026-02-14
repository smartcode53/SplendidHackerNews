import Foundation

struct HNAlgoliaClient {
    private let baseURL = URL(string: "https://hn.algolia.com/api/v1/search")!
    private let session = URLSession.shared

    struct SearchFilters: Equatable {
        enum DateRange: String, CaseIterable {
            case any = "Any"
            case last24Hours = "24h"
            case last7Days = "7d"
            case last30Days = "30d"

            func threshold(now: Date = Date()) -> Int? {
                switch self {
                case .any:
                    return nil
                case .last24Hours:
                    return Int(now.addingTimeInterval(-24 * 60 * 60).timeIntervalSince1970)
                case .last7Days:
                    return Int(now.addingTimeInterval(-7 * 24 * 60 * 60).timeIntervalSince1970)
                case .last30Days:
                    return Int(now.addingTimeInterval(-30 * 24 * 60 * 60).timeIntervalSince1970)
                }
            }
        }

        var dateRange: DateRange = .any
        var minPoints: Int?
        var author: String = ""
        var domain: String = ""
    }

    struct SearchResult: Hashable {
        enum Kind: String {
            case story
            case comment
        }

        let id: Int
        let kind: Kind
        let title: String
        let subtitle: String
        let url: URL?
        let storyID: Int?
    }

    private struct AlgoliaResponse: Decodable {
        let hits: [AlgoliaHit]
        let page: Int
        let nbPages: Int
    }

    private struct AlgoliaHit: Decodable {
        let objectID: String
        let title: String?
        let story_title: String?
        let url: String?
        let story_url: String?
        let author: String?
        let points: Int?
        let created_at_i: Int?
        let story_id: Int?
        let comment_text: String?
    }

    struct SearchPage {
        let results: [SearchResult]
        let page: Int
        let totalPages: Int
    }

    func search(query: String, page: Int, filters: SearchFilters) async throws -> SearchPage {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return SearchPage(results: [], page: 0, totalPages: 0)
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "hitsPerPage", value: "30")
        ]

        var numeric: [String] = []
        if let minPoints = filters.minPoints, minPoints > 0 {
            numeric.append("points>\(minPoints - 1)")
        }
        if let threshold = filters.dateRange.threshold() {
            numeric.append("created_at_i>\(threshold)")
        }
        if !numeric.isEmpty {
            queryItems.append(URLQueryItem(name: "numericFilters", value: numeric.joined(separator: ",")))
        }

        components.queryItems = queryItems
        guard let url = components.url else {
            return SearchPage(results: [], page: 0, totalPages: 0)
        }

        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode(AlgoliaResponse.self, from: data)
        let mapped = decoded.hits.compactMap { mapHit($0, filters: filters) }
        return SearchPage(results: mapped, page: decoded.page, totalPages: decoded.nbPages)
    }

    private func mapHit(_ hit: AlgoliaHit, filters: SearchFilters) -> SearchResult? {
        guard let id = Int(hit.objectID) else { return nil }

        let author = (hit.author ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !filters.author.isEmpty, !author.lowercased().contains(filters.author.lowercased()) {
            return nil
        }

        let isComment = hit.story_id != nil
        let kind: SearchResult.Kind = isComment ? .comment : .story
        let title: String
        if kind == .story {
            title = hit.title ?? "Story \(id)"
        } else {
            title = hit.story_title ?? "Comment \(id)"
        }

        let rawURL = hit.url ?? hit.story_url
        let resultURL = rawURL.flatMap(URL.init(string:))
        if !filters.domain.isEmpty {
            let host = resultURL?.host?.replacingOccurrences(of: "www.", with: "") ?? ""
            if !host.lowercased().contains(filters.domain.lowercased()) {
                return nil
            }
        }

        let points = hit.points ?? 0
        let time = hit.created_at_i.map(Date.getTimeInterval(with:)) ?? "Unknown"
        let snippet: String
        if kind == .comment {
            let text = hit.comment_text ?? ""
            snippet = Self.stripHTML(text).replacingOccurrences(of: "\n", with: " ")
        } else {
            snippet = title
        }

        let subtitle = "\(author.isEmpty ? "unknown" : author) • \(points) pts • \(time)\n\(snippet)"
        return SearchResult(
            id: id,
            kind: kind,
            title: title,
            subtitle: subtitle,
            url: resultURL,
            storyID: hit.story_id
        )
    }

    private static func stripHTML(_ value: String) -> String {
        guard let data = value.data(using: .utf8) else { return value }
        if let attributed = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
        ) {
            return attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
