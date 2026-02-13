//
//  GlobalSettingsViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/25/22.
//

import Combine
import Foundation
import SwiftUI

@MainActor
class GlobalSettingsViewModel: ObservableObject {
    
    @Published var settings: Settings
    @Published var tempBookmarks: [Bookmark]
    @Published private(set) var bookmarkedStoryIDs: Set<Int>
    private let persistence: SettingsPersistenceCoordinator<Settings>
    private var settingsCancellable: AnyCancellable?
#if DEBUG
    @Published var debugSettings: DebugSettings
    private let debugPersistence: SettingsPersistenceCoordinator<DebugSettings>
    private var debugSettingsCancellable: AnyCancellable?
#endif
    
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

    var isHNWriteEnabled: Bool {
        #if DEBUG
        return debugSettings.enableHNWriteActions
        #else
        return false
        #endif
    }
    
    let url: URL
    private let bookmarkURL: URL
    
    init() {
        let fileURL = FileManager.default.documentsDirectory.appending(component: "settings.txt")
        self.url = fileURL
        self.bookmarkURL = FileManager.default.documentsDirectory.appending(component: "bookmark.txt")
        self.persistence = SettingsPersistenceCoordinator(fileURL: fileURL)

        var loadedSettings = Settings(cardStyleString: Settings.CardStyle.normal.rawValue, themeString: Settings.Theme.automatic.rawValue)
        do {
            let data = try Data(contentsOf: fileURL)
            if let settings = try? JSONDecoder().decode(Settings.self, from: data) {
                loadedSettings = settings
            } else {
                loadedSettings = Settings(cardStyleString: Settings.CardStyle.normal.rawValue, themeString: Settings.Theme.automatic.rawValue)
            }
        } catch let error {
            print(error)
            loadedSettings = Settings(cardStyleString: Settings.CardStyle.normal.rawValue, themeString: Settings.Theme.automatic.rawValue)
        }
        self.settings = loadedSettings

#if DEBUG
        let debugFileURL = FileManager.default.documentsDirectory.appending(component: "debug-settings.json")
        self.debugPersistence = SettingsPersistenceCoordinator(fileURL: debugFileURL)
        var loadedDebugSettings = DebugSettings()
        do {
            let data = try Data(contentsOf: debugFileURL)
            if let debugSettings = try? JSONDecoder().decode(DebugSettings.self, from: data) {
                loadedDebugSettings = debugSettings
            } else {
                loadedDebugSettings = DebugSettings()
            }
        } catch let error {
            print(error)
            loadedDebugSettings = DebugSettings()
        }
        self.debugSettings = loadedDebugSettings
#endif

        self.tempBookmarks = []
        if let data = try? Data(contentsOf: bookmarkURL),
           let storedBookmarks = try? JSONDecoder().decode([Bookmark].self, from: data) {
            self.bookmarkedStoryIDs = Set(storedBookmarks.map { $0.story.id })
        } else {
            self.bookmarkedStoryIDs = []
        }
        startObservingSettings()
#if DEBUG
        startObservingDebugSettings()
#endif
    }
    
    func saveSettings() {
        let snapshot = settings
        Task { [persistence = persistence] in
            await persistence.saveNow(snapshot: snapshot)
        }
#if DEBUG
        let debugSnapshot = debugSettings
        Task { [debugPersistence = debugPersistence] in
            await debugPersistence.saveNow(snapshot: debugSnapshot)
        }
#endif
    }

    private func startObservingSettings() {
        settingsCancellable = $settings
            .dropFirst()
            .sink { [weak self] updated in
                guard let self else { return }
                let persistence = self.persistence
                Task { [persistence] in
                    await persistence.scheduleSave(snapshot: updated)
                }
            }
    }

#if DEBUG
    private func startObservingDebugSettings() {
        debugSettingsCancellable = $debugSettings
            .dropFirst()
            .sink { [weak self] updated in
                guard let self else { return }
                let persistence = self.debugPersistence
                Task { [persistence] in
                    await persistence.scheduleSave(snapshot: updated)
                }
            }
    }
#endif

    func isStoryBookmarked(_ storyID: Int) -> Bool {
        bookmarkedStoryIDs.contains(storyID) || tempBookmarks.contains(where: { $0.story.id == storyID })
    }

    @discardableResult
    func addBookmarkIfNeeded(story: Story) -> Bool {
        guard !isStoryBookmarked(story.id) else { return false }
        tempBookmarks.append(Bookmark(story: story))
        bookmarkedStoryIDs.insert(story.id)
        return true
    }

    func syncBookmarkedStoryIDs(from bookmarks: [Bookmark]) {
        bookmarkedStoryIDs = Set(bookmarks.map { $0.story.id })
    }

    var proEntitlementCachedAt: Date? {
        settings.proEntitlementCachedAt
    }

    func updateProEntitlementCacheDate(_ date: Date?) {
        settings.proEntitlementCachedAt = date
    }
}
