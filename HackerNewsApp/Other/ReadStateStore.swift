import Foundation

actor ReadStateStore {
    static let shared = ReadStateStore()
    
    private struct PersistedState: Codable {
        var readIDs: [Int]
        var hideReadByFeed: [String: Bool]
        var lastUpdatedAt: Date
    }
    
    private var readIDs: Set<Int> = []
    private var hideReadByFeed: [String: Bool] = [:]
    private let fileUrl = FileManager.default.documentsDirectory.appending(component: "read_state.json")
    
    init() {
        if let decoded = Self.loadFromDisk(fileUrl: fileUrl) {
            readIDs = Set(decoded.readIDs)
            hideReadByFeed = decoded.hideReadByFeed
        }
    }
    
    func markRead(storyID: Int) {
        readIDs.insert(storyID)
        saveToDisk()
    }
    
    func isRead(_ storyID: Int) -> Bool {
        readIDs.contains(storyID)
    }
    
    func readIDsSnapshot() -> Set<Int> {
        readIDs
    }
    
    func hideRead(for feed: StoryType) -> Bool {
        hideReadByFeed[feed.rawValue] ?? false
    }
    
    func setHideRead(for feed: StoryType, value: Bool) {
        hideReadByFeed[feed.rawValue] = value
        saveToDisk()
    }
    
    func clear() {
        readIDs.removeAll()
        hideReadByFeed.removeAll()
        saveToDisk()
    }
    
    nonisolated private static func loadFromDisk(fileUrl: URL) -> PersistedState? {
        guard let data = try? Data(contentsOf: fileUrl) else { return nil }
        return try? JSONDecoder().decode(PersistedState.self, from: data)
    }
    
    private func saveToDisk() {
        let payload = PersistedState(
            readIDs: Array(readIDs),
            hideReadByFeed: hideReadByFeed,
            lastUpdatedAt: Date()
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileUrl, options: [.atomic])
    }
}
