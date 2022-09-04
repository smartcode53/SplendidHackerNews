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
            if let stories = vm.stories {
                ForEach(stories, id: \.self.id) { story in
                    PostListView(vm: vm, storyObject: story, title: story.title, url: story.url, author: story.author, points: story.points, numComments: story.numComments, id: story.id, storyDate: story.createdAtI)
                        .shadow(radius: 2)
                }
            } else {
                ProgressView()
            }
        }
        .fullScreenCover(item: $vm.selectedStory) { story in
            if let storyUrl = story.url {
                SafariView(vm: vm, url: storyUrl)
            }
            
        }
    }
    
}
