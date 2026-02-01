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
    private let persistence: SettingsPersistenceCoordinator
    private var settingsCancellable: AnyCancellable?
    
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
        return settings.enableHNWriteActionsDebug
        #else
        return false
        #endif
    }
    
    let url: URL
    
    init() {
        let fileURL = FileManager.default.documentsDirectory.appending(component: "settings.txt")
        self.url = fileURL
        self.persistence = SettingsPersistenceCoordinator(fileURL: fileURL)

        do {
            let data = try Data(contentsOf: fileURL)
            if let settings = try? JSONDecoder().decode(Settings.self, from: data) {
                self.settings = settings
            } else {
                self.settings = Settings(cardStyleString: Settings.CardStyle.normal.rawValue, themeString: Settings.Theme.automatic.rawValue)
            }
        } catch let error {
            print(error)
            self.settings = Settings(cardStyleString: Settings.CardStyle.normal.rawValue, themeString: Settings.Theme.automatic.rawValue)
        }
        
        self.tempBookmarks = []
        startObservingSettings()
    }
    
    func saveSettings() {
        let snapshot = settings
        Task { [persistence = persistence] in
            await persistence.saveNow(snapshot: snapshot)
        }
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
}
