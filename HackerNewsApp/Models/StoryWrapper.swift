//
//  StoryWrapper.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/6/22.
//

import Foundation
import SwiftUI

struct StoryWrapper: Identifiable, Equatable {
    let index: Int
    let id: Int
    var story: Story?
    var isLoadedFromCache: Bool = false
}
