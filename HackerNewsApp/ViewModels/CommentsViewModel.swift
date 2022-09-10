//
//  CommentsViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/5/22.
//

import Foundation

class CommentsViewModel: SafariViewLoader {
    
    @Published var showStoryInComments = false
    @Published var item: Item?
    
    let networkManager = NetworkManager.instance
    let cacheManager = CommentsCache.instance
    
    func loadComments(forId id: Int) {
        if let cachedItem = cacheManager.getFromCache(withKey: id) {
            item = cachedItem
            print("Item loaded from cache")
        } else {
            print("Item needed to be downloaded from the server")
            Task {
                let result = await networkManager.getComments(forId: id)
                await MainActor.run { [weak self] in
                    self?.item = result
                }

                if let safeResult = result {
                    cacheManager.saveToCache(safeResult, withKey: id)
                    print("Comment cache save successful with id: \(id)")
                }
            }
        }
    }

    func getCommentAndPointCounts(forPostId id: Int) async -> (Int?, Int)? {
        let story = await networkManager.fetchStory(with: id)
        if let story {
            return (story.descendants, story.score)
        }
        return nil
    }
    
    func returnSafelyLoadedUrl(url: String) -> URL {
        return networkManager.safelyLoadUrl(url: url)
    }
    
}


extension CommentsViewModel {
    
    class CommentsCache {
        
        static let instance = CommentsCache()
        
        private init() {}
        
        let cache = NSCache<NSString, CommentsCacheValueWrapper<Item>>()
        
        func getFromCache(withKey key: Int) -> Item? {
            let returnedCache = cache.object(forKey: String(key) as NSString)
            return returnedCache?.value
        }
        
        func saveToCache(_ object: Item, withKey key: Int) {
            cache.setObject(CommentsCacheValueWrapper(object), forKey: String(key) as NSString)
        }
    }

    class CommentsCacheValueWrapper<T> {
        let value: T
        
        init(_ value: T) {
            self.value = value
        }
    }
}
