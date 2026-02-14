import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

actor SpotlightIndexer {
    static let shared = SpotlightIndexer()

    private let index = CSSearchableIndex.default()
    private let defaults = UserDefaults.standard
    private let mappingKey = "spotlight.url.mapping"
    private let bookmarksDomain = "com.hackerpillar.bookmarks"
    private let historyDomain = "com.hackerpillar.history"

    func bootstrapFromDiskIfNeeded() async {
        let bookmarksURL = FileManager.default.documentsDirectory.appending(component: "bookmark.txt")
        let historyURL = FileManager.default.documentsDirectory.appending(component: "history.json")

        if let bookmarkData = try? Data(contentsOf: bookmarksURL),
           let bookmarks = try? JSONDecoder().decode([Bookmark].self, from: bookmarkData) {
            await indexBookmarks(bookmarks)
        }

        if let historyData = try? Data(contentsOf: historyURL),
           let entries = try? JSONDecoder().decode([HistoryEntry].self, from: historyData) {
            await indexHistory(entries)
        }
    }

    func indexBookmarks(_ bookmarks: [Bookmark]) async {
        await delete(domain: bookmarksDomain)
        let items = bookmarks.compactMap { bookmark in
            makeItem(
                uniqueIdentifier: "bookmark-\(bookmark.story.id)",
                domainIdentifier: bookmarksDomain,
                title: bookmark.story.title,
                description: "Saved by \(bookmark.story.by)",
                urlString: bookmark.story.url
            )
        }
        await save(items: items)
    }

    func indexHistory(_ entries: [HistoryEntry]) async {
        await delete(domain: historyDomain)
        let items = entries.compactMap { entry in
            makeItem(
                uniqueIdentifier: "history-\(entry.storyID)-\(entry.openedAt)",
                domainIdentifier: historyDomain,
                title: entry.title,
                description: "Opened from \(entry.feed)",
                urlString: entry.url
            )
        }
        await save(items: items)
    }

    func resolveURL(for identifier: String) -> URL? {
        let mapping = defaults.dictionary(forKey: mappingKey) as? [String: String] ?? [:]
        guard let raw = mapping[identifier] else { return nil }
        return URL(string: raw)
    }

    private func makeItem(
        uniqueIdentifier: String,
        domainIdentifier: String,
        title: String,
        description: String,
        urlString: String?
    ) -> CSSearchableItem? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        let attributes = CSSearchableItemAttributeSet(contentType: .url)
        attributes.title = title
        attributes.contentDescription = description
        attributes.keywords = ["HackerPillar", "Hacker News", "HN"]
        attributes.contentURL = url

        var mapping = defaults.dictionary(forKey: mappingKey) as? [String: String] ?? [:]
        mapping[uniqueIdentifier] = url.absoluteString
        defaults.set(mapping, forKey: mappingKey)

        return CSSearchableItem(
            uniqueIdentifier: uniqueIdentifier,
            domainIdentifier: domainIdentifier,
            attributeSet: attributes
        )
    }

    private func save(items: [CSSearchableItem]) async {
        guard !items.isEmpty else { return }
        do {
            try await index.indexSearchableItems(items)
        } catch {
            return
        }
    }

    private func delete(domain: String) async {
        do {
            try await index.deleteSearchableItems(withDomainIdentifiers: [domain])
        } catch {
            return
        }
    }
}
