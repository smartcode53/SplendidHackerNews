//
//  CommentsCache.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/23/22.
//

import Foundation
import SwiftUI

class CommentsCache {
    
    static let instance = CommentsCache()
    
    let cache = NSCache<NSString, CommentsCacheValueWrapper<Item>>()
    
    func getFromCache(withKey key: Int) -> Item? {
        let returnedCache = cache.object(forKey: String(key) as NSString)
        return returnedCache?.value
    }
    
    func saveToCache(_ object: Item, withKey key: Int) {
        cache.setObject(CommentsCacheValueWrapper(object), forKey: String(key) as NSString)
    }
    
    func removeFromCache(withKey key: Int) {
        cache.removeObject(forKey: String(key) as NSString)
    }
}

class CommentsCacheValueWrapper<T> {
    let value: T
    
    init(_ value: T) {
        self.value = value
    }
}
