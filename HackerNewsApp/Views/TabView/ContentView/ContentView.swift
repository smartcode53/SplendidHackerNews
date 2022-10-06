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

extension ContentView  {
    
    // MARK: Story array
//    var newPosts: some View {
//        LazyVStack {
//            if !vm.storiesToDisplay.isEmpty {
//                ForEach(Array(zip(vm.stories.indices, vm.stories)), id: \.0) { index, story in
//                    PostView(withStory: story, selectedStory: $selectedStory, index: index)
////                            .task {
////                                if index == vm.stories.count - 1 {
////                                    await vm.altLoadInfinitely()
////                                }
////                            }
//                }
//            } else {
//                ProgressView()
//            }
//
//            if vm.isLoading {
//                ProgressView()
//                    .padding()
//            }
//        }
//        .task {
//            await vm.altLoadStoriesTheFirstTime()
//        }
//        .fullScreenCover(item: $selectedStory) { story in
//            if let storyUrl = story.url {
//                SafariView(vm: vm, url: storyUrl)
//            }
//        }
//    }
    
    var altNewPosts: some View {
        LazyVStack {
            if !vm.storiesToDisplay.isEmpty {
                ForEach(vm.storiesToDisplay) { wrapper in
                    if let story = wrapper.story {
                        PostView(withStory: story, selectedStory: $selectedStory, index: 0)
                                .task {
                                    guard let lastStoryWrapperIndex = vm.storiesToDisplay.lastIndex(where: { item in
                                        item.story != nil
                                   }) else { return }
                                    
                                    if wrapper == vm.storiesToDisplay[lastStoryWrapperIndex] {
                                        print(true)
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
    
//    var listPosts: some View {
//        List {
//
//            Rectangle()
//                .fill(Color.clear)
//                .frame(maxWidth: .infinity)
//                .frame(height: 2)
//                .listRowInsets(.none)
//                .listRowBackground(Color.clear)
//                .listRowSeparator(.hidden)
//
//            if !vm.storiesToDisplay.isEmpty {
//                ForEach(Array(zip(vm.stories.indices, vm.stories)), id: \.0) { (index, story) in
//                    PostView(withStory: story, selectedStory: $selectedStory, index: index)
////                        .onAppear {
////                            print("current index: \(index), stories count: \(vm.topStories.count)")
////                            if index == vm.topStories.count - 1 {
////                                vm.loadInfinitely()
////                            }
////                        }
//
////                    if vm.isLoading {
////                        ProgressView()
////                    }
//                }
//                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
//                .listRowSeparator(.hidden)
//                .listRowBackground(Color.clear)
//            } else {
//                HStack {
//                    Spacer()
//
//                    ProgressView()
//
//
//                    Spacer()
//                }
//                .listRowBackground(Color.clear)
//                .listRowSeparator(.hidden)
//
//            }
//        }
////        .refreshable {
////            vm.refreshStories()
////        }
//        .listStyle(.plain)
//        .scrollContentBackground(.hidden)
//        .environment(\.defaultMinListRowHeight, 5)
//        .overlay(
//            Rectangle()
//                .fill(.primary)
//                .frame(height: 2)
//            ,
//            alignment: .top
//        )
//        .task {
//            await vm.altLoadStoriesTheFirstTime()
//        }
////        .fullScreenCover(item: $selectedStory) { story in
////            if let storyUrl = story.url {
////                SafariView(vm: vm, url: storyUrl)
////            }
////        }
//        .navigationTitle(Text(vm.storyType.rawValue))
//        .navigationBarTitleDisplayMode(.automatic)
//        .toolbarBackground(Color("CardColor"), for: .navigationBar)
//        .toolbarBackground(.visible, for: .navigationBar)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Menu("Switch Feed") {
//                    ForEach(StoryType.allCases, id: \.self) { type in
//                        Button(type.rawValue) {
//                            vm.storyType = type
//                        }
//                    }
//                }
//                .tint(.orange)
//            }
//        }
//    }
    
    var scrollView: some View {
        ScrollView {
            // MARK: View Foreground
            VStack(spacing: 0) {
                
                Rectangle()
                    .fill(.primary)
                    .frame(height: 2)
                
                // MARK: List of stories
                
                altNewPosts
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
        ContentView()
    }
}
