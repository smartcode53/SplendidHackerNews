//
//  MainViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import Foundation
import SwiftUI

enum StoryType: String {
    case topstories, newstories, beststories
}


class ContentViewModel: SafariViewLoader {
    
    var networkManager: NetworkManager = NetworkManager.instance
    
    @Published var stories: [Story]? = nil
    @Published var showStoryInPosts = false
    @Published var showStoryInComments = false
    @Published var selectedStory: Story? = nil
    
    func loadStories() {
        Task {
            let results = await networkManager.getStories()
            await MainActor.run { [weak self] in
                self?.stories = results
            }
        }
    }
    
    func returnSafelyLoadedUrl(url: String) -> URL {
        return networkManager.safelyLoadUrl(url: url)
    }
    
        
}

