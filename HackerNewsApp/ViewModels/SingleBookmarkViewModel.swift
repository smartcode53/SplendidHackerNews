//
//  SingleBookmarkViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/24/22.
//

import Foundation
import SwiftUI

class SingleBookmarkViewModel: ObservableObject, SafariViewLoader, CommentsButtonProtocol {
    
    @Published var comments: Item?
    @Published var story: Story?
    @Published var subError: ErrorType? = nil
    
    @Published var imageUrl: URL?
    @Published var subToastText: String = ""
    @Published var subToastTextColor: Color = .black
    
    @Published var showStoryInComments: Bool = false
    
    lazy var imageCacheManager = UltimatePostViewModel.ImageCache.instance
    
    lazy var networkManager: NetworkManager = NetworkManager.instance
    lazy var commentsCacheManager: CommentsCache = CommentsCache.instance
    
    init(withStory story: Story) {
        self.story = story
    }
    
    func getImageUrl(fromUrl url: String?) async -> URL? {
        if let url {
            return await networkManager.getImage(fromUrl: url)
        }
        return nil
    }
}
