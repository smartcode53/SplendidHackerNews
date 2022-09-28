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
    
    func openMail() {
        let url = URL(string: "message://")
        if let url = url {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}
