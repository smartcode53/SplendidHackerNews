//
//  Comment.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/1/22.
//

import Foundation

struct Comment: Identifiable, Codable {
    
    //MARK: Property Definitions
    
    let id: Int
    let createdAtI: Int
    let type: String
    let author: String?
    let text: String?
    let parentId: Int
    let storyId: Int?
    let children: [Comment]
    
    
    // MARK: Computed Properties
    
    var commentChildren: [Comment]? {
        if children.isEmpty {
            return nil
        } else {
            return children
        }
    }
    
    var commentDate: String {
        Date.unixToRegular(createdAtI)
    }
    
    
    // MARK: Keymmappings for the 'Comments' model
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAtI = "created_at_i"
        case type
        case author
        case text
        case parentId = "parent_id"
        case storyId = "story_id"
        case children
    }
    
    
    // MARK: Decoder Initializer
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(Int.self, forKey: .id)
        self.createdAtI = try container.decode(Int.self, forKey: .createdAtI)
        self.type = try container.decode(String.self, forKey: .type)
        self.author = try container.decode(String?.self, forKey: .author)
        self.text = try container.decode(String?.self, forKey: .text)
        self.parentId = try container.decode(Int.self, forKey: .parentId)
        self.storyId = try container.decode(Int.self, forKey: .storyId)
        self.children = try container.decode([Comment].self, forKey: .children)
    }
}

