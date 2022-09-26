//
//  TabEnclosingView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/24/22.
//

import SwiftUI

struct TabEnclosingView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Image(systemName: "newspaper")
                    Text("Feed")
                }
            
            BookmarksView()
                .tabItem {
                    Image(systemName: "bookmark")
                    Text("Saved Stories")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
        .onAppear {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
        .accentColor(.orange)
    }
}

struct TabEnclosingView_Previews: PreviewProvider {
    static var previews: some View {
        TabEnclosingView()
    }
}
