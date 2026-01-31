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
        loadFromDisk()
    }
    
    func addEntry(story: Story, feed: StoryType) {
        let entry = HistoryEntry(
            id: UUID(),
            storyID: story.id,
            title: story.title,
            url: story.url,
            openedAt: Int(Date().timeIntervalSince1970),
            feed: feed.rawValue
        )
        entries.insert(entry, at: 0)
        saveToDisk()
    }
    
    func allEntries() -> [HistoryEntry] {
        entries
    }
    
    func clear() {
        entries.removeAll()
        saveToDisk()
    }
    
    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileUrl) else { return }
        guard let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        entries = decoded
    }
    
    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileUrl, options: [.atomic])
    }
}
