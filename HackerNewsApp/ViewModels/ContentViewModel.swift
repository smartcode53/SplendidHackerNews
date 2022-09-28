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

enum SortOptions: String, CaseIterable {
    case comments = "Comments"
    case points = "Points"
    case time = "Date"
}


class ContentViewModel: SafariViewLoader {
    
    let networkManager: NetworkManager = NetworkManager.instance
    let cacheManager: StoriesCache = StoriesCache.instance
    
    @Published var storyIds = [Int]() {
        didSet {
            if oldValue.isEmpty {
                print("StoryIDs DidSet fired!")
                Task {
                    return await networkManager.getStoryIds(ofType: storyType)
                }
            }
        }
    }
    
    // Different Story Arrays
    @Published var topStories = [Story]()
    @Published var storyType = StoryType.topstories {
        didSet {
            switchStoryType()
        }
    }
    
    @Published var selectedStory: Story? = nil
    
    // MARK: Boolean Values
    @Published var isLoading = false
    @Published var showStoryInComments = false
    @Published var showStoryPicker: Bool = false
    @Published var showSortSheet = false
    @Published var isRefreshing = false
    
    var buffer = [Int]()
    
    func refreshStories() {
        isRefreshing = true
        cacheManager.clearCache()
        topStories.removeAll()
        initialIdsFetch()
        taskGroupStories()
        isRefreshing = false
    }
    
    func switchStoryType() {
        topStories.removeAll()
        Task {
            await loadStoriesTheFirstTime()
        }
    }
    
    func loadStoriesTheFirstTime() async {
        let idArray = await networkManager.getStoryIds(ofType: storyType)
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
            let idArray = await networkManager.getStoryIds(ofType: storyType)
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
        
        if let cachedStories = cacheManager.getFromCache(withKey: storyType.rawValue) {
            Task {
                await MainActor.run { [weak self] in
                    self?.topStories = cachedStories
                }
            }
            
            print("Stories loaded from Cache. Count of elements in stories array: \(String(describing: topStories.count))")
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
                        self?.topStories.append(contentsOf: items)
                        cacheManager.saveToCache(topStories, withKey: storyType.rawValue)
                    }
                }
                
            }
        }
        
    }
    
    func returnSafelyLoadedUrl(url: String) -> URL {
        return networkManager.safelyLoadUrl(url: url)
    }
}

// MARK: Stories Cache Manager
extension ContentViewModel {
    
    class StoriesCache {
        
        static let instance = StoriesCache()
        
        private let dateProvider: () -> Date = Date.init
        private let entryLifetime: TimeInterval = 12 * 60 * 60
        
        private init() {}
        
        let cache = NSCache<NSString, StoriesCacheValueWrapper<[Story]>>()
        
        func getFromCache(withKey key: String) -> [Story]? {
            
            guard let returnedCacheObject = cache.object(forKey: key as NSString) else {
                return nil
            }
            
            guard dateProvider() < returnedCacheObject.expirationDate else {
                removeFromCache(key: key)
                return nil
            }
            
            return returnedCacheObject.value
        }
        
        func saveToCache(_ object: [Story], withKey key: String) {
            let date = dateProvider().addingTimeInterval(entryLifetime)
            let wrapper = StoriesCacheValueWrapper(object, expirationDate: date)
            cache.setObject(wrapper, forKey: key as NSString)
        }
        
        func clearCache() {
            cache.removeAllObjects()
        }
        
        func removeFromCache(key: String) {
            cache.removeObject(forKey: key as NSString)
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

// MARK: Extension for implementing sorting functions
extension ContentViewModel {
    
    enum SortDirection {
        case ascending, descending
    }
    
    func sortByPoints(array: [Story], direction: SortDirection) {
        topStories = array.sorted { story1, story2 in
            if direction == .ascending {
                return story1.score < story2.score
            } else {
                return story1.score > story2.score
            }
        }
    }
    
    func sortByNumberOfComments(array: [Story], direction: SortDirection) {
        topStories = array.sorted { story1, story2 in
            if direction == .ascending {
                return story1.descendants ?? 0 < story2.descendants ?? 0
            } else {
               return story1.descendants ?? 0 > story2.descendants ?? 0
            }
        }
    }
    
    func sortByTime(array: [Story], direction: SortDirection) {
        topStories = array.sorted { story1, story2 in
            if direction == .ascending {
                return story1.time > story2.time
            } else {
                return story1.time < story2.time
            }
        }
    }
    
}


