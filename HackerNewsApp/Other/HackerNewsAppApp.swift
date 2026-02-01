//
//  HackerNewsAppApp.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import SwiftUI

@main
struct HackerNewsAppApp: App {
    
    @Environment(\.scenePhase) var scenePhase
    @StateObject var globalSettings = GlobalSettingsViewModel()
    @StateObject var hnAccount = HNAccount()
    
    var body: some Scene {
        WindowGroup {
            TabEnclosingView()
                .environmentObject(globalSettings)
                .environmentObject(hnAccount)
                .preferredColorScheme(
                    globalSettings.selectedTheme == .automatic
                    ?
                        .none
                    :
                        globalSettings.selectedTheme == .dark
                    ?
                        .dark
                    :
                            .light
                )
                .onChange(of: scenePhase) { phase in
                    if phase == .inactive {
                        globalSettings.saveSettings()
                    }
                }
        }
    }
}
