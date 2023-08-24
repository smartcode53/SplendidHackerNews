//
//  CommentsButtonProtocol.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/24/22.
//

import Foundation
import SwiftUI

protocol CommentsButtonProtocol: ObservableObject {
    
    var story: Story? { get set }
    var comments: Item? {get set}
    var subError: ErrorType? {get set}
    
    var subToastText: String {get set}
    var subToastTextColor: Color {get set}
    
    var showStoryInComments: Bool { get set }
    
    var networkManager: NetworkManager { get }
    var commentsCacheManager: CommentsCache { get }
    
    func loadComments(withId id: Int, completion: @escaping (ErrorHandler?) -> Void)
    
    func getCommentAndPointCounts(forPostWithId id: Int) async -> (Int?, Int)?
}

extension CommentsButtonProtocol {
    
    func loadComments(withId id: Int, completion: @escaping (ErrorHandler?) -> Void) {
        if let cachedItem = commentsCacheManager.getFromCache(withKey: id) {
            comments = cachedItem
        } else {
            Task {
                let result = await networkManager.getComments(forId: id)
                
                await MainActor.run { [weak self] in
                    if let safeResult = result {
                        self?.comments = safeResult
                        commentsCacheManager.saveToCache(safeResult, withKey: id)
                    } else {
                        completion(.commentLoadError)
                    }
                }
                
                await MainActor.run { [weak self] in
                    self?.comments = result
                }
                
                if let safeResult = result {
                    commentsCacheManager.saveToCache(safeResult, withKey: id)
                }
            }
        }
    }
    
    func getCommentAndPointCounts(forPostWithId id: Int) async -> (Int?, Int)? {
        let story = await networkManager.fetchSingleStory(withId: id)
        if let story {
            return (story.descendants, story.score)
        }
        return nil
    }
}
