import Foundation
import SwiftUI

struct ReaderContent: Hashable {
    let title: String
    let urlString: String
    let domain: String?
    let blocks: [ReaderBlock]
    let isTruncated: Bool
}

enum ReaderLoadState {
    case idle
    case loading
    case success(ReaderContent)
    case failed(String)
}

final class ReaderContentCache {
    static let shared = ReaderContentCache()

    private final class ContentBox {
        let content: ReaderContent

        init(content: ReaderContent) {
            self.content = content
        }
    }

    private let cache = NSCache<NSString, ContentBox>()

    func content(for key: String) -> ReaderContent? {
        cache.object(forKey: key as NSString)?.content
    }

    func store(_ content: ReaderContent, for key: String) {
        cache.setObject(ContentBox(content: content), forKey: key as NSString)
    }

    func remove(for key: String) {
        cache.removeObject(forKey: key as NSString)
    }
}

@MainActor
final class ReaderViewModel: ObservableObject {
    @Published var state: ReaderLoadState = .idle

    let story: Story
    let safeURL: URL?

    private let extractor: ReaderExtractor
    private let cache: ReaderContentCache
    private let networkManager = NetworkManager.instance

    init(story: Story, extractor: ReaderExtractor = ReaderExtractor(), cache: ReaderContentCache = .shared) {
        self.story = story
        self.extractor = extractor
        self.cache = cache
        if let urlString = story.url {
            let secureString = networkManager.getSecureUrlString(url: urlString)
            self.safeURL = URL(string: secureString)
        } else {
            self.safeURL = nil
        }
    }

    func load(force: Bool = false) async {
        guard let safeURL else {
            state = .failed("This story doesn't have a URL.")
            return
        }

        if !force, let cached = cache.content(for: cacheKey(for: safeURL)) {
            state = .success(cached)
            return
        }

        state = .loading

        do {
            let result = try await extractor.extract(from: safeURL)
            let domain = safeURL.host
            let content = ReaderContent(
                title: story.title,
                urlString: safeURL.absoluteString,
                domain: domain,
                blocks: result.blocks,
                isTruncated: result.isTruncated
            )
            cache.store(content, for: cacheKey(for: safeURL))
            state = .success(content)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "Couldn't extract this article."
            state = .failed(message)
        }
    }

    func reload() async {
        if let safeURL {
            cache.remove(for: cacheKey(for: safeURL))
        }
        await load(force: true)
    }

    private func cacheKey(for url: URL) -> String {
        url.absoluteString
    }
}
