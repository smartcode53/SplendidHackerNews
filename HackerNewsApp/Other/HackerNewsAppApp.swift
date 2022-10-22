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
    
    var body: some Scene {
        WindowGroup {
            TabEnclosingView()
                .environmentObject(globalSettings)
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
                        globalSettings.saveSettingsToDisk()
                    }
                }
        }
    }
}
