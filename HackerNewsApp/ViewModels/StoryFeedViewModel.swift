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

@MainActor
class StoryFeedViewModel: SafariViewLoader {
    
    @Published var storiesToDisplay: [StoryWrapper] = []
    @Published var fetchedIds: [StoryWrapper] = []
    
    let networkManager: NetworkManager = NetworkManager.instance
    let cacheManager: StoriesCache = StoriesCache.instance
    @Published var networkChecker: NetworkChecker = NetworkChecker()
    
    let fileUrl = FileManager().documentsDirectory.appending(component: "stories.txt")
    
    @Published var storyType = StoryType.topstories {
        didSet {
            changeStoryType()
        }
    }
    @Published var selectedStory: Story? = nil
    
    // MARK: Boolean Values
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var hasAskedToReload: Bool = false
    
}


// MARK: Methods
extension StoryFeedViewModel {
    
    func loadStoriesTheFirstTime() async {
        guard let wrappedStoriesArray = await networkManager.getStoryIds(ofType: storyType) else { return }
        
        await MainActor.run { [weak self] in
//            if let reloading = self?.hasAskedToReload {
//                if reloading {
//                    self?.fetchedStoryWrappers.removeAll()
//                }
//            }
            self?.fetchedIds = wrappedStoriesArray
        }
        
        await downloadStories()
    }
    
    func downloadStories() async {
        
        let extractedStories = extractLimitedStories()
        
        guard let storiesArray = await networkManager.getStories(using: extractedStories) else { return }
        
        await MainActor.run { [weak self] in
            
//            if let reloading = self?.hasAskedToReload {
//                if reloading {
//                    self?.storiesToDisplay.removeAll()
//                }
//            }
            
            self?.storiesToDisplay.append(contentsOf: storiesArray)
            
//            for wrapper in storiesArray {
//                self?.storiesToDisplay.append(wrapper)
//            }
        }
    }
    
    func extractLimitedStories() -> [StoryWrapper] {
        
        if fetchedIds.count > 9 {
            let slice = Array(fetchedIds.prefix(upTo: 10))
            print("Slice Count: \(slice.count)")
            fetchedIds = fetchedIds.filter({ wrapper in
                !slice.contains(wrapper)
            })
            print("First Item now in FetchedStoryWrappers = \(String(describing: fetchedIds.first?.index))")
            return slice
        } else {
            return fetchedIds
        }
    }
    
    func loadInfinitely() async {
        await MainActor.run {
            self.isLoading = true
        }
        await downloadStories()
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    func changeStoryType() {
        fetchedIds.removeAll()
        storiesToDisplay.removeAll()
        Task {
            await loadStoriesTheFirstTime()
        }
    }
    
    func refreshStories() {
        cacheManager.clearCache()
        fetchedIds.removeAll()
        storiesToDisplay.removeAll()
        Task {
            await loadStoriesTheFirstTime()
        }
        hasAskedToReload = false
    }
    
    nonisolated func returnSafelyLoadedUrl(url: String) -> URL {
        return networkManager.safelyLoadUrl(url: url)
    }
    
    func saveStoriesToDisk() {
        do {
            let data = try JSONEncoder().encode(storiesToDisplay)
            try data.write(to: fileUrl, options: [.atomic])
            print("Stories saved to disk SUCCESSFULLY")
        } catch let error {
            print("THere was an error encoding and saving the stories array. Here's the error description: \(error)")
        }
    }
    
    func getStoriesFromDisk() -> [StoryWrapper]? {
        let data = try? Data(contentsOf: fileUrl)
        
        if let data {
            do {
                let safeData = try JSONDecoder().decode([StoryWrapper].self, from: data)
                print("Stories retrieved from Disk SUCCESSFULLY.")
                return safeData
            } catch let error {
                print("There was an error decoding the bookmarks array. Here's the error description: \(error)")
            }
        }
        
        return nil
    }
}


// MARK: Stories Cache Manager
extension StoryFeedViewModel {
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


