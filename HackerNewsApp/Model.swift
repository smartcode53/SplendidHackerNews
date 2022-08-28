//
//  Model.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import Foundation

struct Results: Codable {
    let hits: [Story]
    let page: Int
    let nbPages: Int
    let hitsPerPage: Int
}

struct Story: Identifiable, Codable {
    let createdAt: String
    let title: String
    let url: String
    let author: String
    let points: Int
    let numComments: Int
//    var createdAtI: Int
    var id: String {
        return objectID
    }
    var storyConvertedDate: String {
        Date.unixToRegular(createdAtI)
    }
    let objectID: String
    let createdAtI: Int
    
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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.createdAt = try container.decode(String.self, forKey: .createdAt)
        self.title = try container.decode(String.self, forKey: .title)
        self.url = try container.decode(String.self, forKey: .url)
        self.author = try container.decode(String.self, forKey: .author)
        self.points = try container.decode(Int.self, forKey: .points)
        self.numComments = try container.decode(Int.self, forKey: .numComments)
        self.objectID = try container.decode(String.self, forKey: .objectID)
        self.createdAtI = try container.decode(Int.self, forKey: .createdAtI)
    }

}

//struct CommentResults: Codable {
//    let hits: [Comment]
//    let page: Int
//    let nbPages: Int
//    let hitsPerPage: Int
//}

//struct Comment: Identifiable, Codable {
//    let author: String
//    let commentText: String
//    let parentId: Int
//    let createdAtI: Int
//    var id: String {
//        objectID
//    }
//    var commentConvertedDate: String {
//        Date.unixToRegular(createdAtI)
//    }
//    let objectID: String
//
//    enum CodingKeys: String, CodingKey {
//        case author
//        case commentText = "comment_text"
//        case parentId = "parent_id"
//        case createdAtI = "created_at_i"
//        case objectID
//    }
//
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        self.author = try container.decode(String.self, forKey: .author)
//        self.commentText = try container.decode(String.self, forKey: .commentText)
//        self.parentId = try container.decode(Int.self, forKey: .parentId)
//        self.createdAtI = try container.decode(Int.self, forKey: .createdAtI)
//        self.objectID = try container.decode(String.self, forKey: .objectID)
//    }
//}

struct Item: Identifiable, Codable {
    let id: Int
    let createdAtI: Int
    let type: String
    let author: String
    let title: String
    let url: String
    let points: Int
    let children: [Comment]
    
    var storyDate: String {
        Date.unixToRegular(createdAtI)
    }
    
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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(Int.self, forKey: .id)
        self.createdAtI = try container.decode(Int.self, forKey: .createdAtI)
        self.type = try container.decode(String.self, forKey: .type)
        self.author = try container.decode(String.self, forKey: .author)
        self.title = try container.decode(String.self, forKey: .title)
        self.url = try container.decode(String.self, forKey: .url)
        self.points = try container.decode(Int.self, forKey: .points)
        self.children = try container.decode([Comment].self, forKey: .children)
    }
}

struct Comment: Identifiable, Codable {
    let id: Int
    let createdAtI: Int
    let type: String
    let author: String
    let text: String
    let parentId: Int
    let storyId: Int
    let children: [Comment]
    
    var commentDate: String {
        Date.unixToRegular(createdAtI)
    }
    
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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(Int.self, forKey: .id)
        self.createdAtI = try container.decode(Int.self, forKey: .createdAtI)
        self.type = try container.decode(String.self, forKey: .type)
        self.author = try container.decode(String.self, forKey: .author)
        self.text = try container.decode(String.self, forKey: .text)
        self.parentId = try container.decode(Int.self, forKey: .parentId)
        self.storyId = try container.decode(Int.self, forKey: .storyId)
        self.children = try container.decode([Comment].self, forKey: .children)
    }
}
