//
//  ContentView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import SwiftUI

struct ContentView: View {
    
    // MARK: ContentView Properties
    @Binding var path: [AppRoute]
    @StateObject var vm = ContentViewModel()
    @Namespace var namespace
    @State var showComments: Bool = false
    
    
    // MARK: ContentView Body
    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea()
            
            scrollView
        }
        .navigationTitle("\(vm.storyType.rawValue)")
        .navigationBarTitleDisplayMode(.automatic)
        .task {
            await vm.loadInitial()
        }
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
        EmptyView()
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
        List {
            if !vm.stories.isEmpty {
                ForEach(Array(vm.stories.enumerated()), id: \.element.id) { index, story in
                        PostView(withStory: story, index: index + 1, isRead: vm.isRead(story.id), path: $path)
                            .environmentObject(vm)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .task {
                            await vm.loadMoreIfNeeded(currentID: story.id)
                        }
                }
            } else if vm.isLoading || vm.isRefreshing {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            
            if vm.isLoading && !vm.stories.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu("Switch Feed") {
                    ForEach(StoryType.allCases, id: \.self) { type in
                        Button(type.rawValue) {
                            vm.storyType = type
                        }
                    }
                    
                    Divider()
                    
                    Toggle("Hide Read", isOn: $vm.hideRead)
                }
                .tint(.accentColor)
            }
        }
        .refreshable {
            await vm.refresh()
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
        ContentView(path: .constant([]))
    }
}
