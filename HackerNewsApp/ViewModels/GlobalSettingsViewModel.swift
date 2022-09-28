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
    @Published var tempBookmarks: [Bookmark]
    
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
    
    let url = FileManager.default.documentsDirectory.appending(component: "settings.txt")
    
    init() {
        do {
            let data = try Data(contentsOf: url)
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
    }
    
    func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: url)
        } catch let error {
            print(error)
        }
    }
}
