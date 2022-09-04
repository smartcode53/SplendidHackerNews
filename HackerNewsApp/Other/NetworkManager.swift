//
//  NetworkManager.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/4/22.
//

import Foundation


class NetworkManager {
    
    static let instance = NetworkManager()
    
    private init() {}
    
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
    
}
