import Foundation

actor WidgetDataProvider {
    static let shared = WidgetDataProvider()

    private let groupID = "group.com.hackerpillar.shared"
    private let fallbackURL = FileManager.default.documentsDirectory.appending(component: "widget_snapshot.json")

    func refreshFromDisk() async {
        let bookmarksURL = FileManager.default.documentsDirectory.appending(component: "bookmark.txt")
        let historyURL = FileManager.default.documentsDirectory.appending(component: "history.json")
        let trackedURL = FileManager.default.documentsDirectory.appending(component: "tracked_stories.json")

        let bookmarks = (try? Data(contentsOf: bookmarksURL))
            .flatMap { try? JSONDecoder().decode([Bookmark].self, from: $0) } ?? []
        let history = (try? Data(contentsOf: historyURL))
            .flatMap { try? JSONDecoder().decode([HistoryEntry].self, from: $0) } ?? []
        let tracked = (try? Data(contentsOf: trackedURL))
            .flatMap { try? JSONDecoder().decode([TrackedStory].self, from: $0) } ?? []

        let snapshot = AppWidgetSnapshot(
            generatedAt: Date(),
            bookmarkCount: bookmarks.count,
            historyCount: history.count,
            trackedThreadsCount: tracked.count,
            topBookmarkTitle: bookmarks.first?.story.title
        )
        save(snapshot)
    }

    private func save(_ snapshot: AppWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            let url = container.appendingPathComponent("widget_snapshot.json")
            try? data.write(to: url, options: [.atomic])
        } else {
            try? data.write(to: fallbackURL, options: [.atomic])
        }
    }
}

private struct AppWidgetSnapshot: Codable {
    let generatedAt: Date
    let bookmarkCount: Int
    let historyCount: Int
    let trackedThreadsCount: Int
    let topBookmarkTitle: String?
}

actor ShareExtensionBridge {
    static let shared = ShareExtensionBridge()

    private let suiteName = "group.com.hackerpillar.shared"
    private let pendingURLsKey = "share.pending.urls"

    func importPendingURLs() async {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            ShareImportTelemetry.recordFailure(stage: "app_import", message: "Missing app-group defaults.")
            return
        }
        guard let pending = defaults.array(forKey: pendingURLsKey) as? [String], !pending.isEmpty else { return }

        let bookmarkFile = FileManager.default.documentsDirectory.appending(component: "bookmark.txt")
        var bookmarks: [Bookmark] = []
        if let existing = try? Data(contentsOf: bookmarkFile) {
            do {
                bookmarks = try JSONDecoder().decode([Bookmark].self, from: existing)
            } catch {
                ShareImportTelemetry.recordFailure(stage: "app_import", message: "Failed to decode bookmarks.")
                return
            }
        }

        let existingURLs = Set(bookmarks.compactMap { $0.story.url })
        var importedCount = 0
        for (index, rawURL) in pending.enumerated() {
            guard !existingURLs.contains(rawURL) else { continue }
            guard URL(string: rawURL) != nil else {
                ShareImportTelemetry.recordFailure(stage: "app_import", message: "Invalid shared URL: \(rawURL)")
                continue
            }
            let title = URL(string: rawURL)?.host?.replacingOccurrences(of: "www.", with: "") ?? "Shared Link"
            let story = Story(
                by: "shared",
                descendants: nil,
                id: Int(Date().timeIntervalSince1970) + index,
                score: 0,
                time: Int(Date().timeIntervalSince1970),
                title: title,
                type: "story",
                url: rawURL
            )
            bookmarks.insert(Bookmark(story: story), at: 0)
            importedCount += 1
        }

        do {
            let data = try JSONEncoder().encode(bookmarks)
            try data.write(to: bookmarkFile, options: [.atomic])
        } catch {
            ShareImportTelemetry.recordFailure(stage: "app_import", message: "Failed to persist imported bookmarks.")
            return
        }
        defaults.removeObject(forKey: pendingURLsKey)
        ShareImportTelemetry.recordSuccess(importedCount: importedCount)
        await WidgetDataProvider.shared.refreshFromDisk()
    }
}
