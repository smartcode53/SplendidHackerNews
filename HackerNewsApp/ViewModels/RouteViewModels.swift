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
}
