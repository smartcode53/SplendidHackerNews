//
//  ContentView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject var vm = ContentViewModel()
    @State var selectedStory: Story? = nil
    
    var body: some View {
        
        NavigationStack {
            
            ZStack {
                
                Color("BackgroundColor")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    ZStack {
                        HStack {
                            
                            Text("Stories")
                                .font(.largeTitle.weight(.bold))
                                .underline(true, pattern: .solid, color: .orange)
                            
                            Spacer()
                            
                            Menu(vm.storyType.rawValue) {
                                Button(StoryType.topstories.rawValue) {
                                    vm.storyType = .topstories
                                }
                                
                                Button(StoryType.newstories.rawValue) {
                                    vm.storyType = .newstories
                                }
                                
                                Button(StoryType.beststories.rawValue) {
                                    vm.storyType = .beststories
                                }
                                
                                Button(StoryType.askstories.rawValue) {
                                    vm.storyType = .askstories
                                }
                                
                                Button(StoryType.showstories.rawValue) {
                                    vm.storyType = .showstories
                                }
                            }
                        }
                        .padding()
                    }
                    .background(Color("CardColor"))
                    
                    Rectangle()
                        .fill(.primary)
                        .frame(height: 2)
                    
                    ScrollView {
                        
                        newPosts
                            .padding(.top)
                        
                    }
                    .frame(maxWidth: .infinity)
                    .toolbar(.hidden)
                }
            }
        }
    }
}

extension ContentView  {
    
    var newPosts: some View {
        LazyVStack {
            if !vm.topStories.isEmpty {
                ForEach(Array(vm.topStories.enumerated()), id: \.element.id) { index, story in
                    PostView(story: story, selectedStory: $selectedStory)
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
