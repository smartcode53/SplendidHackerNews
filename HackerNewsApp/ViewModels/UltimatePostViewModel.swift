//
//  UltimatePostViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/22/22.
//

import Foundation
import SwiftUI

@MainActor
class UltimatePostViewModel: ObservableObject, SafariViewLoader, CommentsButtonProtocol {
    
    @Published var story: Story?
    @Published var comments: Item?
    
    @Published var imageUrl: URL?
    @Published var cachedImage: Image?
    @Published var imageAvailability: ImageAvailability = .unknown
    @Published var urlDomain: String?
    
    @Published var showStoryInComments = false
    
    lazy var networkManager = NetworkManager.instance
    lazy var commentsCacheManager = CommentsCache.instance
    lazy var imageCacheManager = ImageCache.instance
    lazy var imageAvailabilityCache = ImageAvailabilityCache.instance
    lazy var imageURLCache = ImageURLCache.instance
    
    
    init(withStory story: Story) {
        self._story = Published(initialValue: story)
        self.urlDomain = story.url?.urlDomain
        self.cachedImage = imageCacheManager.getFromCache(withKey: String(story.id))
        if cachedImage != nil {
            imageAvailability = .available
        } else if let cachedURL = imageURLCache.getFromCache(withKey: String(story.id)) {
            imageUrl = cachedURL
            imageAvailability = .available
        } else if let cachedAvailability = imageAvailabilityCache.getFromCache(withKey: String(story.id)) {
            imageAvailability = cachedAvailability ? .available : .unavailable
        } else if story.url == nil {
            imageAvailability = .unavailable
        }
    }
    
    /// Loads the OpenGraph image URL for this story.
    /// Before issuing a network request, re-checks the URL and availability
    /// caches (the background prefetcher in ContentViewModel may have
    /// populated them between VM init and PostView's .task firing).
    /// If a fetch IS needed, NetworkManager's deduplicator ensures that
    /// concurrent calls (from both prefetch and PostView) coalesce into
    /// a single network request.
    func loadImage(fromUrl url: String) async {
        guard imageAvailability != .unavailable else { return }
        guard imageUrl == nil else { return }

        let key = String(story?.id ?? 0)

        // Re-check caches: the prefetcher may have resolved this while we waited
        if let cachedURL = imageURLCache.getFromCache(withKey: key) {
            imageUrl = cachedURL
            imageAvailability = .available
            return
        }
        if let cachedAvailability = imageAvailabilityCache.getFromCache(withKey: key), cachedAvailability == false {
            imageAvailability = .unavailable
            return
        }

        // NetworkManager.getImage now deduplicates in-flight requests:
        // if the prefetcher is already fetching this URL, we await the
        // same result instead of issuing a duplicate OG fetch.
        let resultUrl = await networkManager.getImage(fromUrl: url)
        imageUrl = resultUrl
        if resultUrl == nil {
            imageAvailability = .unavailable
            imageAvailabilityCache.saveToCache(false, withKey: key)
        } else if let resultUrl {
            imageAvailability = .available
            imageAvailabilityCache.saveToCache(true, withKey: key)
            imageURLCache.saveToCache(resultUrl, withKey: key)
        }
    }

    func saveImageToCache(_ image: Image, storyId: Int) {
        imageCacheManager.saveToCache(image, withKey: String(storyId))
    }

    func cacheImageIfNeeded(_ image: Image, storyId: Int) {
        guard cachedImage == nil else { return }
        cachedImage = image
        saveImageToCache(image, storyId: storyId)
    }
}


extension UltimatePostViewModel {
    
    final class ImageCache: @unchecked Sendable {
        
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
    
    
    final class ImageCacheValueWrapper<T> {
        let value: T
        let expirationDate: Date
        
        init(_ value: T, expirationDate: Date) {
            self.value = value
            self.expirationDate = expirationDate
        }
    }
}

extension UltimatePostViewModel {
    enum ImageAvailability: Equatable {
        case unknown
        case available
        case unavailable
    }

    final class ImageAvailabilityCache: @unchecked Sendable {
        static let instance = ImageAvailabilityCache()

        private let dateProvider: () -> Date = Date.init
        private let entryLifetime: TimeInterval = 12 * 60 * 60
        private init() {}

        private let cache = NSCache<NSString, ImageCacheValueWrapper<NSNumber>>()

        func getFromCache(withKey key: String) -> Bool? {
            guard let returnedCacheObject = cache.object(forKey: key as NSString) else {
                return nil
            }

            guard dateProvider() < returnedCacheObject.expirationDate else {
                removeFromCache(key: key)
                return nil
            }

            return returnedCacheObject.value.boolValue
        }

        func saveToCache(_ value: Bool, withKey key: String) {
            let date = dateProvider().addingTimeInterval(entryLifetime)
            let wrapper = ImageCacheValueWrapper(NSNumber(value: value), expirationDate: date)
            cache.setObject(wrapper, forKey: key as NSString)
        }

        func removeFromCache(key: String) {
            cache.removeObject(forKey: key as NSString)
        }
    }
}

extension UltimatePostViewModel {
    final class ImageURLCache: @unchecked Sendable {
        static let instance = ImageURLCache()

        private let dateProvider: () -> Date = Date.init
        private let entryLifetime: TimeInterval = 12 * 60 * 60
        private init() {}

        private let cache = NSCache<NSString, ImageCacheValueWrapper<URL>>()

        func getFromCache(withKey key: String) -> URL? {
            guard let returnedCacheObject = cache.object(forKey: key as NSString) else {
                return nil
            }

            guard dateProvider() < returnedCacheObject.expirationDate else {
                removeFromCache(key: key)
                return nil
            }

            return returnedCacheObject.value
        }

        func saveToCache(_ value: URL, withKey key: String) {
            let date = dateProvider().addingTimeInterval(entryLifetime)
            let wrapper = ImageCacheValueWrapper(value, expirationDate: date)
            cache.setObject(wrapper, forKey: key as NSString)
        }

        func removeFromCache(key: String) {
            cache.removeObject(forKey: key as NSString)
        }
    }
}
