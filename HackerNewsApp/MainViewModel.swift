//
//  MainViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import Foundation
import SwiftUI
import SwiftSoup

enum StoryType: String {
    case topstories, newstories, beststories
}


class MainViewModel: ObservableObject {
    @Published var stories = [Story]()
    @Published var isLoadingPosts = false
    @Published var isLoadingComments = false
    @Published var showStoryInPosts = false
    @Published var showStoryInComments = false
    
    @Published var selectedStory: Story? = nil
    
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
        guard let url = URL(string: "https://hn.algolia.com/api/v1/items/\(postID)") else { return [] }
        
        DispatchQueue.main.async { [weak self] in
            self?.isLoadingComments = true
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        do {
            let safeData = try JSONDecoder().decode(Item.self, from: data)
            DispatchQueue.main.async { [weak self] in
                self?.isLoadingComments = false
            }
            
            return safeData.children
        } catch let error {
            print("Decoding error in getComments: \(error)")
        }
        
        isLoadingComments = false
        return []
    }
    
    func getUrlDomain(for url: String) -> String? {
        let generatedUrl = URL(string: url)
        return generatedUrl?.host ?? nil
    }
    
    func returnSafeUrl(url: String) -> URL {
        if let safeUrl = URL(string: url) {
            return safeUrl
        } else {
            return URL(string: "")!
        }
    }
    
    func parseText(text: String) -> String {
        do {
            let document = try SwiftSoup.parse(text)
            return try document.text(trimAndNormaliseWhitespace: true)
        } catch let error {
            print(error)
        }
        
        return ""
    }
}

