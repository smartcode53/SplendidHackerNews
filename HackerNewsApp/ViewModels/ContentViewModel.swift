//
//  MainViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import Foundation
import SwiftUI

enum StoryType: String {
    case topstories, newstories, beststories
}


class ContentViewModel: SafariViewLoader {
    
    let networkManager: NetworkManager = NetworkManager.instance
    let cacheManager: StoriesCache = StoriesCache.instance
    
    @Published var storyIds = [Int]() {
        didSet {
            if oldValue.isEmpty {
                Task {
                    return await networkManager.getStoryIds()
                }
            }
        }
    }
    @Published var stories = [Story]()

    
    @Published var isLoading = false
    @Published var showStoryInComments = false
    @Published var selectedStory: Story? = nil
    @Published var pageNo: Int = 0
    
    var buffer = [Int]()
    
    func loadStoriesTheFirstTime() async {
        let idArray = await networkManager.getStoryIds()
        print("idArray.count: \(String(describing: idArray?.count))")
        if let idArray {
            await MainActor.run { [weak self] in
                self?.storyIds = idArray
            }
        }
        
        print("Entering the taskGroupStories function from the loadStoriesTheFirstTime function")
        
        taskGroupStories()
    }
    
    func loadInfinitely() {
        isLoading = true
        cacheManager.clearCache()
        taskGroupStories()
        isLoading = false
    }
    
    func initialIdsFetch() {
        Task {
            let idArray = await networkManager.getStoryIds()
            print("idArray count: \(String(describing: idArray?.count))")
            if let idArray {
                await MainActor.run { [weak self] in
                    self?.storyIds = idArray
                }
            }
        }
    }
    
    func taskGroupStories() {
        
        print("Entered the taskGroupStories function.")
        
        if let cachedStories = cacheManager.getFromCache(withKey: "storyArray") {
            Task {
                await MainActor.run { [weak self] in
                    self?.stories = cachedStories
                }
            }
            
            print("Stories loaded from Cache. Count of elements in stories array: \(String(describing: stories.count))")
        } else {
            print("Loading from cache failed... Now initiating loading process from the server")
            print("Count of storyIds array before initiating the download process: \(storyIds.count)")
            Task {
//                guard let ids = await networkManager.getStoryIds() else {return}
//                storyIds = ids
                let initialItems = storyIds.count < 20 ? storyIds : Array(storyIds.prefix(20)) // Extract 20 items from the fetched array.
                buffer = initialItems // Add those 20 items to the buffer array
                await MainActor.run { [weak self] in
                    self?.storyIds = self?.storyIds.filter({ id in // recreate the storyIds array to exclude items from the buffer array.
                        !buffer.contains(id)
                    }) ?? []
                }
                let items = await networkManager.downloadStories(using: initialItems)
                if let items {
                    await MainActor.run { [weak self] in
                        self?.stories.append(contentsOf: items)
                        cacheManager.saveToCache(stories, withKey: "storyArray")
                    }
                }
                
            }
        }
        
    }
    
    func returnSafelyLoadedUrl(url: String) -> URL {
        return networkManager.safelyLoadUrl(url: url)
    }
    
    
}

extension ContentViewModel {
    
    class StoriesCache {
        
        static let instance = StoriesCache()
        
        private init() {}
        
        let cache = NSCache<NSString, StoriesCacheValueWrapper<[Story]>>()
        
        func getFromCache(withKey key: String) -> [Story]? {
            let returnedCache = cache.object(forKey: key as NSString)
            return returnedCache?.value
        }
        
        func saveToCache(_ object: [Story], withKey key: String) {
            cache.setObject(StoriesCacheValueWrapper(object), forKey: key as NSString)
        }
        
        func clearCache() {
            cache.removeAllObjects()
        }
    }
    
    class StoriesCacheValueWrapper<T> {
        let value: T
        
        init(_ value: T) {
            self.value = value
        }
    }
}


