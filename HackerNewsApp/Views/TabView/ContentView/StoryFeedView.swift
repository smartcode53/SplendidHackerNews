//
//  ContentView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import SwiftUI

struct StoryFeedView: View {
    
    // MARK: ContentView Properties
    @StateObject var vm = StoryFeedViewModel()
    @State var selectedStory: Story? = nil
    @Namespace var namespace
    @State private var functionHasRan = false
    
    
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
                                        await vm.loadInfinitely()
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
            await vm.loadStoriesTheFirstTime()
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
                
                // MARK: ProgressView indicator shown upon pulling down on the ScrollView
                if vm.hasAskedToReload {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .transition(.move(edge: .bottom))
                } else {
                    // MARK: GeometryReader for custom Pull-To-Refresh button
                    GeometryReader { proxy in
                        EmptyView()
                            .onChange(of: proxy.frame(in: .named("scrollView")).minY) { newPosition in
                                if newPosition > 115.0 && !functionHasRan {
                                    functionHasRan = true
                                    print("Position is equal to than 115")
                                    withAnimation(.spring()) {
                                        vm.hasAskedToReload = true
                                    }

                                    vm.refreshStories()
                                    
                                }
                                
                                if newPosition < 20 {
                                    functionHasRan = false
                                }
                            }
                            .frame(height: 10)
                            .frame(maxWidth: .infinity)
                    }

                }
                            
                
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
        .coordinateSpace(name: "scrollView")
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
