import Foundation

struct HistoryEntry: Codable, Identifiable {
    let id: UUID
    let storyID: Int
    let title: String
    let url: String?
    let openedAt: Int
    let feed: String
}

actor HistoryStore {
    static let shared = HistoryStore()
    
    private var entries: [HistoryEntry] = []
    private let fileUrl = FileManager.default.documentsDirectory.appending(component: "history.json")
    
    init() {
        if let decoded = Self.loadFromDisk(fileUrl: fileUrl) {
            entries = decoded
        }
    }
    
    func addEntry(story: Story, feed: StoryType) async {
        let entry = HistoryEntry(
            id: UUID(),
            storyID: story.id,
            title: story.title,
            url: story.url,
            openedAt: Int(Date().timeIntervalSince1970),
            feed: feed.rawValue
        )
        entries.insert(entry, at: 0)
        await SmartFeedStore.shared.recordOpen(story: story)
        saveToDisk()
        await SpotlightIndexer.shared.indexHistory(entries)
        await WidgetDataProvider.shared.refreshFromDisk()
    }
    
    func allEntries() -> [HistoryEntry] {
        entries
    }
    
    func clear() async {
        entries.removeAll()
        saveToDisk()
        await SpotlightIndexer.shared.indexHistory([])
        await WidgetDataProvider.shared.refreshFromDisk()
    }
    
    nonisolated private static func loadFromDisk(fileUrl: URL) -> [HistoryEntry]? {
        guard let data = try? Data(contentsOf: fileUrl) else { return nil }
        return try? JSONDecoder().decode([HistoryEntry].self, from: data)
    }
    
    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileUrl, options: [.atomic])
    }
}
