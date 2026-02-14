import Foundation

enum ShortcutActivityType {
    static let showTopStories = "com.hackerpillar.shortcuts.showTopStories"
    static let openBookmarks = "com.hackerpillar.shortcuts.openBookmarks"
    static let searchHN = "com.hackerpillar.shortcuts.searchHN"
    static let searchQueryKey = "query"
}

@MainActor
final class ShortcutsProvider {
    static let shared = ShortcutsProvider()
    private init() {}

    func donateShowTopStories() {
        donate(
            activityType: ShortcutActivityType.showTopStories,
            title: "Show Top Stories",
            phrase: "Show top stories in HackerPillar",
            userInfo: nil
        )
    }

    func donateOpenBookmarks() {
        donate(
            activityType: ShortcutActivityType.openBookmarks,
            title: "Open Bookmarks",
            phrase: "Open bookmarks in HackerPillar",
            userInfo: nil
        )
    }

    func donateSearch(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        donate(
            activityType: ShortcutActivityType.searchHN,
            title: "Search HN",
            phrase: "Search HackerPillar",
            userInfo: [ShortcutActivityType.searchQueryKey: query]
        )
    }

    private func donate(activityType: String, title: String, phrase: String, userInfo: [AnyHashable: Any]?) {
        let activity = NSUserActivity(activityType: activityType)
        activity.title = title
        activity.suggestedInvocationPhrase = phrase
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.userInfo = userInfo
        activity.persistentIdentifier = NSUserActivityPersistentIdentifier(activityType)
        activity.becomeCurrent()
    }
}
