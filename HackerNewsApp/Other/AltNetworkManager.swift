//
//  AltNetworkManager.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/3/22.
//

import Foundation
import SwiftUI

class AltNetworkManager {
    
    static let instance = AltNetworkManager()
    
    // MARK: Function to get the array of post IDs and convert it into a dictionary.
    func getStoryIds(ofType type: StoryType) async -> [Int: Int]? {
        
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
                var idDictionary: [Int: Int] = [:]
                for (index, id) in safeData.enumerated() {
                    idDictionary[index + 1] = id
                }
                return idDictionary
            }
        } catch let error {
            print(error)
        }
        
        return nil
    }
    
    func getStories(using idDictionary: [Int: Int]) async -> [Story]?  {
        
        do {
            let stories = try await withThrowingTaskGroup(of: (Int, Story?).self, body: { group in
                
                var storyDict: [Int: Story] = [:]
                var storyArray: [Story] = []
                
                for (key, value) in idDictionary {
                    group.addTask {
                        let story = await self.fetchSingleStory(withId: value)
                        return (key, story)
                    }
                }
                
                for try await (key, story) in group {
                    if let story {
                        storyDict[key] = story
                    }
                }
                
                let sortedKeys = Array(storyDict.keys).sorted { item1, item2 in
                    item1 < item2
                }
                
                for key in sortedKeys {
                    if let story = storyDict[key] {
                        storyArray.append(story)
                    }
                }
                
                return storyArray
                
            })
            
            return stories
            
        } catch let error {
            print("Error in task group: \(error)")
            return nil
        }
        
    }
    
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
}
