//
//  Bookmark.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/25/22.
//

import Foundation
import SwiftUI

struct Bookmark: Identifiable, Codable, Equatable {
    var id: Int {
        date
    }
    var story: Story
    var date = Int(Date.timeIntervalSinceReferenceDate)
}
