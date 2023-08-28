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
    @StateObject var nav = GlobalNavigator()
    let dependencies = Dependencies()
    
    var body: some Scene {
        WindowGroup {
            TabEnclosingView(dependencies: dependencies)
                .environmentObject(globalSettings)
                .environmentObject(nav)
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
