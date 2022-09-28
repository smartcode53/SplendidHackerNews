//
//  ContentView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import SwiftUI

struct ContentView: View {
    
    // MARK: ContentView Properties
    @StateObject var vm = ContentViewModel()
    @State var selectedStory: Story? = nil
    @State var contentType: String = "Top Stories"
    @Namespace var namespace
    @State var showComments: Bool = false
    
    
    // MARK: ContentView Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundColor")
                
                ScrollView {
                    // MARK: View Foreground
                    VStack(spacing: 0) {
                        
                        Rectangle()
                            .fill(.primary)
                            .frame(height: 2)
                        
                        // MARK: List of stories
                        
                        newPosts
                            .padding(.top, vm.storyType == .askstories || vm.storyType == .showstories ?  0 : 20)
                        
                        
                    }
                    .navigationTitle(Text(vm.storyType.rawValue))
                    .navigationBarTitleDisplayMode(.automatic)
                    .toolbarBackground(Color("CardColor"), for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Menu("Switch Feed") {
                                ForEach(StoryType.allCases, id: \.self) { type in
                                    Button(type.rawValue) {
                                        vm.storyType = type
                                    }
                                }
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
        }
        .accentColor(.primary)
    }
}

extension ContentView  {
    
    // MARK: Story array
    var newPosts: some View {
        LazyVStack {
            if !vm.topStories.isEmpty {
                ForEach(Array(vm.topStories.enumerated()), id: \.element.id) { index, story in
                    PostView(withStory: story, selectedStory: $selectedStory)
                        .onAppear {
                            print("current index: \(index), stories count: \(vm.topStories.count)")
                            if index == vm.topStories.count - 1 {
                                vm.loadInfinitely()
                            }
                        }
                    
                    if vm.isLoading {
                        ProgressView()
                    }
                }
//                .id(UUID())
            } else {
                ProgressView()
            }
        }
        .task {
            await vm.loadStoriesTheFirstTime()
        }
        .fullScreenCover(item: $selectedStory) { story in
            if let storyUrl = story.url {
                SafariView(vm: vm, url: storyUrl)
            }
        }
    }
    
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
