import Foundation

actor CommentsScrollStore {
    static let shared = CommentsScrollStore()

    private struct PersistedState: Codable {
        var lastSeenCommentIDByStory: [Int: Int]
    }

    private var lastSeenCommentIDByStory: [Int: Int] = [:]
    private let fileUrl = FileManager.default.documentsDirectory.appending(component: "comments_scroll.json")

    init() {
        if let decoded = Self.loadFromDisk(fileUrl: fileUrl) {
            lastSeenCommentIDByStory = decoded.lastSeenCommentIDByStory
        }
    }

    func setLastSeen(storyID: Int, commentID: Int) {
        lastSeenCommentIDByStory[storyID] = commentID
        saveToDisk()
    }

    func getLastSeen(storyID: Int) -> Int? {
        lastSeenCommentIDByStory[storyID]
    }

    func clear(storyID: Int) {
        lastSeenCommentIDByStory.removeValue(forKey: storyID)
        saveToDisk()
    }

    func clearAll() {
        lastSeenCommentIDByStory.removeAll()
        saveToDisk()
    }

    nonisolated private static func loadFromDisk(fileUrl: URL) -> PersistedState? {
        guard let data = try? Data(contentsOf: fileUrl) else { return nil }
        return try? JSONDecoder().decode(PersistedState.self, from: data)
    }

    private func saveToDisk() {
        let payload = PersistedState(lastSeenCommentIDByStory: lastSeenCommentIDByStory)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileUrl, options: [.atomic])
    }
}
