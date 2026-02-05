//
//  MainViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import Foundation
import SwiftUI

enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case error(message: String, canRetry: Bool)

    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    var isLoaded: Bool {
        if case .loaded = self {
            return true
        }
        return false
    }

    var errorMessage: String? {
        if case .error(let message, _) = self {
            return message
        }
        return nil
    }

    var canRetry: Bool {
        if case .error(_, let canRetry) = self {
            return canRetry
        }
        return false
    }
}

enum StoryType: String, CaseIterable {
    case topstories = "Top Stories"
    case newstories = "New Stories"
    case beststories = "Best Stories"
    case askstories = "Ask HN"
    case showstories = "Show HN"
    case jobstories = "Jobs"
    
    var endpoint: String {
        switch self {
        case .askstories:
            return "askstories"
        case .beststories:
            return "beststories"
        case .newstories:
            return "newstories"
        case .showstories:
            return "showstories"
        case .topstories:
            return "topstories"
        case .jobstories:
            return "jobstories"
        }
    }
}


@MainActor
class ContentViewModel: SafariViewLoader {
    
    @Published var stories: [Story] = []
    @Published var storyType = StoryType.topstories {
        didSet {
            #if DEBUG
            print("[Feed] Switching to \(storyType.rawValue). Resetting state.")
            #endif
            Task { await applyFeedChange() }
        }
    }
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var initialLoadState: LoadState = .idle
    @Published var refreshErrorMessage: String?
    @Published var loadMoreState: LoadState = .idle
    @Published var errorMessage: String?
    @Published var hideRead = false {
        didSet {
            Task { await applyHideReadChange() }
        }
    }
    
    private let repository: StoryRepository
    private let readStateStore: ReadStateStore
    private let historyStore: HistoryStore
    private var ids: [Int] = []
    private var nextIndex = 0
    private let pageSize = 30
    private var loadedIDs = Set<Int>()
    private var readIDs = Set<Int>()
    
    let networkManager: NetworkManager = NetworkManager.instance
    
    init(repository: StoryRepository = StoryRepository(),
         readStateStore: ReadStateStore = ReadStateStore.shared,
         historyStore: HistoryStore = HistoryStore.shared) {
        self.repository = repository
        self.readStateStore = readStateStore
        self.historyStore = historyStore
    }
    
    func loadInitial() async {
        if stories.isEmpty {
            #if DEBUG
            if DebugEnvironment.shared.fixtureMode {
                await applyFixtureIfNeeded()
                return
            }
            #endif
            await applyFeedChange()
        }
    }
    
    func applyFeedChange() async {
        hideRead = await readStateStore.hideRead(for: storyType)
        ids.removeAll()
        nextIndex = 0
        loadedIDs.removeAll()
        stories.removeAll()
        initialLoadState = .loading
        await refresh()
    }
    
    func refresh() async {
        #if DEBUG
        if DebugEnvironment.shared.fixtureMode {
            await applyFixtureIfNeeded()
            return
        }
        #endif
        guard !isRefreshing else { return }
        isRefreshing = true
        refreshErrorMessage = nil
        errorMessage = nil
        loadMoreState = .idle

        let hadStories = !stories.isEmpty
        if !hadStories {
            initialLoadState = .loading
        }

        readIDs = await readStateStore.readIDsSnapshot()

        do {
            let fetchedIDs = try await RetryPolicy.runWithTransientRetry { [self] in
                try await repository.fetchIDs(type: storyType)
            }
            #if DEBUG
            let preview = fetchedIDs.prefix(5).map(String.init).joined(separator: ", ")
            print("[Feed] IDs fetched (\(storyType.rawValue)) first 5: \(preview)")
            #endif

            let page = try await fetchPage(
                ids: fetchedIDs,
                startIndex: 0,
                loadedIDs: [],
                readIDs: readIDs,
                hideRead: hideRead
            )

            await prefetchImageURLs(for: page.appended)

            ids = fetchedIDs
            nextIndex = page.nextIndex
            loadedIDs = page.loadedIDs
            stories = page.appended
            loadMoreState = .idle
            initialLoadState = page.appended.isEmpty ? .empty : .loaded
        } catch {
            let message = ErrorPresenter.message(
                for: error,
                defaultMessage: "Check your connection and try again.",
                debugTag: "HN_FEED"
            )
            if hadStories {
                refreshErrorMessage = ErrorPresenter.message(
                    for: error,
                    defaultMessage: "Refresh failed. Pull to retry.",
                    debugTag: "HN_REFRESH"
                )
            } else {
                initialLoadState = .error(message: message, canRetry: true)
            }
        }

        isRefreshing = false
    }
    
    func loadMoreIfNeeded(currentID: Int) async {
        #if DEBUG
        if DebugEnvironment.shared.fixtureMode {
            return
        }
        #endif
        guard let lastID = stories.last?.id, currentID == lastID else { return }
        await loadNextPage()
    }
    
    func openStory(_ story: Story) async {
        await readStateStore.markRead(storyID: story.id)
        readIDs.insert(story.id)
        await historyStore.addEntry(story: story, feed: storyType)
        
        if hideRead {
            stories.removeAll { $0.id == story.id }
            loadedIDs.remove(story.id)
            await loadNextPage()
        }
    }

    func openComments(_ story: Story) async {
        await historyStore.addEntry(story: story, feed: storyType)
    }
    
    func isRead(_ storyID: Int) -> Bool {
        readIDs.contains(storyID)
    }

