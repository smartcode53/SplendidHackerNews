//
//  HackerNewsAppApp.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import SwiftUI

@main
struct HackerNewsAppApp: App {
    
    @State var globalSettings = GlobalSettingsViewModel()
    
    var body: some Scene {
        WindowGroup {
            TabEnclosingView()
                .environmentObject(globalSettings)
        }
    }
}
