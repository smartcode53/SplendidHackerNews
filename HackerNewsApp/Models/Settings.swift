//
//  Settings.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/27/22.
//

import Foundation
import SwiftUI

struct Settings: Codable {
    var cardStyleString: String
    var themeString: String
    
    enum CardStyle: String, CaseIterable {
        case compact = "Compact"
        case normal = "Normal"
    }
    
    enum Theme: String, CaseIterable {
        case dark = "Dark"
        case light = "Light"
        case automatic = "Automatic"
    }
    
    static let defaultSettings = Settings(cardStyleString: Settings.CardStyle.normal.rawValue, themeString: Settings.Theme.automatic.rawValue)
}
