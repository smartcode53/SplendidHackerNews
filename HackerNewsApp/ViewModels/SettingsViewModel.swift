//
//  SettingsViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/26/22.
//

import Foundation
import SwiftUI

class SettingsViewModel: ObservableObject {
    
    enum CardStyle: String, CaseIterable {
        case compact = "Compact"
        case normal = "Normal"
    }
    
    enum Theme: String, CaseIterable {
        case dark = "Dark"
        case light = "Light"
        case automatic = "Automatic"
    }
    
    @Published var showCardStylingOptions = false
}
