//
//  Story.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/1/22.
//

import Foundation

struct Story: Identifiable, Codable {
    
    // MARK: Property Definitions
    
    let createdAt: String
    let title: String
    var url: String?
    let author: String
    let points: Int
    let numComments: Int
    let objectID: String
    let createdAtI: Int
    
    // MARK: Computed Properties
    
    var id: String {
        return objectID
    }
    var storyConvertedDate: String {
        Date.unixToRegular(createdAtI)
    }
    
    
    // MARK: Keymapping for the 'Story' Model
    
    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case title
        case url
        case author
        case points
        case numComments = "num_comments"
        case objectID
        case createdAtI = "created_at_i"
    }
    
    
    // MARK: Decoder initializer
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.createdAt = try container.decode(String.self, forKey: .createdAt)
        self.title = try container.decode(String.self, forKey: .title)
        self.url = try container.decode(String?.self, forKey: .url)
        self.author = try container.decode(String.self, forKey: .author)
        self.points = try container.decode(Int.self, forKey: .points)
        self.numComments = try container.decode(Int.self, forKey: .numComments)
        self.objectID = try container.decode(String.self, forKey: .objectID)
        self.createdAtI = try container.decode(Int.self, forKey: .createdAtI)
    }

}
