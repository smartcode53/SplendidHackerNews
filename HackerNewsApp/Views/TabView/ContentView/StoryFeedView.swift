//
//  ContentView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import SwiftUI

struct StoryFeedView: View {
    
    // MARK: ContentView Properties
    @StateObject var vm = ContentViewModel()
    @State var selectedStory: Story? = nil
    @Namespace var namespace
    @State var showComments: Bool = false
    
    
    // MARK: ContentView Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundColor")
                scrollView
            }
        }
        .accentColor(.primary)
    }
}

extension StoryFeedView  {
    
    var stories: some View {
        LazyVStack {
            if !vm.storiesToDisplay.isEmpty {
                ForEach(vm.storiesToDisplay) { wrapper in
                    if let story = wrapper.story {
                        PostView(withStory: story, selectedStory: $selectedStory)
                                .task {
                                    
                                    guard let lastStoryWrapperIndex = vm.storiesToDisplay.last?.index else { return }
                                    
                                    if wrapper.index == lastStoryWrapperIndex {
                                        print("Reached the last story in the array. Now loading infinitely")
                                        await vm.altLoadInfinitely()
                                    }
                                }
                    }
                }
            } else {
                ProgressView()
            }
            
            if vm.isLoading {
                ProgressView()
                    .padding()
            }
        }
        .task {
            await vm.altLoadStoriesTheFirstTime()
        }
        .fullScreenCover(item: $selectedStory) { story in
            if let storyUrl = story.url {
                SafariView(vm: vm, url: storyUrl)
            }
        }
    }
    
    var scrollView: some View {
        ScrollView {
            // MARK: View Foreground
            VStack(spacing: 0) {
                
                Rectangle()
                    .fill(.primary)
                    .frame(height: 2)
                
                // MARK: List of stories
                
                stories
                    .padding(.top)
                
                
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
    
    var bookmarkConfirmationView: some View {
        VStack {
            Image(systemName: "checkmark.seal")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding()
        .padding()
        .background(Material.regularMaterial)
        .cornerRadius(12)
    }
    
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        StoryFeedView()
    }
}
