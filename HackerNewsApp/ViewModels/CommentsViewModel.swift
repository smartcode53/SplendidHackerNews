//
//  CommentsViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/5/22.
//

import Foundation

class CommentsViewModel: SafariViewLoader {
    
    @Published var showStoryInComments = false
    @Published var item: Item?
    
    let networkManager = NetworkManager.instance
    
    func loadComments(forPost id: String) {
        Task {
            let result = await networkManager.getComments(forId: id)
            await MainActor.run { [weak self] in
                self?.item = result
            }
        }
    }
    
    func getCommentAndPointsCount(forPost id: String) async -> (Int?, Int)? {
        let stories = await networkManager.getStories()
        if let stories {
            for story in stories {
                if story.id == id {
                    return (story.numComments, story.points)
                } else {
                    return nil
                }
            }
        } else {
            return nil
        }
        
        return nil
    }
    
    func returnSafelyLoadedUrl(url: String) -> URL {
        return networkManager.safelyLoadUrl(url: url)
    }
    
}
