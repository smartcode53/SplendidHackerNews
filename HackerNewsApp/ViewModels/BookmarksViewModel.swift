//
//  BookmarksViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/24/22.
//

import Foundation
import SwiftUI

class BookmarksViewModel: ObservableObject {
    
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
    }
    
}
