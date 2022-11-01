//
//  SingleBookmarkViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/24/22.
//

import Foundation
import SwiftUI

class SingleBookmarkViewModel: ObservableObject, SafariViewLoader, CommentsButtonProtocol, CustomPullToRefresh {
    
    @Published var comments: Item?
    @Published var story: Story?
    @Published var subError: ErrorType? = nil
    
    @Published var imageUrl: URL?
    @Published var subToastText: String = ""
    @Published var subToastTextColor: Color = .black
    
    @Published var showStoryInComments: Bool = false
    @Published var functionHasRan: Bool = false
    @Published var hasAskedToReload: Bool = false
    @Published var deleteBookmark: Bool = false
    
    lazy var imageCacheManager = UltimatePostViewModel.ImageCache.instance
    
    lazy var networkManager: NetworkManager = NetworkManager.instance
    lazy var commentsCacheManager: CommentsCache = CommentsCache.instance
    
    init(withStory story: Story) {
        self.story = story
    }
    
    func getImageUrl(fromUrl url: String?) async -> URL? {
        if let url {
            return await networkManager.getImage(fromUrl: url)
        }
        return nil
    }
    
    func refresh() {
        if let id = story?.id {
            commentsCacheManager.removeFromCache(withKey: id)
            comments = nil
            loadComments(withId: id) { [weak self] error in
                if let error {
                    let errorType = ErrorType(error: error)
                    self?.subToastText = errorType.error.localizedDescription
                    self?.subError = errorType
                }
                
            }
            if comments != nil && story != nil {
                Task {
                    if let (numComments, points) = await getCommentAndPointCounts(forPostWithId: story!.id) {
                        await MainActor.run { [weak self] in
                            self?.story!.descendants = numComments
                            self?.story!.score = points
                        }
                        
                    }
                }
            }
            
            hasAskedToReload = false
        }
    }
}
