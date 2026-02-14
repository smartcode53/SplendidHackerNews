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
    case smartfeed = "Smart Feed"
    case topstories = "Top Stories"
    case newstories = "New Stories"
    case beststories = "Best Stories"
    case askstories = "Ask HN"
    case showstories = "Show HN"
    case jobstories = "Jobs"
    
    var endpoint: String {
        switch self {
        case .smartfeed:
            return "topstories"
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
    @Published var storyType = StoryType.topstories
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var initialLoadState: LoadState = .idle
    @Published var refreshErrorMessage: String?
    @Published var loadMoreState: LoadState = .idle
    @Published var errorMessage: String?
    @Published var hideRead = false
    @Published var activeFilter: FeedFilter?
    
    private let repository: StoryRepository
    private let readStateStore: ReadStateStore
    private let historyStore: HistoryStore
    private var ids: [Int] = []
    private var nextIndex = 0
    private let pageSize = 30
    private var loadedIDs = Set<Int>()
    private var readIDs = Set<Int>()
    private var activeFeedRequestID = UUID()
    private var refreshingRequestID: UUID?
    private var feedChangeTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    private var initialFeedOverride: (type: StoryType, filter: FeedFilter?)?
    
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
            let initialOverride = initialFeedOverride
            let requestID = UUID()
            activeFeedRequestID = requestID
            await applyFeedChange(
                for: initialOverride?.type ?? storyType,
                requestID: requestID,
                preferredHideRead: nil,
                preferredFilter: initialOverride?.filter,
                persistFilter: false
            )
            initialFeedOverride = nil
        }
    }

    func configureInitialFeed(type: StoryType, filter: FeedFilter?) {
        guard stories.isEmpty else { return }
        let normalizedFilter = filter?.normalized()
        storyType = type
        activeFilter = normalizedFilter
        initialFeedOverride = (type: type, filter: normalizedFilter)
    }

    func setStoryType(_ newType: StoryType) {
        guard storyType != newType else { return }
        #if DEBUG
        print("[Feed] Switching to \(newType.rawValue). Resetting state.")
        #endif
        beginFeedChange(to: newType, preferredHideRead: nil, persistHideRead: false)
    }

    func setHideRead(_ newValue: Bool) {
        guard hideRead != newValue else { return }
        beginFeedChange(to: storyType, preferredHideRead: newValue, persistHideRead: true)
    }

    func setActiveFilter(_ filter: FeedFilter?) {
        let normalized = filter?.normalized()
        if activeFilter == normalized {
            return
        }
        beginFeedChange(
            to: storyType,
            preferredHideRead: nil,
            persistHideRead: false,
            preferredFilter: normalized,
            persistFilter: true
        )
    }
    
    func refresh() async {
        let requestID = activeFeedRequestID
        let selectedStoryType = storyType
        let selectedHideRead = hideRead
        let selectedFilter = activeFilter
        await refresh(
            requestID: requestID,
            force: false,
            storyType: selectedStoryType,
            hideRead: selectedHideRead,
            filter: selectedFilter
        )
    }

    private func refresh(
        requestID: UUID,
        force: Bool,
        storyType: StoryType,
        hideRead: Bool,
        filter: FeedFilter?
    ) async {
        #if DEBUG
        if DebugEnvironment.shared.fixtureMode {
            await applyFixtureIfNeeded()
            return
        }
        #endif
        cancelPrefetch()
        guard force || !isRefreshing else { return }

        refreshingRequestID = requestID
        isRefreshing = true
        defer {
            if refreshingRequestID == requestID {
                isRefreshing = false
                refreshingRequestID = nil
            }
        }

        refreshErrorMessage = nil
        errorMessage = nil
        loadMoreState = .idle

        let hadStories = !stories.isEmpty
        if !hadStories {
            initialLoadState = .loading
        }

        readIDs = await readStateStore.readIDsSnapshot()

        do {
            let fetchedIDs: [Int]
            if storyType == .smartfeed {
                let baseIDs = try await RetryPolicy.runWithTransientRetry { [self] in
                    try await repository.fetchIDs(type: .topstories)
                }
                let candidateIDs = Array(baseIDs.prefix(500))
                let candidateStories = try await RetryPolicy.runWithTransientRetry { [self] in
                    try await repository.fetchStories(ids: candidateIDs)
                }
                let affinitySnapshot = await SmartFeedStore.shared.snapshot()
                let rankedStories = SmartFeedRanker.rank(stories: candidateStories, affinity: affinitySnapshot)
                fetchedIDs = rankedStories.map(\.id)
            } else {
                fetchedIDs = try await RetryPolicy.runWithTransientRetry { [self] in
                    try await repository.fetchIDs(type: storyType)
                }
            }
            guard isActiveRequest(requestID), !Task.isCancelled else { return }
            #if DEBUG
            let preview = fetchedIDs.prefix(5).map(String.init).joined(separator: ", ")
            print("[Feed] IDs fetched (\(storyType.rawValue)) first 5: \(preview)")
            #endif

            let page = try await fetchPage(
                ids: fetchedIDs,
                startIndex: 0,
                loadedIDs: [],
                readIDs: readIDs,
                hideRead: hideRead,
                filter: filter
            )
            guard isActiveRequest(requestID), !Task.isCancelled else { return }

            // Display stories immediately, then prefetch images concurrently.
            // Previously: awaited prefetchImageURLs BEFORE setting stories,
            // delaying the entire feed display by the full OG fetch time.
            // Now: stories appear instantly; images load in the background.
            ids = fetchedIDs
            nextIndex = page.nextIndex
            loadedIDs = page.loadedIDs
            stories = page.appended
            loadMoreState = .idle
            initialLoadState = page.appended.isEmpty ? .empty : .loaded

            // Fire-and-forget: prefetch images in background without blocking UI
            let storiesToPrefetch = page.appended
            schedulePrefetch(for: storiesToPrefetch, maxItems: 16)
        } catch is CancellationError {
            return
        } catch {
            guard isActiveRequest(requestID), !Task.isCancelled else { return }
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
    }
    
    /// Triggers loading the next page when the user scrolls near the end.
    /// Uses a ~70% threshold: triggers when the user reaches the story at
    /// approximately `stories.count - prefetchThreshold` from the end.
    /// Previously only triggered at the very last story, causing visible wait times.
    func loadMoreIfNeeded(currentIndex: Int) async {
        #if DEBUG
        if DebugEnvironment.shared.fixtureMode {
            return
        }
        #endif
        let threshold = 10
        let count = stories.count
        guard count > 0 else { return }
        if currentIndex >= count - threshold {
            await loadNextPage()
        }
    }

    /// Legacy ID-based trigger retained for compatibility.
    func loadMoreIfNeeded(currentID: Int) async {
        #if DEBUG
        if DebugEnvironment.shared.fixtureMode {
            return
        }
        #endif
        guard let currentIndex = stories.firstIndex(where: { $0.id == currentID }) else { return }
        await loadMoreIfNeeded(currentIndex: currentIndex)
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

    func adjacentStories(for storyID: Int) -> (previous: Story?, next: Story?) {
        guard let index = stories.firstIndex(where: { $0.id == storyID }) else {
            return (nil, nil)
        }
        let previous = index > 0 ? stories[index - 1] : nil
        let next = index < stories.count - 1 ? stories[index + 1] : nil
        return (previous, next)
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
                hideRead: hideRead,
                filter: activeFilter
            )

            // Update state and append stories immediately before prefetching images.
            // Image prefetch runs concurrently in the background.
            nextIndex = page.nextIndex
            loadedIDs = page.loadedIDs

            if !page.appended.isEmpty {
                stories.append(contentsOf: page.appended)
                #if DEBUG
                let preview = page.appended.prefix(5).map { String($0.id) }.joined(separator: ", ")
                print("[Feed] Appended \(page.appended.count) stories. First 5 appended: \(preview)")
                #endif

                // Fire-and-forget: prefetch images in background without blocking pagination
                let storiesToPrefetch = page.appended
                schedulePrefetch(for: storiesToPrefetch, maxItems: 12)
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

    private func beginFeedChange(
        to newType: StoryType,
        preferredHideRead: Bool?,
        persistHideRead: Bool,
        preferredFilter: FeedFilter? = nil,
        persistFilter: Bool = false
    ) {
        let requestID = UUID()
        activeFeedRequestID = requestID
        feedChangeTask?.cancel()
        feedChangeTask = Task { [weak self] in
            guard let self else { return }
            await self.applyFeedChange(
                for: newType,
                requestID: requestID,
                preferredHideRead: preferredHideRead,
                persistHideRead: persistHideRead,
                preferredFilter: preferredFilter,
                persistFilter: persistFilter
            )
        }
    }

    private func applyFeedChange(
        for storyType: StoryType,
        requestID: UUID,
        preferredHideRead: Bool?,
        persistHideRead: Bool = false,
        preferredFilter: FeedFilter? = nil,
        persistFilter: Bool = false
    ) async {
        self.storyType = storyType

        let resolvedHideRead: Bool
        if let preferredHideRead {
            resolvedHideRead = preferredHideRead
            hideRead = preferredHideRead
            if persistHideRead {
                await readStateStore.setHideRead(for: storyType, value: preferredHideRead)
            }
        } else {
            resolvedHideRead = await readStateStore.hideRead(for: storyType)
            guard isActiveRequest(requestID), !Task.isCancelled else { return }
            hideRead = resolvedHideRead
        }

        let resolvedFilter: FeedFilter?
        if preferredFilter != nil || persistFilter {
            resolvedFilter = preferredFilter
            activeFilter = preferredFilter
            if persistFilter {
                await readStateStore.setFilter(for: storyType, value: preferredFilter)
            }
        } else {
            resolvedFilter = await readStateStore.filter(for: storyType)
            guard isActiveRequest(requestID), !Task.isCancelled else { return }
            activeFilter = resolvedFilter
        }

        guard isActiveRequest(requestID), !Task.isCancelled else { return }
        cancelPrefetch()
        ids.removeAll()
        nextIndex = 0
        loadedIDs.removeAll()
        stories.removeAll()
        initialLoadState = .loading

        await refresh(
            requestID: requestID,
            force: true,
            storyType: storyType,
            hideRead: resolvedHideRead,
            filter: resolvedFilter
        )
    }

    private func isActiveRequest(_ requestID: UUID) -> Bool {
        requestID == activeFeedRequestID
    }

    private func schedulePrefetch(for stories: [Story], maxItems: Int) {
        prefetchTask?.cancel()
        prefetchTask = Task { [weak self] in
            await self?.prefetchImageURLs(for: stories, maxItems: maxItems)
        }
    }

    private func cancelPrefetch() {
        prefetchTask?.cancel()
        prefetchTask = nil
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

    /// Prefetches OpenGraph image URLs for the given stories.
    /// Uses a single TaskGroup with all candidates launched concurrently.
    /// Deduplication of in-flight requests is handled by NetworkManager's
    /// OpenGraphDeduplicator, so even if PostView's .task fires concurrently,
    /// only one OG fetch per URL occurs.
    /// Previously: sequential batches of 6 = many round-trips.
    /// Now: all candidates launch at once; HTTP connection limits in URLSession
    /// naturally throttle actual network concurrency.
    private func prefetchImageURLs(for stories: [Story], maxItems: Int) async {
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
        let boundedCandidates = Array(candidates.prefix(maxItems))
        guard !boundedCandidates.isEmpty else { return }

        // Bound prefetch work to avoid overloading networking + parsing while scrolling.
        let maxConcurrent = 4
        var start = 0
        while start < boundedCandidates.count {
            if Task.isCancelled { return }
            let end = min(start + maxConcurrent, boundedCandidates.count)
            let chunk = boundedCandidates[start..<end]

            await withTaskGroup(of: Void.self) { group in
                for (storyId, urlString) in chunk {
                    group.addTask { [networkManager] in
                        if Task.isCancelled { return }
                        let resultUrl = await networkManager.getImage(fromUrl: urlString)
                        if Task.isCancelled { return }
                        if let resultUrl {
                            urlCache.saveToCache(resultUrl, withKey: String(storyId))
                            availabilityCache.saveToCache(true, withKey: String(storyId))
                        } else {
                            availabilityCache.saveToCache(false, withKey: String(storyId))
                        }
                    }
                }
            }
            start = end
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
        hideRead: Bool,
        filter: FeedFilter?
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
            let filtered = ordered.filter { story in
                guard let filter else { return true }
                return filter.matches(story)
            }
            for story in ordered {
                loadedIDs.insert(story.id)
            }
            appended.append(contentsOf: filtered)
        }

        return PageResult(appended: appended, nextIndex: nextIndex, loadedIDs: loadedIDs)
    }
    
}
