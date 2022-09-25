//
//  BookmarksViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/24/22.
//

import Foundation
import SwiftUI

class BookmarksViewModel: ObservableObject {
    
    @Published var bookmarks: [Bookmark] = []
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
    
    @Published var stories = [
        Story(by: "Taha", descendants: 12, id: 1, score: 234, time: 122334223, title: "Something needs to be said", type: "story", url: "https://google.com"),
        Story(by: "dissTrack", descendants: 245, id: 2, score: 56, time: 383894893, title: "The audacity of the president of the new country", type: "story", url: "https://madsen.com")
    ]
    
    func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(bookmarks)
            try data.write(to: fileUrl, options: [.atomic])
        } catch let error {
            print("There was an error encoding and saving the bookmarks array. Here's the error description: \(error)")
        }
    }
    
    
}
