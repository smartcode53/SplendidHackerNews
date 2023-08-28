//
//  UltimatePostViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/22/22.
//

import Foundation
import SwiftUI

class StoryViewModel: ObservableObject, SafariViewLoader, CommentsButtonProtocol, CustomPullToRefresh {
    
    @Published var story: Story?
    @Published var comments: Item?
    @Published var subError: ErrorType?
    
//    @Published var imageUrl: URL?
    @Published var urlDomain: String?
    @Published var subToastText: String = ""
    @Published var subToastTextColor: Color = .black
    
    @Published var showStoryInComments: Bool = false
    @Published var isBookmarked: Bool = false
    @Published var functionHasRan: Bool = false
    @Published var hasAskedToReload: Bool = false
    
    lazy var networkManager = NetworkManager.instance
    lazy var commentsCacheManager = CommentsCache.instance
    lazy var imageCacheManager = ImageCache.instance
    var storyFeedVm: FeedViewModel
    
    
    init(withStory story: Story, storyFeedVm: FeedViewModel) {
        self._story = Published(initialValue: story)
        self.urlDomain = story.url?.urlDomain
        self.storyFeedVm = storyFeedVm
    }
    
//    func loadImage(fromUrl url: String) {
//        Task {
//            let resultUrl = await networkManager.getImage(fromUrl: url)
//            await MainActor.run { [weak self] in
//                self?.imageUrl = resultUrl
//            }
//        }
//    }

    func saveImageToCache(_ image: Image, storyId: Int) {
        imageCacheManager.saveToCache(image, withKey: String(storyId))
    }
    
    func updateBookmarkStatus(globalSettings: GlobalSettingsViewModel, story: Story) {
        let bookmarkStories = globalSettings.bookmarks.map { $0.story }
        if !bookmarkStories.contains(story) {
            isBookmarked = false
        }
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


extension StoryViewModel {
    
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
