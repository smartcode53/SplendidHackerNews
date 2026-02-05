import Foundation

@MainActor
final class CommentsRouteViewModel: ObservableObject, CommentsButtonProtocol, SafariViewLoader {
    @Published var story: Story?
    @Published var comments: Item?
    @Published var showStoryInComments: Bool = false
    
    lazy var networkManager: NetworkManager = NetworkManager.instance
    lazy var commentsCacheManager: CommentsCache = CommentsCache.instance
    
    init(story: Story) {
        self.story = story
    }

    #if DEBUG
    func loadComments(withId id: Int) async {
        if DebugEnvironment.shared.fixtureMode {
            story = story ?? DebugFixtures.story(for: id)
            comments = DebugFixtures.commentsItem(storyID: id)
            return
        }
        if let cachedItem = commentsCacheManager.getFromCache(withKey: id) {
            comments = cachedItem
            print("Item loaded from cache")
            return
        }

        print("Item needed to be downloaded from the server")
        let result = await networkManager.getComments(forId: id)
        comments = result
        if let safeResult = result {
            commentsCacheManager.saveToCache(safeResult, withKey: id)
            print("Comment cache save successful with id: \(id)")
        }
    }

    func getCommentAndPointCounts(forPostWithId id: Int) async -> (Int?, Int)? {
        if DebugEnvironment.shared.fixtureMode {
            return (comments?.children?.count ?? 30, story?.score ?? 120)
        }
        let story = await networkManager.fetchSingleStory(withId: id)
        if let story {
            return (story.descendants, story.score)
        }
        return nil
    }
    #endif
}
