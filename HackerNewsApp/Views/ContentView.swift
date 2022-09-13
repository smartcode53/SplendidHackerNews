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
    @State var contentType: String = "Top Stories"
    @Namespace var namespace
    
    var body: some View {
        
        NavigationStack {
            
            ZStack {
                
                Color("BackgroundColor")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    ZStack {
                        HStack {
                            
                            Text(vm.storyTypeString)
                                .font(.largeTitle.weight(.bold))
                                .underline(true, pattern: .solid, color: .orange)
                            
                            Spacer()
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color("CardColor"))
                                    .matchedGeometryEffect(id: "feedSwitcher", in: namespace)
                                    .frame(width: 150, height: 40)
                                
                                Text("Switch Feed")
                                    .foregroundColor(.orange)
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            .zIndex(100)
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    vm.showStoryPicker = true
                                }
                            }
                            
//                            Menu(vm.storyType.rawValue) {
//                                Button(StoryType.topstories.rawValue) {
//                                    vm.storyType = .topstories
//                                }
//
//                                Button(StoryType.newstories.rawValue) {
//                                    vm.storyType = .newstories
//                                }
//
//                                Button(StoryType.beststories.rawValue) {
//                                    vm.storyType = .beststories
//                                }
//
//                                Button(StoryType.askstories.rawValue) {
//                                    vm.storyType = .askstories
//                                }
//
//                                Button(StoryType.showstories.rawValue) {
//                                    vm.storyType = .showstories
//                                }
//                            }
                        }
                        .padding()
                        
                        if vm.showStoryPicker {
                            switchController
                        }
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
    
    var switchController: some View {
        ZStack {
            
            Rectangle()
                .fill(Color("CardColor"))
                .ignoresSafeArea()
                .matchedGeometryEffect(id: "feedSwitcher", in: namespace)
            
            VStack(spacing: 20) {
                ForEach(StoryType.stringArray, id: \.self) { storyType in
                    ZStack {
                        
                        if storyType == vm.storyTypeString {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white)
                                .frame(width: 200, height: 50)
                                .matchedGeometryEffect(id: "storySelector", in: namespace)
                                
                        }
                        
                        
                        Text(storyType)
                            .padding()
                            .foregroundColor(.black)
                            .fontWeight(.semibold)
                            .onTapGesture {
                                
                                withAnimation(.easeInOut) {
                                    switch storyType {
                                    case "Top Stories":
                                        vm.storyType = .topstories
                                    case "New Stories":
                                        vm.storyType = .newstories
                                    case "Show HN":
                                        vm.storyType = .showstories
                                    case "Ask HN":
                                        vm.storyType = .askstories
                                    case "Best Stories":
                                        vm.storyType = .beststories
                                    default:
                                        print("Default case ran")
                                        vm.storyType = .topstories
                                    }
                                }
                                
                                withAnimation(.spring()) {
                                    vm.showStoryPicker = false
                                }
                                
                            }
                    }
                    
                }
            }
            .padding()
            .padding(.horizontal)
            .background(.orange.gradient)
            .cornerRadius(12)
            .padding(.vertical)
        }
    }
}
    

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
