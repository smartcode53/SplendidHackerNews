import Foundation

actor CommentsScrollStore {
    static let shared = CommentsScrollStore()

    private var lastSeenCommentIDByStory: [Int: Int] = [:]

    func setLastSeen(storyID: Int, commentID: Int) {
        lastSeenCommentIDByStory[storyID] = commentID
    }

    func getLastSeen(storyID: Int) -> Int? {
        lastSeenCommentIDByStory[storyID]
    }

    func clear(storyID: Int) {
        lastSeenCommentIDByStory.removeValue(forKey: storyID)
    }

    func clearAll() {
        lastSeenCommentIDByStory.removeAll()
    }
}
