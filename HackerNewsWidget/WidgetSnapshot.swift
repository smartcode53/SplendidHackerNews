import Foundation

struct WidgetSnapshot: Codable {
    let generatedAt: Date
    let bookmarkCount: Int
    let historyCount: Int
    let trackedThreadsCount: Int
    let topBookmarkTitle: String?
}
