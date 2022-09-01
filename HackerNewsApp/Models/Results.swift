//
//  Results.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/1/22.
//

import Foundation

struct Results: Codable {
    let hits: [Story]
    let page: Int
    let nbPages: Int
    let hitsPerPage: Int
}


