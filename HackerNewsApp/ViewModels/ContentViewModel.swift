//
//  MainViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import Foundation
import SwiftUI

enum StoryType: String, CaseIterable {
    case topstories = "Top Stories"
    case newstories = "New Stories"
    case beststories = "Best Stories"
    case askstories = "Ask HN"
    case showstories = "Show HN"
}


@MainActor
class ContentViewModel: SafariViewLoader {
    
    @Published var storiesToDisplay: [StoryWrapper] = []
    @Published var fetchedStoryWrappers: [StoryWrapper] = []
    
    let networkManager: NetworkManager = NetworkManager.instance
    
    @Published var storyType = StoryType.topstories {
        didSet {
            changeStoryType()
        }
    }
    @Published var selectedStory: Story? = nil
    
    // MARK: Boolean Values
    @Published var isLoading = false
    @Published var isRefreshing = false
    
    
    func refreshStories() {
        isRefreshing = true
//        cacheManager.clearCache()
//        topStories.removeAll()
//        initialIdsFetch()
//        taskGroupStories()
        isRefreshing = false
    }
    
    nonisolated func returnSafelyLoadedUrl(url: String) -> URL {
        return networkManager.safelyLoadUrl(url: url)
    }
    
}

// MARK: Methods
extension ContentViewModel {
    
    func altLoadStoriesTheFirstTime() async {
        guard let wrappedStoriesArray = await networkManager.getStoryIds(ofType: storyType) else { return }
        
        await MainActor.run { [weak self] in
            self?.fetchedStoryWrappers = wrappedStoriesArray
        }
        
        await altDownloadStories()
    }
    
    func altDownloadStories() async {
        
        let extractedStories = extractLimitedStories()
        
        guard let storiesArray = await networkManager.getStories(using: extractedStories) else { return }
        
        await MainActor.run { [weak self] in
            for wrapper in storiesArray {
                self?.storiesToDisplay.append(wrapper)
            }
        }
    }
    
    func extractLimitedStories() -> [StoryWrapper] {
        
        if fetchedStoryWrappers.count > 19 {
            let slice = Array(fetchedStoryWrappers.prefix(upTo: 20))
            print("Slice Count: \(slice.count)")
            fetchedStoryWrappers = fetchedStoryWrappers.filter({ wrapper in
                !slice.contains(wrapper)
            })
            print("First Item now in FetchedStoryWrappers = \(String(describing: fetchedStoryWrappers.first?.index))")
            return slice
        } else {
            return fetchedStoryWrappers
        }
    }
    
    func altLoadInfinitely() async {
        await MainActor.run {
            self.isLoading = true
        }
        await altDownloadStories()
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    func changeStoryType() {
        fetchedStoryWrappers.removeAll()
        storiesToDisplay.removeAll()
        Task {
            await altLoadStoriesTheFirstTime()
        }
    }
}


// MARK: Stories Cache Manager
extension ContentViewModel {
    class StoriesCache {
        
        static let instance = StoriesCache()
        
        private let dateProvider: () -> Date = Date.init
        private let entryLifetime: TimeInterval = 12 * 60 * 60
        
        private init() {}
        
        let cache = NSCache<NSString, StoriesCacheValueWrapper<Story>>()
        
        func getFromCache(withKey key: String) -> Story? {
            guard let result = cache.object(forKey: key as NSString) else {
                return nil
            }
            
            guard dateProvider() < result.expirationDate else {
                removeFromCache(key: key)
                return nil
            }
            
            return result.value
        }
        
        func saveToCache(_ object: Story, withKey key: String) {
            let date = dateProvider().addingTimeInterval(entryLifetime)
            let wrapper = StoriesCacheValueWrapper(object, expirationDate: date)
            cache.setObject(wrapper, forKey: key as NSString)
        }
        
        func removeFromCache(key: String) {
            cache.removeObject(forKey: key as NSString)
        }
        
        func clearCache() {
            cache.removeAllObjects()
        }
    }
    
    class StoriesCacheValueWrapper<T> {
        let value: T
        let expirationDate: Date
        
        init(_ value: T, expirationDate: Date) {
            self.value = value
            self.expirationDate = expirationDate
        }
    }
}


