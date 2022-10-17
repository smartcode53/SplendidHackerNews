//
//  MainViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import Foundation
import SwiftUI


class StoryFeedViewModel: SafariViewLoader, CommentsButtonProtocol {
    
    @Published var storiesDict: [StoryType: [StoryWrapper]] = [
        .topstories: [],
        .askstories: [],
        .beststories: [],
        .newstories: [],
        .showstories: []
    ]
    @Published var storiesToDisplay: [StoryWrapper] = []
    @Published var fetchedIds: [StoryWrapper] = []
    
    lazy var commentsCacheManager: CommentsCache = CommentsCache.instance
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
    @Published var generatedError: ErrorHandler? = nil
    @Published var toastText: String = "All Good!"
    @Published var toastTextColor: Color = .primary
    @Published var story: Story?
    @Published var comments: Item?
    
    // MARK: Boolean Values
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var hasAskedToReload: Bool = false
    @Published var showToast = false {
        didSet {
            if showToast {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    withAnimation(.spring()) {
                        self?.showToast = false
                    }
                }
            }
        }
    }
    @Published var functionHasRan = false
    @Published var showStoryInComments: Bool = false
    
}


// MARK: Methods
extension StoryFeedViewModel {
    
    func loadStoriesTheFirstTime() async {
        guard let wrappedStoriesArray = await networkManager.getStoryIds(ofType: storyType) else { return }
        
        await MainActor.run { [weak self] in
            self?.fetchedIds = wrappedStoriesArray
        }
        
        await downloadStories()
    }
    
    func downloadStories() async {
        
        if let cachedStories = cacheManager.getFromCache(withKey: storyType.rawValue) {
            await MainActor.run { [weak self] in
                self?.storiesDict[storyType] = cachedStories
            }
        } else {
            let extractedStories = await extractLimitedStories()
            
            let storiesArray = await networkManager.getStories(using: extractedStories)
            
            await MainActor.run { [weak self] in
    //            self?.storiesToDisplay.append(contentsOf: storiesArray)
                self?.storiesDict[storyType]?.append(contentsOf: storiesArray)
            }
            
            cacheManager.saveToCache(storiesDict[storyType] ?? [], withKey: storyType.rawValue)
        }
        
    }
    
    private func extractLimitedStories() async -> [StoryWrapper] {
        
        if fetchedIds.count > 9 {
            let slice = Array(fetchedIds.prefix(upTo: 10))
            await MainActor.run { [weak self] in
                self?.fetchedIds = fetchedIds.filter({ wrapper in
                    !slice.contains(wrapper)
                })
            }
            
            return slice
            
        } else {
            return fetchedIds
        }
    }
    
    func loadInfinitely() async {
        await MainActor.run {
            self.isLoading = true
        }
        cacheManager.removeFromCache(key: storyType.rawValue)
        await downloadStories()
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    func changeStoryType() {
        fetchedIds.removeAll()
        storiesDict[storyType]?.removeAll()
        Task {
            await loadStoriesTheFirstTime()
        }
    }
    
    func refreshStories() {
        cacheManager.removeFromCache(key: storyType.rawValue)
        fetchedIds.removeAll()
        storiesDict[storyType]?.removeAll()
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
            let data = try JSONEncoder().encode(storiesDict)
            try data.write(to: fileUrl, options: [.atomic])
        } catch let error {
            print("THere was an error encoding and saving the stories array. Here's the error description: \(error)")
        }
    }
    
    func getStoriesFromDisk() -> [StoryType: [StoryWrapper]] {
        let data = try? Data(contentsOf: fileUrl)
        
        if let data {
            do {
                let safeData = try JSONDecoder().decode([StoryType: [StoryWrapper]].self, from: data)
                return safeData
            } catch let error {
                print("There was an error decoding the bookmarks array. Here's the error description: \(error)")
            }
        }
        
        return [
            .topstories: [],
            .askstories: [],
            .showstories: [],
            .newstories: [],
            .beststories: []
        ]
    }
}


// MARK: Stories Cache Manager
extension StoryFeedViewModel {
    class StoriesCache {
        
        static let instance = StoriesCache()
        
        private let dateProvider: () -> Date = Date.init
        private let entryLifetime: TimeInterval = 12 * 60 * 60
        
        private init() {}
        
        let cache = NSCache<NSString, StoriesCacheValueWrapper<[StoryWrapper]>>()
        
        func getFromCache(withKey key: String) -> [StoryWrapper]? {
            guard let result = cache.object(forKey: key as NSString) else {
                return nil
            }
            
            guard dateProvider() < result.expirationDate else {
                removeFromCache(key: key)
                return nil
            }
            
            return result.value
        }
        
        func saveToCache(_ object: [StoryWrapper], withKey key: String) {
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


