import Foundation
import SwiftUI

struct ReaderContent: Hashable {
    let title: String
    let urlString: String
    let domain: String?
    let blocks: [ReaderBlock]
    let isTruncated: Bool
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
    @Published var loadState: LoadState = .idle
    @Published var content: ReaderContent?
#if DEBUG
    @Published var lastUpdated: Date?
#endif

    let sourceTitle: String
    let safeURL: URL?

    private let extractor: ReaderExtractor
    private let cache: ReaderContentCache
    private let networkManager = NetworkManager.instance
#if DEBUG
    private let debugForceBadURL = false
    private let debugBadURL = URL(string: "https://example.invalid")!
#endif

    init(story: Story, extractor: ReaderExtractor = ReaderExtractor(), cache: ReaderContentCache = .shared) {
        self.sourceTitle = story.title
        self.extractor = extractor
        self.cache = cache
        if let urlString = story.url {
            let secureString = networkManager.getSecureUrlString(url: urlString)
            self.safeURL = URL(string: secureString)
        } else {
            self.safeURL = nil
        }
    }

    init(url: URL, title: String, extractor: ReaderExtractor = ReaderExtractor(), cache: ReaderContentCache = .shared) {
        self.sourceTitle = title
        self.extractor = extractor
        self.cache = cache
        let secureString = networkManager.getSecureUrlString(url: url.absoluteString)
        self.safeURL = URL(string: secureString)
    }

    func load(force: Bool = false) async {
        #if DEBUG
        if DebugEnvironment.shared.fixtureMode {
            let url = safeURL ?? DebugEnvironment.shared.fixtureURL
            let content = DebugFixtures.readerContent(url: url, title: sourceTitle)
            self.content = content
            loadState = .loaded
            lastUpdated = Date()
            return
        }
        #endif
        guard let safeURL else {
            loadState = .error(message: "This story doesn't have a URL.", canRetry: false)
#if DEBUG
            lastUpdated = Date()
#endif
            return
        }

        if !force, let cached = cache.content(for: cacheKey(for: safeURL)) {
            content = cached
            loadState = .loaded
#if DEBUG
            lastUpdated = Date()
#endif
            return
        }

        content = nil
        loadState = .loading

        do {
            let targetURL: URL
#if DEBUG
            targetURL = debugForceBadURL ? debugBadURL : safeURL
#else
            targetURL = safeURL
#endif
            let result = try await RetryPolicy.runWithTransientRetry { [self] in
                try await extractor.extract(from: targetURL)
            }
            if result.blocks.isEmpty {
                content = nil
                loadState = .empty
#if DEBUG
                lastUpdated = Date()
#endif
                return
            }
            let domain = targetURL.host
            let content = ReaderContent(
                title: sourceTitle,
                urlString: targetURL.absoluteString,
                domain: domain,
                blocks: result.blocks,
                isTruncated: result.isTruncated
            )
            cache.store(content, for: cacheKey(for: safeURL))
            self.content = content
            loadState = .loaded
#if DEBUG
            lastUpdated = Date()
#endif
        } catch {
            content = nil
            if let extractorError = error as? ReaderExtractorError, extractorError == .emptyContent {
                loadState = .empty
            } else {
                let message = ErrorPresenter.message(
                    for: error,
                    defaultMessage: "Check your connection and try again.",
                    debugTag: "READER_FETCH"
                )
                loadState = .error(message: message, canRetry: true)
            }
#if DEBUG
            lastUpdated = Date()
#endif
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
