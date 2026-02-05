//
//  TabEnclosingView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/24/22.
//

import SwiftUI
import UIKit

enum TabDestination: Hashable {
    case feed
    case saved
    case settings
}

@MainActor
final class TabRouter: ObservableObject {
    @Published var selectedTab: TabDestination = .feed
}

struct TabEnclosingView: View {
    @StateObject private var tabRouter = TabRouter()

    var body: some View {
        TabView(selection: $tabRouter.selectedTab) {
            ContentRootView()
                .tabItem {
                    Label("Feed", systemImage: "newspaper")
                        .accessibilityIdentifier("tab.feed")
                        .accessibilityLabel("Feed")
                        .accessibilityElement(children: .combine)
                }
                .tag(TabDestination.feed)
            
            BookmarksRootView()
                .tabItem {
                    Label("Saved Stories", systemImage: "bookmark")
                        .accessibilityIdentifier("tab.saved")
                        .accessibilityLabel("Saved Stories")
                        .accessibilityElement(children: .combine)
                }
                .tag(TabDestination.saved)
            
            SettingsRootView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                        .accessibilityIdentifier("tab.settings")
                        .accessibilityLabel("Settings")
                        .accessibilityElement(children: .combine)
                }
                .tag(TabDestination.settings)
        }
        .onAppear {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
        .accentColor(.orange)
        .background(TabBarAccessibilityConfigurator())
        .environmentObject(tabRouter)
    }
}

struct TabEnclosingView_Previews: PreviewProvider {
    static var previews: some View {
        TabEnclosingView()
    }
}

private struct TabBarAccessibilityConfigurator: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            let tabBarController = Self.findTabBarController(from: uiViewController)
            guard let tabBarController, let items = tabBarController.tabBar.items, items.count >= 3 else { return }
            items[0].accessibilityIdentifier = "tab.feed"
            items[1].accessibilityIdentifier = "tab.saved"
            items[2].accessibilityIdentifier = "tab.settings"

            let tabBar = tabBarController.tabBar
            let tabButtons = tabBar.subviews
                .filter { $0 is UIControl }
                .sorted { $0.frame.minX < $1.frame.minX }
            guard tabButtons.count >= 3 else { return }
            tabButtons[0].accessibilityIdentifier = "tab.feed"
            tabButtons[1].accessibilityIdentifier = "tab.saved"
            tabButtons[2].accessibilityIdentifier = "tab.settings"
        }
    }

    private static func findTabBarController(from controller: UIViewController) -> UITabBarController? {
        if let tabBarController = controller.tabBarController {
            return tabBarController
        }
        if let root = controller.view.window?.rootViewController {
            return searchForTabBarController(root)
        }
        return nil
    }

    private static func searchForTabBarController(_ controller: UIViewController) -> UITabBarController? {
        if let tabBarController = controller as? UITabBarController {
            return tabBarController
        }
        for child in controller.children {
            if let found = searchForTabBarController(child) {
                return found
            }
        }
        if let presented = controller.presentedViewController {
            return searchForTabBarController(presented)
        }
        return nil
    }
}
