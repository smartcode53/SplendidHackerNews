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
#if DEBUG
    @StateObject var hnAccount = HNAccount()
#endif
    
    var body: some Scene {
        WindowGroup {
            TabEnclosingView()
                .environmentObject(globalSettings)
#if DEBUG
                .environmentObject(hnAccount)
#endif
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
#if DEBUG
                .task {
                    if DebugEnvironment.shared.fixtureMode {
                        DebugEnvironment.shared.fixtureMode = false
                    }
                }
#endif
                .onChange(of: scenePhase) { phase in
                    if phase == .inactive {
                        globalSettings.saveSettings()
                    }
                }
        }
    }
}
