//
//  Dependencies.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/26/23.
//

import Foundation


class Dependencies {
    let commentsCacheManager = CommentsCache()
    let networkManager = NetworkManager()
    let notificationsManager = NotificationsManager()
}
