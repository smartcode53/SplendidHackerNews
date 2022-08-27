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


class MainViewModel: ObservableObject {
    @Published var stories = [Story]()
    @Published var isLoading = false
    
    func getStories() async {
        guard let url = URL(string: "https://hn.algolia.com/api/v1/search?tags=front_page") else { return }
        
        print("URL created successfully")
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            print("Data recieved back from the server successfully")
            
//            let decoder = JSONDecoder()
//            decoder.keyDecodingStrategy = .convertFromSnakeCase
//
            print("Decoder configured successfully")
            
            do {
                let safeData = try JSONDecoder().decode(Results.self, from: data)
                DispatchQueue.main.async { [weak self] in
                    self?.stories = safeData.hits
                }
                
            } catch let error {
                print("Decoding error: \(error)")
            }
        } catch let error {
            print("Error: was unable to fetch data from the server: \(error.localizedDescription)")
        }
    }
    
    func getComments(for postID: String) async throws -> [Comment] {
        guard let url = URL(string: "https://hn.algolia.com/api/v1/search?tags=comment,story_\(postID)") else { return [] }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        do {
            let safeData = try JSONDecoder().decode(CommentResults.self, from: data)
            return safeData.hits
        } catch let error {
            print("Decoding error: \(error)")
        }
        return []
    }
}

