//
//  SettingsViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/26/22.
//

import Foundation
import SwiftUI

class SettingsViewModel: ObservableObject {
    
    @Published var showCardStylingOptions = false
    @Published var showThemeOptions = false
    
    @Published var sendEmail: Bool = false
    
}
