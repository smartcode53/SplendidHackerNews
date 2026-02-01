//
//  AltNetworkManager.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/3/22.
//

import Foundation
import SwiftUI
import OpenGraph

final class NetworkManager: @unchecked Sendable {
    
    static let instance = NetworkManager()
    
    // Sub-function to help fetch a single story using its ID.
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
