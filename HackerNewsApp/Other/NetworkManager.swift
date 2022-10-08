//
//  AltNetworkManager.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/3/22.
//

import Foundation
import SwiftUI
import OpenGraph

class NetworkManager {
    
    static let instance = NetworkManager()
    let cacheManager: StoryFeedViewModel.StoriesCache = StoryFeedViewModel.StoriesCache.instance
    
    // Function to get the array of post IDs and convert it into a dictionary.
    func getStoryIds(ofType type: StoryType) async -> [StoryWrapper]? {
        
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
        
        guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/\(urlStoryType).json") else { return nil }
        
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let safeData = try? JSONDecoder().decode([Int].self, from: data) {
                var wrapperArray: [StoryWrapper] = []
                for (index, id) in safeData.enumerated() {
                    let wrapper = StoryWrapper(index: index, id: id)
                    wrapperArray.append(wrapper)
                }
                return wrapperArray
            }
        } catch let error {
            print(error)
        }
        
        return nil
    }
    
    // Function to fetch stories from the dictionary of post IDs
    func getStories(using wrapperArray: [StoryWrapper]) async -> [StoryWrapper]?  {
        
        do {
            let stories = try await withThrowingTaskGroup(of: StoryWrapper?.self, body: { group in
                
                var storyArray: [StoryWrapper] = []
                
                for wrapper in wrapperArray {
                    group.addTask {
                        
                        if let cachedStory = self.cacheManager.getFromCache(withKey: String(wrapper.id)) {
                            var editedWrapper = wrapper
                            editedWrapper.story = cachedStory
                            return editedWrapper
                        }
                        
                        guard let story = await self.fetchSingleStory(withId: wrapper.id) else { return nil }
                        let newWrapper = StoryWrapper(index: wrapper.index, id: wrapper.id, story: story)
                        self.cacheManager.saveToCache(story, withKey: String(newWrapper.id))
                        return newWrapper
                    }
                }
                
                for try await result in group {
                    if let result {
                        storyArray.append(result)
                    }
                }
                
                storyArray.sort { wrapper1, wrapper2 in
                    wrapper1.index < wrapper2.index
                }
                
                return storyArray
                
            })
            
            return stories
            
        } catch let error {
            print("Error in task group: \(error)")
            return nil
        }
        
    }
    
    // Sub-function of the getStories function to help fetch a single story using its ID.
    func fetchSingleStory(withId id: Int) async -> Story? {
        guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(id).json") else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let safeStory = try? JSONDecoder().decode(Story.self, from: data)
            return safeStory
        } catch let error {
            print("There was an error fetching stories from the server: \(error)")
            return nil
        }
    }
    
    // Function to fetch a single image associated with a story.
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
    
    // Function to convert non-HTTPS URLs to HTTPS
    func getSecureUrlString(url: String) -> String {
        let atsSecureUrl = url.contains("https") ? url : url.replacingOccurrences(of: "http", with: "https", range: url.startIndex..<url.index(url.startIndex, offsetBy: 6))
        return atsSecureUrl
    }
    
    // Function to fetch comments associated with a single story
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
    
    // Functin to de-optionalize a URL
    func safelyLoadUrl(url: String) -> URL {
        let atsSecureUrlString = getSecureUrlString(url: url)
        if let safeUrl = URL(string: atsSecureUrlString) {
            return safeUrl
        } else {
            return URL(string: "")!
        }
    }
}
