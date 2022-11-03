//
//  GlobalSettingsViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/25/22.
//

import Foundation
import SwiftUI

class GlobalSettingsViewModel: ObservableObject {
    
    @Published var settings: Settings
    @Published var bookmarks: [Bookmark] = []
    @Published var selectedSortType: SortType = .lastSaved {
        didSet {
            switch selectedSortType {
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
    @Published var appError: ErrorType? = nil {
        didSet {
            if appError != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    withAnimation(.spring()) {
                        self?.appError = nil
                    }
                }
            }
        }
    }
    @Published var toastText: String = "All Good!"
    @Published var toastTextColor: Color = .primary
    
    let firstTimeBoolKey: String = "firstTime"
    let userDefaults: UserDefaults = UserDefaults.standard
    let settingsUrl = FileManager.default.documentsDirectory.appending(component: "settings.txt")
    let bookmarkUrl = FileManager().documentsDirectory.appending(component: "bookmark.txt")
    
    var selectedCardStyle: Settings.CardStyle {
        switch settings.cardStyleString {
        case "Normal":
            return .normal
        case "Compact":
            return .compact
        default:
            return .normal
        }
    }
    var selectedTheme: Settings.Theme {
        switch settings.themeString {
        case "Dark":
            return .dark
        case "Light":
            return .light
        case "Automatic":
            return .automatic
        default:
            return .automatic
        }
    }
    
    
    init() {
        
        
        // Checking if it's the first time the Settings screen is being accessed.
        if userDefaults.value(forKey: firstTimeBoolKey) == nil {
            userDefaults.set(true, forKey: firstTimeBoolKey)
        }
        
        // Loading settings from disk
        if userDefaults.bool(forKey: firstTimeBoolKey) {
            userDefaults.set(false, forKey: firstTimeBoolKey)
            self.settings = Settings.defaultSettings
        } else {
            do {
                let data = try Data(contentsOf: settingsUrl)
                let decodedData = try JSONDecoder().decode(Settings.self, from: data)
                self.settings = decodedData
            } catch {
                // MARK: Update error here
                self.settings = Settings.defaultSettings
                print("There was an error loading settings. Reverted to default settings")
            }
        }
        
        
        // Loading bookmarks from disk
        do {
            let data = try Data(contentsOf: bookmarkUrl)
            let convertedArray = try JSONDecoder().decode([Bookmark].self, from: data)
            self.bookmarks = convertedArray
            self.bookmarks = self.bookmarks.sorted { item1, item2 in
                item1.date > item2.date
            }
        } catch {
            // MARK: Return error here
            print("Error loading bookmarks")
        }
        
    }
    
    func saveSettingsToDisk() {
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsUrl)
        } catch let error {
            print(error)
        }
    }
    
    func saveBookmarksToDisk() {
        do {
            let data = try JSONEncoder().encode(bookmarks)
            try data.write(to: bookmarkUrl, options: [.atomic])
        } catch let error {
            print("There was an error encoding and saving the bookmarks array. Here's the error description: \(error)")
        }
    }
    
    func sortBookmarks() -> [Bookmark] {
        switch selectedSortType {
        case .lastSaved:
            return bookmarks.sorted { item1, item2 in
                item1.date > item2.date
            }
        case .comments:
            return bookmarks.sorted { item1, item2 in
                item1.story.descendants ?? 0 > item2.story.descendants ?? 0
            }
        case .points:
            return bookmarks.sorted { item1, item2 in
                item1.story.score > item2.story.score
            }
        }
    }
}
