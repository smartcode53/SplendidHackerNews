//
//  ContentViewExtension.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/1/22.
//

import Foundation
import SwiftUI

extension ContentView  {
    
    var posts: some View {
        LazyVStack {
            ForEach(vm.stories, id: \.self.id) { story in
                PostListView(vm: vm, storyObject: story, title: story.title, url: story.url ?? "google.com", author: story.author, points: story.points, numComments: story.numComments, id: story.id, storyDate: story.storyConvertedDate)
            }
            
        }
        .fullScreenCover(item: $vm.selectedStory) { story in
            if let storyUrl = story.url {
                SafariView(vm: vm, url: storyUrl)
            }
            
        }
    }
    
}
