import Foundation
import UserNotifications

struct TrackedStory: Codable, Identifiable, Equatable {
    let id: Int
    var title: String
    var lastSeenCommentCount: Int
    var lastCheckedAt: Date

    init(storyID: Int, title: String, lastSeenCommentCount: Int, lastCheckedAt: Date = Date()) {
        self.id = storyID
        self.title = title
        self.lastSeenCommentCount = lastSeenCommentCount
        self.lastCheckedAt = lastCheckedAt
    }
}

actor NotificationStore {
    static let shared = NotificationStore()

    private let fileURL = FileManager.default.documentsDirectory.appending(component: "tracked_stories.json")

    func allTrackedStories() -> [TrackedStory] {
        load()
    }

    func upsert(_ story: TrackedStory) {
        var stories = load()
        if let idx = stories.firstIndex(where: { $0.id == story.id }) {
            stories[idx] = story
        } else {
            stories.append(story)
        }
        save(stories)
        Task { await WidgetDataProvider.shared.refreshFromDisk() }
    }

    func remove(storyID: Int) {
        var stories = load()
        stories.removeAll { $0.id == storyID }
        save(stories)
        Task { await WidgetDataProvider.shared.refreshFromDisk() }
    }

    func isTracked(storyID: Int) -> Bool {
        load().contains(where: { $0.id == storyID })
    }

    private func load() -> [TrackedStory] {
        guard let data = try? Data(contentsOf: fileURL),
              let stories = try? JSONDecoder().decode([TrackedStory].self, from: data) else {
            return []
        }
        return stories
    }

    private func save(_ stories: [TrackedStory]) {
        guard let data = try? JSONEncoder().encode(stories) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func scheduleNewCommentsNotification(title: String, storyID: Int, count: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "New comments on tracked story"
        content.body = "\(count) new comment\(count == 1 ? "" : "s") on “\(title)”"
        content.sound = .default
        content.userInfo = ["storyID": storyID]

        let request = UNNotificationRequest(
            identifier: "tracked-story-\(storyID)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}

actor CommentMonitor {
    static let shared = CommentMonitor()

    private let api = HNAPIClient()
    private let store = NotificationStore.shared
    private var loopTask: Task<Void, Never>?

    func start() {
        guard loopTask == nil else { return }
        loopTask = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.checkNow()
                try? await Task.sleep(nanoseconds: 15 * 60 * 1_000_000_000)
            }
        }
    }

    func checkNow() async {
        let tracked = await store.allTrackedStories()
        guard !tracked.isEmpty else { return }

        for var item in tracked {
            do {
                let story = try await api.fetchStory(id: item.id)
                let currentCount = story.descendants ?? 0
                let previousCount = item.lastSeenCommentCount
                if currentCount > previousCount {
                    let delta = currentCount - previousCount
                    await NotificationManager.shared.scheduleNewCommentsNotification(
                        title: story.title,
                        storyID: story.id,
                        count: delta
                    )
                }
                item.title = story.title
                item.lastSeenCommentCount = max(currentCount, previousCount)
                item.lastCheckedAt = Date()
                await store.upsert(item)
                await WidgetDataProvider.shared.refreshFromDisk()
            } catch {
                continue
            }
        }
    }
}
