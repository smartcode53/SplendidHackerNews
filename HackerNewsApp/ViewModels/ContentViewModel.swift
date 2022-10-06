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
            changeStoryType()
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
    
    nonisolated func returnSafelyLoadedUrl(url: String) -> URL {
        return networkManager.safelyLoadUrl(url: url)
    }
    
    // MARK: Alt section
    //    @Published var altStoryIds: [Int: Int] = [:]
    //    @Published var stories: [Story] = []
    @Published var storiesToDisplay: [StoryWrapper] = []
    @Published var fetchedStoryWrappers: [StoryWrapper] = []
    @Published var currentMaxItemNumber: Int = 20
    @Published var currentMinItemNumber: Int = 1
    lazy var altNetworkManager: AltNetworkManager = AltNetworkManager.instance
    lazy var altCacheManager: AltStoriesCache = AltStoriesCache.instance
    
}

// MARK: Alt ViewModel Extension (Testing purposes)
extension ContentViewModel {
    
    func altLoadStoriesTheFirstTime() async {
        guard let wrappedStoriesArray = await altNetworkManager.getStoryIds(ofType: storyType) else { return }
        
        await MainActor.run { [weak self] in
            self?.fetchedStoryWrappers = wrappedStoriesArray
        }
        
        await altDownloadStories()
    }
    
    func altDownloadStories() async {
        
        var cachedStories: [StoryWrapper] = []
        
        for storyWrapper in storiesToDisplay {
            if let cachedStory = altCacheManager.getFromCache(withKey: String(storyWrapper.id)) {
                cachedStories.append(cachedStory)
            }
        }
        
        if storiesToDisplay.count == cachedStories.count && !cachedStories.isEmpty {
            
            await MainActor.run { [weak self] in
                self?.storiesToDisplay = cachedStories
            }
            
            print("Loaded from cache")
            
        } else {
            
            let extractedStories = extractLimitedStories()
            
            guard let storiesArray = await altNetworkManager.getStories(using: extractedStories) else { return }
            
            await MainActor.run { [weak self] in
                for wrapper in storiesArray {
                    self?.storiesToDisplay.append(wrapper)
                    self?.altCacheManager.saveToCache(wrapper, withKey: String(wrapper.id))
                }
                
//                self?.storiesToDisplay.sort(by: { item1, item2 in
//                    item1.index < item2.index
//                })
            }
        }
        
        
        
        
        
//        var cachedStoryArray: [StoryWrapper] = []
//
//        for wrapper in fetchedStoryWrappers {
//            if let cachedStory = altCacheManager.getFromCache(withKey: String(wrapper.id)) {
//                cachedStoryArray.append(cachedStory)
//            }
//        }
        
        //        if cachedStoryArray.isEmpty {
        //        let filteredIdDict: [Int: Int] = altStoryIds.filter { dict in
        //            if currentMaxItemNumber == currentMinItemNumber {
        //                return dict.key == currentMaxItemNumber
        //            } else {
        //                return dict.key >= currentMinItemNumber && dict.key <= currentMaxItemNumber
        //            }
        //        }
//        if cachedStoryArray.isEmpty {
//            let filteredArray: [StoryWrapper] = fetchedStoryWrappers.filter { wrapper in
//                if currentMaxItemNumber == currentMinItemNumber {
//                    return wrapper.index == currentMaxItemNumber
//                } else {
//                    return wrapper.index >= currentMinItemNumber && wrapper.index <= currentMaxItemNumber
//                }
//            }
//
//
//            await MainActor.run { [weak self] in
//                self?.updateRange()
//            }
//
//            guard let storiesArray = await altNetworkManager.getStories(using: filteredArray) else {
//                print("Failed to download stories")
//                return
//            }
//
//            await MainActor.run { [weak self] in
//                for wrapper in storiesArray {
//                    if let wrapperIndex = fetchedStoryWrappers.firstIndex(where: { storyWrapper in
//                        storyWrapper.index == wrapper.index
//                    }) {
//                        self?.fetchedStoryWrappers[wrapperIndex] = wrapper
//                        altCacheManager.saveToCache(wrapper, withKey: String(wrapper.id))
//                    }
//                }
//                //            self?.stories.append(contentsOf: storiesArray)
//                //            for story in stories {
//                //                altCacheManager.saveToCache(story, withKey: String(story.id))
//                //            }
//            }
//        } else {
//            await MainActor.run { [weak self] in
//                for wrapper in cachedStoryArray {
//                    if let wrapperIndex = fetchedStoryWrappers.firstIndex(where: { item in
//                        item.index == wrapper.index
//                    }) {
//                        self?.fetchedStoryWrappers[wrapperIndex] = wrapper
//                    }
//                }
//            }
//
//        }
        
        
    }
    
    func extractLimitedStories() -> [StoryWrapper] {
        let firstStoryIndex = fetchedStoryWrappers.first?.index
        let lastStoryIndex = fetchedStoryWrappers.last?.index
        var currentMax: Int = 0
        
        if let firstStoryIndex, let lastStoryIndex {
            if lastStoryIndex - firstStoryIndex < 19 {
                // Add remaining stories to the storiesToLoadArray and finally empty the fetchedStoryWrappers array.
                return fetchedStoryWrappers
            } else {
                currentMax = firstStoryIndex + 19
            }
        }
        
        let slice = Array(fetchedStoryWrappers.prefix(currentMax))
        fetchedStoryWrappers.removeSubrange(0...currentMax)
        return slice
    }
    
//    func updateRange() {
//        let arrayCount: Int = fetchedStoryWrappers.count
//
//        if currentMaxItemNumber + 20 > arrayCount {
//            currentMinItemNumber = currentMaxItemNumber + 1
//            currentMaxItemNumber = arrayCount
//        } else {
//            currentMaxItemNumber += 20
//            currentMinItemNumber += 20
//        }
//    }
    
    func altLoadInfinitely() async {
        await MainActor.run {
            self.isLoading = true
            for storyWrapper in storiesToDisplay {
                altCacheManager.removeFromCache(key: String(storyWrapper.id))
            }
        }
        await altDownloadStories()
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    func changeStoryType() {
        fetchedStoryWrappers.removeAll()
        storiesToDisplay.removeAll()
//        altCacheManager.clearCache()
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


// MARK: AltStories Cache Manager
extension ContentViewModel {
    class AltStoriesCache {
        
        static let instance = AltStoriesCache()
        
        private let dateProvider: () -> Date = Date.init
        private let entryLifetime: TimeInterval = 12 * 60 * 60
        
        private init() {}
        
        let cache = NSCache<NSString, AltStoriesCacheValueWrapper<StoryWrapper>>()
        
        func getFromCache(withKey key: String) -> StoryWrapper? {
            guard let result = cache.object(forKey: key as NSString) else {
                return nil
            }
            
            guard dateProvider() < result.expirationDate else {
                removeFromCache(key: key)
                return nil
            }
            
            return result.value
        }
        
        func saveToCache(_ object: StoryWrapper, withKey key: String) {
            let date = dateProvider().addingTimeInterval(entryLifetime)
            let wrapper = AltStoriesCacheValueWrapper(object, expirationDate: date)
            cache.setObject(wrapper, forKey: key as NSString)
        }
        
        func removeFromCache(key: String) {
            cache.removeObject(forKey: key as NSString)
        }
        
        func clearCache() {
            cache.removeAllObjects()
        }
    }
    
    class AltStoriesCacheValueWrapper<T> {
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


