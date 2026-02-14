import Foundation
#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct StoryLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var score: Int
        var commentCount: Int
        var title: String
    }

    var storyID: Int
}

@available(iOS 16.1, *)
actor LiveActivityManager {
    static let shared = LiveActivityManager()

    private let api = HNAPIClient()
    private var refreshTask: Task<Void, Never>?

    func start(story: Story) async {
        let attributes = StoryLiveActivityAttributes(storyID: story.id)
        let state = StoryLiveActivityAttributes.ContentState(
            score: story.score,
            commentCount: story.descendants ?? 0,
            title: story.title
        )
        _ = try? Activity<StoryLiveActivityAttributes>.request(
            attributes: attributes,
            content: .init(state: state, staleDate: Date().addingTimeInterval(15 * 60))
        )
        startRefreshLoopIfNeeded()
    }

    func stop(storyID: Int) async {
        let activities = Activity<StoryLiveActivityAttributes>.activities
        for activity in activities where activity.attributes.storyID == storyID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        stopRefreshLoopIfNoActiveActivities()
    }

    private func startRefreshLoopIfNeeded() {
        guard refreshTask == nil else { return }
        refreshTask = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshActiveStories()
                try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
            }
        }
    }

    private func refreshActiveStories() async {
        let activities = Activity<StoryLiveActivityAttributes>.activities
        guard !activities.isEmpty else {
            stopRefreshLoopIfNoActiveActivities()
            return
        }
        for activity in activities {
            do {
                let story = try await api.fetchStory(id: activity.attributes.storyID)
                let state = StoryLiveActivityAttributes.ContentState(
                    score: story.score,
                    commentCount: story.descendants ?? 0,
                    title: story.title
                )
                await activity.update(.init(state: state, staleDate: Date().addingTimeInterval(15 * 60)))
            } catch {
                continue
            }
        }
    }

    private func stopRefreshLoopIfNoActiveActivities() {
        guard Activity<StoryLiveActivityAttributes>.activities.isEmpty else { return }
        refreshTask?.cancel()
        refreshTask = nil
    }
}
#endif
