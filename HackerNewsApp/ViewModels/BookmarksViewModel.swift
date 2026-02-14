//
//  BookmarksViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/24/22.
//

import Foundation
import SwiftUI

@MainActor
class BookmarksViewModel: ObservableObject, SafariViewLoader {
    
    enum SortType: String, CaseIterable {
        case lastSaved = "Last Saved"
        case comments = "Comments"
        case points = "Points"
    }
    
    @Published var bookmarks: [Bookmark] = []
    @Published var selectedSortType: SortType = .lastSaved {
        didSet {
            switch oldValue {
            case .lastSaved:
                bookmarks.sort { item1, item2 in
                    item1.date > item2.date
                }
            case .comments:
                bookmarks.sort { item1, item2 in
                    item1.story.descendants ?? 0 > item2.story.descendants ?? 0
                }
            case .points:
                bookmarks.sort { item1, item2 in
                    item1.story.score > item2.story.score
                }
            }
        }
    }
    
    lazy var networkManager: NetworkManager = NetworkManager.instance
    private let syncManager = iCloudSyncManager.shared
    private var iCloudSyncEnabled = false
    private var iCloudObserver: NSObjectProtocol?
    private var isApplyingRemoteBookmarks = false
    let fileUrl = FileManager().documentsDirectory.appending(component: "bookmark.txt")
    
    init() {
        let data = try? Data(contentsOf: fileUrl)
        if let data {
            do {
                let safeData = try JSONDecoder().decode([Bookmark].self, from: data)
                bookmarks = safeData
            } catch let error {
                print("There was an error decoding the bookmarks array. Here's the error description: \(error)")
            }
        }
    }
    
    func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(bookmarks)
            try data.write(to: fileUrl, options: [.atomic])
        } catch let error {
            print("There was an error encoding and saving the bookmarks array. Here's the error description: \(error)")
        }

        let snapshot = bookmarks
        Task {
            await SpotlightIndexer.shared.indexBookmarks(snapshot)
            await WidgetDataProvider.shared.refreshFromDisk()
        }

        guard iCloudSyncEnabled else { return }
        guard !isApplyingRemoteBookmarks else { return }
        Task {
            await syncManager.pushBookmarks(snapshot, updatedAt: Date())
        }
    }

    func configureICloudSync(enabled: Bool) {
        iCloudSyncEnabled = enabled
        if enabled {
            startICloudObservation()
            Task { await pullFromICloudIfNeeded() }
        } else {
            stopICloudObservation()
        }
    }

    func pullFromICloudIfNeeded() async {
        guard iCloudSyncEnabled else { return }
        let local = iCloudSyncManager.BookmarksRecord(bookmarks: bookmarks, updatedAt: Date())
        guard let remote = await syncManager.fetchBookmarksRecord() else { return }
        let merged = await syncManager.mergeBookmarks(local: local, remote: remote)
        isApplyingRemoteBookmarks = true
        bookmarks = merged.bookmarks
        saveToDisk()
        isApplyingRemoteBookmarks = false
    }

    private func startICloudObservation() {
        guard iCloudObserver == nil else { return }
        iCloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.pullFromICloudIfNeeded()
            }
        }
    }

    private func stopICloudObservation() {
        guard let iCloudObserver else { return }
        NotificationCenter.default.removeObserver(iCloudObserver)
        self.iCloudObserver = nil
    }

}
