//
//  NetworkManager.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/4/22.
//

import Foundation
import OpenGraph


class NetworkManager {
    
    static let instance = NetworkManager()
    
    func getStoryIds(ofType type: StoryType) async -> [Int]? {
        
        let urlStoryType: String
        
        switch type {
        case .askstories:
            urlStoryType = "askstories"
        case .beststories:
            urlStoryType = "beststories"
        case .newstories:
            urlStoryType = "newstories"
        case .showstories:
            urlStoryType = "showstories"
        case .topstories:
            urlStoryType = "topstories"
        }
        
        guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/\(urlStoryType).json") else {return nil}
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let safeData = try? JSONDecoder().decode([Int].self, from: data) {
                return safeData
            }
        } catch let error {
            print(error)
        }
        
        return nil
    }
    
    func downloadStories(using idArray: [Int]) async -> [Story]? {
        
        do {
            let stories = try await withThrowingTaskGroup(of: Story?.self, body: { group in
                var storyArray = [Story]()
                
                for id in idArray {
                    group.addTask {
                        return await self.fetchStory(with: id)
                    }
                }
                
                for try await story in group {
                    if let story {
                        storyArray.append(story)
                    }
                }
                
                return storyArray
            })
            
            return stories
        } catch let error {
            print("\(error)")
        }
        
        return nil
    }
    
    func fetchStory(with id: Int) async -> Story? {
        guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(id).json") else {return nil}
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let safeStory = try? JSONDecoder().decode(Story.self, from: data)
            return safeStory
        } catch let error {
            print("There was an error fetching stories from the server: \(error)")
        }
        return nil
    }
    
    func getUrlDomain(forUrl url: String) -> String? {
        if let generatedUrl = URL(string: url) {
            return generatedUrl.host
        }
        return nil
    }
    
    func getImage(fromUrl url: String) async -> URL? {
        guard let safeUrl = URL(string: getSecureUrlString(url: url)) else { return nil }
        
        do {
            let og = try await OpenGraph.fetch(url: safeUrl)
            guard let ogUrl = og[.image] else { return nil }
            if let finalUrl = URL(string: ogUrl) {
                return finalUrl
            }
            
        } catch let error {
            print("There was an error fetching the image: \(error)")
        }
        
        return nil
    }
    
    func getSecureUrlString(url: String) -> String {
        let atsSecureUrl = url.contains("https") ? url : url.replacingOccurrences(of: "http", with: "https", range: url.startIndex..<url.index(url.startIndex, offsetBy: 6))
        return atsSecureUrl
    }
    
    func getComments(forId id: Int) async -> Item? {
        guard let url = URL(string: "https://hn.algolia.com/api/v1/items/\(id)") else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            do {
                let safeData = try JSONDecoder().decode(Item.self, from: data)
                return safeData
            } catch let error {
                print("Decoding error in getComments: \(error)")
            }
        } catch let error {
            print("There was an error fetching comment data from the server. The complete description of the error is as follows: \(error)")
        }
        
        return nil
    }
    
    func safelyLoadUrl(url: String) -> URL {
        let atsSecureUrlString = getSecureUrlString(url: url)
        if let safeUrl = URL(string: atsSecureUrlString) {
            return safeUrl
        } else {
            return URL(string: "")!
        }
    }
    
}

