//
//  Item.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/1/22.
//

import Foundation

struct Item: Identifiable, Codable {
    
    // MARK: Property Definitions
    
    let id: Int
    let createdAtI: Int
    let type: String
    let author: String?
    let title: String
    var url: String?
    let points: Int
    let children: [Comment]
    
    // MARK: Computed Properties
    
    var storyDate: String {
        Date.unixToRegular(createdAtI)
    }
    
    
    // MARK: Keymapping for the 'Item' model
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAtI = "created_at_i"
        case type
        case author
        case title
        case url
        case points
        case children
    }
    
    // MARK: Decoder Initializer
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(Int.self, forKey: .id)
        self.createdAtI = try container.decode(Int.self, forKey: .createdAtI)
        self.type = try container.decode(String.self, forKey: .type)
        self.author = try container.decode(String?.self, forKey: .author)
        self.title = try container.decode(String.self, forKey: .title)
        self.url = try container.decode(String?.self, forKey: .url)
        self.points = try container.decode(Int.self, forKey: .points)
        self.children = try container.decode([Comment].self, forKey: .children)
    }
}
