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
            await applyFeedChange()
        }
    }
    
    func applyFeedChange() async {
        hideRead = await readStateStore.hideRead(for: storyType)
        await refresh()
    }
    
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        ids.removeAll()
        nextIndex = 0
        loadedIDs.removeAll()
        readIDs = await readStateStore.readIDsSnapshot()
        stories.removeAll()
        
        do {
            ids = try await repository.fetchIDs(type: storyType)
            #if DEBUG
            let preview = ids.prefix(5).map(String.init).joined(separator: ", ")
            print("[Feed] IDs fetched (\(storyType.rawValue)) first 5: \(preview)")
            #endif
            await loadNextPage()
        } catch {
            errorMessage = "Failed to load stories."
        }
        
        isRefreshing = false
    }
    
    func loadMoreIfNeeded(currentID: Int) async {
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
    
    private func loadNextPage() async {
        guard !isLoading else { return }
        guard nextIndex < ids.count else { return }
        
        isLoading = true
        var appended: [Story] = []
        
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
            
            do {
                let fetched = try await repository.fetchStories(ids: newIDs)
                let byId = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
                let ordered = newIDs.compactMap { byId[$0] }
                for story in ordered {
                    loadedIDs.insert(story.id)
                }
                appended.append(contentsOf: ordered)
            } catch {
                errorMessage = "Failed to load stories."
                break
            }
        }
        
        if !appended.isEmpty {
            stories.append(contentsOf: appended)
            #if DEBUG
            let preview = appended.prefix(5).map { String($0.id) }.joined(separator: ", ")
            print("[Feed] Appended \(appended.count) stories. First 5 appended: \(preview)")
            #endif
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
    
    nonisolated func returnSafelyLoadedUrl(url: String) -> URL {
        return networkManager.safelyLoadUrl(url: url)
    }
}
