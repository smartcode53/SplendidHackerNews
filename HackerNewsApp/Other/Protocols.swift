//
//  Protocols.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/5/22.
//

import Foundation

protocol SafariViewLoader: ObservableObject {
    
    var networkManager: NetworkManager { get }
    
    func returnSafelyLoadedUrl(url: String) -> URL
}

extension SafariViewLoader {
    func returnSafelyLoadedUrl(url: String) -> URL {
        return networkManager.safelyLoadUrl(url: url)
    }
}


protocol CommentsButtonProtocol: ObservableObject {
    
    var story: Story? { get set }
    var comments: Item? {get set}
    
    var showStoryInComments: Bool { get set }
    
    var networkManager: NetworkManager { get }
    var commentsCacheManager: CommentsCache { get }
    
    func loadComments(withId id: Int)
    
    func getCommentAndPointCounts(forPostWithId id: Int) async -> (Int?, Int)? 
}


extension CommentsButtonProtocol {
    
    func loadComments(withId id: Int) {
        if let cachedItem = commentsCacheManager.getFromCache(withKey: id) {
            comments = cachedItem
        } else {
            Task {
                let result = await networkManager.getComments(forId: id)
                await MainActor.run { [weak self] in
                    self?.comments = result
                }
                
                if let safeResult = result {
                    commentsCacheManager.saveToCache(safeResult, withKey: id)
                }
            }
        }
    }
    
    func getCommentAndPointCounts(forPostWithId id: Int) async -> (Int?, Int)? {
        let story = await networkManager.fetchSingleStory(withId: id)
        if let story {
            return (story.descendants, story.score)
        }
        return nil
    }
}
