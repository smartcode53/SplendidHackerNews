//
//  UltimatePostViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/22/22.
//

import Foundation
import SwiftUI

class UltimatePostViewModel: ObservableObject, SafariViewLoader, CommentsButtonProtocol {
    
    @Published var story: Story?
    @Published var comments: Item?
    
    @Published var imageUrl: URL?
    @Published var urlDomain: String?
    
    @Published var showStoryInComments = false
    
    lazy var networkManager = NetworkManager.instance
    lazy var commentsCacheManager = CommentsCache.instance
    lazy var imageCacheManager = ImageCache.instance
    
    
    init(withStory story: Story) {
        self._story = Published(initialValue: story)
        self.urlDomain = story.url?.urlDomain
    }
    
    func loadImage(fromUrl url: String) {
        Task {
            let resultUrl = await networkManager.getImage(fromUrl: url)
            await MainActor.run { [weak self] in
                self?.imageUrl = resultUrl
            }
        }
    }

    func saveImageToCache(_ image: Image, storyId: Int) {
        imageCacheManager.saveToCache(image, withKey: String(storyId))
    }
}


extension UltimatePostViewModel {
    
    class ImageCache {
        
        static let instance = ImageCache()
        
        private let dateProvider: () -> Date = Date.init
        private let entryLifetime: TimeInterval = 12 * 60 * 60
        
        private init() {}
        
        let cache = NSCache<NSString, ImageCacheValueWrapper<Image>>()
        
        func getFromCache(withKey key: String) -> Image? {
            
            guard let returnedCacheObject = cache.object(forKey: key as NSString) else {
                return nil
            }
            
            guard dateProvider() < returnedCacheObject.expirationDate else {
                removeFromCache(key: key)
                return nil
            }
            
            return returnedCacheObject.value
        }
        
        func saveToCache(_ object: Image, withKey key: String) {
            let date = dateProvider().addingTimeInterval(entryLifetime)
            let wrapper = ImageCacheValueWrapper(object, expirationDate: date)
            cache.setObject(wrapper, forKey: key as NSString)
        }
        
        func clearCache() {
            cache.removeAllObjects()
        }
        
        func removeFromCache(key: String) {
            cache.removeObject(forKey: key as NSString)
        }
    }
    
    
    class ImageCacheValueWrapper<T> {
        let value: T
        let expirationDate: Date
        
        init(_ value: T, expirationDate: Date) {
            self.value = value
            self.expirationDate = expirationDate
        }
    }
}
