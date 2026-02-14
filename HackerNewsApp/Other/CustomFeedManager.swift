import Foundation
import Combine

struct CustomFeed: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var storyTypeRawValue: String
    var filter: FeedFilter?

    init(id: UUID = UUID(), name: String, storyType: StoryType, filter: FeedFilter?) {
        self.id = id
        self.name = name
        self.storyTypeRawValue = storyType.rawValue
        self.filter = filter?.normalized()
    }

    var storyType: StoryType {
        get { StoryType(rawValue: storyTypeRawValue) ?? .topstories }
        set { storyTypeRawValue = newValue.rawValue }
    }
}

@MainActor
final class CustomFeedManager: ObservableObject {
    static let shared = CustomFeedManager()

    @Published private(set) var feeds: [CustomFeed] = []

    private let fileURL = FileManager.default.documentsDirectory.appending(component: "custom_feeds.json")

    private init() {
        load()
    }

    func upsert(_ feed: CustomFeed) {
        if let index = feeds.firstIndex(where: { $0.id == feed.id }) {
            feeds[index] = feed
        } else {
            feeds.append(feed)
        }
        save()
    }

    func remove(id: UUID) {
        feeds.removeAll { $0.id == id }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        feeds.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([CustomFeed].self, from: data) else {
            feeds = []
            return
        }
        feeds = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(feeds) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
