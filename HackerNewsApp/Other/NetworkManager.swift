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
    
    
    func getStories() async -> [Story]? {
        guard let url = URL(string: "https://hn.algolia.com/api/v1/search?tags=front_page") else { return nil}
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            do {
                let response = try JSONDecoder().decode(Results.self, from: data)
                return response.hits
            } catch let error {
                print("There was an error decoding the front-page stories downloaded from the API. Here's the error description: \(error)")
            }
        } catch let error {
            print("There was an error fetching the front-page stories from the server. Here's the error description: \(error)")
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
        let atsSecureUrl = url.contains("https") ? url : url.replacingOccurrences(of: "http", with: "https", range: url.startIndex..<url.index(url.startIndex, offsetBy: 6))
        guard let safeUrl = URL(string: atsSecureUrl) else { return nil }
        
        
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
    
    func getComments(forId id: String) async -> Item? {
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
        if let safeUrl = URL(string: url) {
            return safeUrl
        } else {
            return URL(string: "")!
        }
    }

}
