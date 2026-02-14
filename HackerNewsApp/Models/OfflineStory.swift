import Foundation

struct OfflineStory: Codable, Identifiable {
    let storyID: Int
    let title: String
    let author: String
    let urlString: String?
    let savedAt: Date
    let readerContent: String
    let imageData: Data?
    let commentsSnapshot: Item?

    var id: Int { storyID }
}
