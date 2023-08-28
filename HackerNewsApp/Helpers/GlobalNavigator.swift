//
//  GlobalNavigator.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/25/23.
//

import Foundation

class GlobalNavigator: ObservableObject {
    
    @Published var feedRoutes = [FeedRoute]()
    @Published var bookmarksRoutes = [BookmarksRoute]()
    @Published var settingsRoutes = [SettingsRoute]()
    
    public func push<T: GlobalNavigationProtocol>(to route: T.Type, path: T) async {
        await MainActor.run { [weak self] in
            guard let self else { return }
            
            if route == FeedRoute.self {
                guard let safePath = path as? FeedRoute else { return }
                self.feedRoutes.append(safePath)
            } else if route == BookmarksRoute.self {
                guard let safePath = path as? BookmarksRoute else { return }
                self.bookmarksRoutes.append(safePath)
            } else if route == SettingsRoute.self {
                guard let safePath = path as? SettingsRoute else { return }
                self.settingsRoutes.append(safePath)
            }
        }
    }
    
    public func pop<T: GlobalNavigationProtocol>(within route: T.Type) async {
        await MainActor.run { [weak self] in
            guard let self else { return }
            
            if route == FeedRoute.self {
                self.feedRoutes.removeLast()
            } else if route == BookmarksRoute.self {
                self.bookmarksRoutes.removeLast()
            } else if route == SettingsRoute.self {
                self.settingsRoutes.removeLast()
            }
            
        }
    }
    
    public func popToRoot<T: GlobalNavigationProtocol>(within route: T.Type) async {
        await MainActor.run { [weak self] in
            guard let self else { return }
            
            if route == FeedRoute.self {
                self.feedRoutes.removeAll()
            } else if route == BookmarksRoute.self {
                self.bookmarksRoutes.removeAll()
            } else if route == SettingsRoute.self {
                self.settingsRoutes.removeAll()
            }
            
        }
    }
}

protocol GlobalNavigationProtocol: Hashable { }

enum FeedRoute: GlobalNavigationProtocol {
    case commentsView
}

enum BookmarksRoute: GlobalNavigationProtocol {
    case postDetailView
}

enum SettingsRoute: GlobalNavigationProtocol {
    case postDetailView
}
