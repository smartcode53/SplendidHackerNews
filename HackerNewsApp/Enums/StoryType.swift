//
//  StoryType.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/14/22.
//

import Foundation
import SwiftUI

enum StoryType: String, CaseIterable, Codable {
    case topstories = "Top Stories"
    case newstories = "New Stories"
    case beststories = "Best Stories"
    case askstories = "Ask HN"
    case showstories = "Show HN"
}
