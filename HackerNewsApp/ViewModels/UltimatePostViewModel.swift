//
//  UltimatePostViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/22/22.
//

import Foundation
import SwiftUI

class UltimatePostViewModel: ObservableObject, SafariViewLoader, CommentsButtonProtocol {
    
    @Published var story: Story?
    @Published var comments: Item?
    
    @Published var imageUrl: URL?
    @Published var urlDomain: String?
    
    @Published var showStoryInComments = false
    
    lazy var networkManager = NetworkManager.instance
    lazy var commentsCacheManager = CommentsCache.instance
    
    
    init(withStory story: Story) {
        self._story = Published(initialValue: story)
        self.urlDomain = story.url?.urlDomain
    }
    
    func loadImage(fromUrl url: String) {
        Task {
            let resultUrl = await networkManager.getImage(fromUrl: url)
            await MainActor.run { [weak self] in
                self?.imageUrl = resultUrl
            }
        }
    }


}