    func ensureStoryLoaded(targetID: Int, maxPages: Int) async -> Bool {
        if stories.contains(where: { $0.id == targetID }) {
            return true
        }
        var attempts = 0
        while attempts < maxPages {
            let beforeCount = stories.count
            await loadNextPage()
            if stories.contains(where: { $0.id == targetID }) {
                return true
            }
            attempts += 1
            if stories.count == beforeCount {
                break
            }
        }
        return false
    }
    
    func loadNextPage() async {
        #if DEBUG
        if DebugEnvironment.shared.fixtureMode {
            return
        }
        #endif
        guard !isLoading else { return }
        guard nextIndex < ids.count else { return }
        
        isLoading = true
        loadMoreState = .loading

        do {
            let page = try await fetchPage(
                ids: ids,
                startIndex: nextIndex,
                loadedIDs: loadedIDs,
                readIDs: readIDs,
                hideRead: hideRead
            )

            await prefetchImageURLs(for: page.appended)

            nextIndex = page.nextIndex
            loadedIDs = page.loadedIDs

            if !page.appended.isEmpty {
                stories.append(contentsOf: page.appended)
                #if DEBUG
                let preview = page.appended.prefix(5).map { String($0.id) }.joined(separator: ", ")
                print("[Feed] Appended \(page.appended.count) stories. First 5 appended: \(preview)")
                #endif
            }

            loadMoreState = .idle
        } catch {
            let message = ErrorPresenter.message(
                for: error,
                defaultMessage: "Load more failed. Tap to retry.",
                debugTag: "HN_LOAD_MORE"
            )
            loadMoreState = .error(message: message, canRetry: true)
        }

        isLoading = false
    }
    
    private func applyHideReadChange() async {
        await readStateStore.setHideRead(for: storyType, value: hideRead)
        loadedIDs = Set(stories.map { $0.id })
        if hideRead {
            stories.removeAll { readIDs.contains($0.id) }
            await loadNextPage()
        }
    }
    
    #if DEBUG
    func applyFixtureIfNeeded() async {
        guard DebugEnvironment.shared.fixtureMode else { return }
        isLoading = false
        isRefreshing = false
        errorMessage = nil
        refreshErrorMessage = nil
        ids.removeAll()
        nextIndex = 0
        loadedIDs.removeAll()
        readIDs = await readStateStore.readIDsSnapshot()
        stories = DebugFixtures.feedStories
        initialLoadState = stories.isEmpty ? .empty : .loaded
        loadMoreState = .idle
    }
    #endif

    private func prefetchImageURLs(for stories: [Story]) async {
        #if DEBUG
        if DebugEnvironment.shared.fixtureMode {
            return
        }
        #endif
        guard !stories.isEmpty else { return }

        let availabilityCache = UltimatePostViewModel.ImageAvailabilityCache.instance
        let urlCache = UltimatePostViewModel.ImageURLCache.instance

        let candidates = stories.compactMap { story -> (Int, String)? in
            guard let urlString = story.url else { return nil }
            let key = String(story.id)
            if urlCache.getFromCache(withKey: key) != nil { return nil }
            if let cached = availabilityCache.getFromCache(withKey: key), cached == false { return nil }
            return (story.id, urlString)
        }

        guard !candidates.isEmpty else { return }

        let batchSize = 6
        var index = 0
        while index < candidates.count {
            let end = min(index + batchSize, candidates.count)
            let batch = candidates[index..<end]
            await withTaskGroup(of: Void.self) { group in
                for (storyId, urlString) in batch {
                    group.addTask { [networkManager] in
                        let resultUrl = await networkManager.getImage(fromUrl: urlString)
                        if let resultUrl {
                            urlCache.saveToCache(resultUrl, withKey: String(storyId))
                            availabilityCache.saveToCache(true, withKey: String(storyId))
                        } else {
                            availabilityCache.saveToCache(false, withKey: String(storyId))
                        }
                    }
                }
            }
            index = end
        }
    }

    private struct PageResult {
        let appended: [Story]
        let nextIndex: Int
        let loadedIDs: Set<Int>
    }

    private func fetchPage(
        ids: [Int],
        startIndex: Int,
        loadedIDs: Set<Int>,
        readIDs: Set<Int>,
        hideRead: Bool
    ) async throws -> PageResult {
        var appended: [Story] = []
        var nextIndex = startIndex
        var loadedIDs = loadedIDs

        while appended.count < pageSize && nextIndex < ids.count {
            let endIndex = min(nextIndex + pageSize, ids.count)
            let pageIDs = Array(ids[nextIndex..<endIndex])
            nextIndex = endIndex

            let newIDs = pageIDs.filter { id in
                if loadedIDs.contains(id) {
                    #if DEBUG
                    print("[Feed] De-dupe skipped id \(id) (already loaded)")
                    #endif
                    return false
                }
                if hideRead && readIDs.contains(id) {
                    #if DEBUG
                    print("[Feed] De-dupe skipped id \(id) (read, hide enabled)")
                    #endif
                    return false
                }
                return true
            }

            if newIDs.isEmpty { continue }

            let fetched = try await RetryPolicy.runWithTransientRetry { [self] in
                try await repository.fetchStories(ids: newIDs)
            }
            let byId = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
            let ordered = newIDs.compactMap { byId[$0] }
            for story in ordered {
                loadedIDs.insert(story.id)
            }
            appended.append(contentsOf: ordered)
        }

        return PageResult(appended: appended, nextIndex: nextIndex, loadedIDs: loadedIDs)
    }
    
}
