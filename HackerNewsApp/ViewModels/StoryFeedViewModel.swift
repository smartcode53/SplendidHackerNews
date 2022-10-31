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
    @Published var subError: ErrorType? = nil 
    
    
    
    lazy var commentsCacheManager: CommentsCache = CommentsCache.instance
    lazy var networkManager: NetworkManager = NetworkManager.instance
    lazy var cacheManager: StoriesCache = StoriesCache.instance
    lazy var notificationsManager: NotificationsManager = NotificationsManager.instance
    @Published var networkChecker: NetworkChecker = NetworkChecker()
    
    let fileUrl = FileManager().documentsDirectory.appending(component: "stories.txt")
    
    @Published var storyType = StoryType.topstories {
        didSet {
            changeStoryType()
        }
    }
    @Published var selectedStory: Story? = nil
    @Published var generatedError: ErrorHandler? = nil
    @Published var subToastText: String = "All Good!"
    @Published var subToastTextColor: Color = .primary
    @Published var story: Story?
    @Published var comments: Item?
    
    // MARK: Boolean Values
    @Published var isInitiallyLoading: Bool = false {
        didSet {
            if isInitiallyLoading {
                showBlankColor = false
            } else {
                showBlankColor = true
            }
        }
    }
    @Published var showBlankColor: Bool = false
    @Published var isLoading: Bool = false 
    @Published var isRefreshing: Bool = false
    @Published var hasAskedToReload: Bool = false
    @Published var functionHasRan = false
    @Published var showStoryInComments: Bool = false
    @Published var showNoInternetScreen: Bool = false
    @Published var storiesLoaded: Bool = false
    
}


// MARK: Methods
extension StoryFeedViewModel {
    
    func loadStoriesTheFirstTime() async {
        
        await MainActor.run { [weak self] in
            self?.isInitiallyLoading = true
        }
        
        let wrappedStories = await networkManager.getStoryIds(ofType: storyType)
        
                
        switch wrappedStories {
        case .success(let array):
            await MainActor.run { [weak self] in
                self?.fetchedIds = array
            }
            let downloadTask = Task { () -> [StoryWrapper] in
                let returnedStories = try await downloadStories()
                return returnedStories
            }
            let result = await downloadTask.result
            switch result {
            case .success(let array):
                await MainActor.run { [weak self] in
                    self?.storiesDict[storyType] = array
                    self?.cacheManager.saveToCache(storiesDict[storyType, default: []], withKey: storyType.rawValue)
                    self?.storiesLoaded = true
                    self?.isInitiallyLoading = false
                }
            case .failure(_):
                
                await MainActor.run { [weak self] in
                    let handler = ErrorHandler.noStoryArray
                    self?.subToastText = handler.localizedDescription
                    self?.subToastTextColor = .black
                    self?.subError = ErrorType(error: ErrorHandler.noStoryArray)
                }
            }
            
        case .failure(_):
            let errorType = ErrorType(error: .noStoryArray)
            subToastText = errorType.error.localizedDescription
            subToastTextColor = .black
            subError = errorType
        }
        
    }
    
    func downloadStories() async throws -> [StoryWrapper] {
        
        if let cachedStories = cacheManager.getFromCache(withKey: storyType.rawValue) {
            return cachedStories
        } else {
            let extractedStories = await extractLimitedStories()
            
            let storiesArray = await networkManager.getStories(using: extractedStories)
            
            switch storiesArray {
            case .success(let array):
                return array
            case .failure(let error):
                throw error
            }
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
        
        cacheManager.removeFromCache(key: storyType.rawValue)
        
        await MainActor.run {
            self.isLoading = true
            self.showBlankColor = false
        }
        
        let downloadTask = Task { () -> [StoryWrapper] in
            let returnedStories = try await downloadStories()
            return returnedStories
        }
        let result = await downloadTask.result
        switch result {
        case .success(let array):
            await MainActor.run { [weak self] in
                self?.storiesDict[storyType]?.append(contentsOf: array)
                cacheManager.saveToCache(storiesDict[storyType, default: []], withKey: storyType.rawValue)
            }
        case .failure(_):
            await MainActor.run { [weak self] in
                let errorType = ErrorType(error: .infiniteLoadingFailed)
                self?.subToastText = errorType.error.localizedDescription
                self?.subToastTextColor = .black
                self?.subError = errorType
            }
        }
        
        await MainActor.run {
            self.isLoading = false
            self.showBlankColor = true
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
    }
    
    nonisolated func returnSafelyLoadedUrl(url: String) -> URL {
        return networkManager.safelyLoadUrl(url: url)
    }
    
    func saveStoriesToDisk() {
        do {
            let data = try JSONEncoder().encode(storiesDict)
            try data.write(to: fileUrl, options: [.atomic])
        } catch {
            let errorType = ErrorType(error: .diskSaveError)
            subToastText = errorType.error.localizedDescription
            subToastTextColor = .black
            subError = errorType
        }
    }
    
    func getStoriesFromDisk() -> [StoryType: [StoryWrapper]] {
        let data = try? Data(contentsOf: fileUrl)
        
        if let data {
            do {
                let safeData = try JSONDecoder().decode([StoryType: [StoryWrapper]].self, from: data)
                return safeData
            } catch {
                let errorType = ErrorType(error: .diskLoadError)
                subToastText = errorType.error.localizedDescription
                subToastTextColor = .black
                subError = errorType
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


