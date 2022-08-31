//
//  ContentView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject var vm = MainViewModel()
    //    var stories: [Story] {
    //        [story, story2]
    //    }
    //    @State private var story = Story(by: "skrillex", descendants: 2, id: 23, kids: [], score: 23, time: 1, title: "Some Awesome News on the Internet By the greatest person that is gallant and worthy", type: "Post", url: "URL")
    //
    //    @State private var story2 = Story(by: "mango", descendants: 45, id: 25, kids: [], score: 365, time: 234324534, title: "What you need to know about the upcoming iPhone 14", type: "Post", url: "URL")
    
    var body: some View {
        ZStack {
            NavigationView {
                ScrollView {
                    if !vm.isLoadingPosts {
                        LazyVStack {
                            ForEach(vm.stories, id: \.self.id) { story in
                                PostListView(vm: vm, storyObject: story, title: story.title, url: story.url ?? "google.com", author: story.author, points: story.points, numComments: story.numComments, id: story.id, storyDate: story.storyConvertedDate)
                            }
                            
                        }
                        .fullScreenCover(item: $vm.selectedStory) { story in
                            if let storyUrl = story.url {
                                WebViewWrapper(vm: vm, url: storyUrl)
                            }
                            
                        }
                    } else {
                        ProgressView()
                    }
                }
                .navigationTitle("Stories")
                .frame(maxWidth: .infinity)
                .background(.orange)
                
            }
            .zIndex(0)
            .task {
                await vm.getStories()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
