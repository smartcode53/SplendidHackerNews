//
//  HNStory.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/8/22.
//

import Foundation

/*
 "by": "dhouston",
 "descendants": 71,
 "id": 8863,
 "score": 104,
 "time": 1175714200,
 "title": "My YC app: Dropbox - Throw away your USB drive",
 "type": "story",
 "url": "http://www.getdropbox.com/u/2/screencast.html"
}
 
 */

struct Story: Identifiable, Codable, Equatable, Hashable {
    let by: String
    var descendants: Int?
    let id: Int
    var score: Int
    let time: Int
    let title: String
    let type: String
    let url: String?
}

