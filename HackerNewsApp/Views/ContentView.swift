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
    
    
    // MARK: ContentView Body
    var body: some View {
        
        NavigationStack {
            
            ZStack {
                
                // MARK: View Background
                Color("BackgroundColor")
                    .ignoresSafeArea()
                
                // MARK: View Foreground
                VStack(spacing: 0) {
                    
                    // MARK: Masthead
                    ZStack {
                        HStack {
                            
                            Text(vm.storyType.rawValue)
                                .font(.largeTitle.weight(.bold))
                                .underline(true, pattern: .solid, color: .orange)
                            
                            Spacer()
                            
                                
                            Menu("Switch Feed") {
                                ForEach(StoryType.allCases, id: \.self) { type in
                                    Button(type.rawValue) {
                                        vm.storyType = type
                                    }
                                }
                            }
                            .tint(.orange)
                        }
                        .padding()
                    }
                    .background(Color("CardColor"))
                    
                    Rectangle()
                        .fill(.primary)
                        .frame(height: 2)
                    
                    // MARK: List of stories
                    ScrollView {
                        
                        if vm.storyType == .askstories || vm.storyType == .showstories {
                            HStack {
                                
                                Spacer()
                                
                                Button {
                                    vm.showSortSheet = true
                                } label: {
                                    Label("Sort Stories", systemImage: "shippingbox")
                                }
                                .createFilterButton()
                                .sheet(isPresented: $vm.showSortSheet) {
                                    SortOptionsView(vm: vm)
                                        .presentationDetents([.fraction(0.2)])
                                }
                                
                                Button {
                                    
                                } label: {
                                    Label("Ascending", systemImage: "arrow.up")
                                }
                                .createFilterButton()
                                
                                
                                
                            }
                            .padding()
                            .fontWeight(.bold)
                        }
                        
                        newPosts
                            .padding(.top, vm.storyType == .askstories || vm.storyType == .showstories ?  0 : 20)
                        
                    }
                    .frame(maxWidth: .infinity)
                    .toolbar(.hidden)
                }
            }
        }
    }
}

extension ContentView  {
    
    // MARK: Story array
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
    
    // MARK: Optional story type switcher
    var switchController: some View {
        ZStack {
            
            Rectangle()
                .fill(Color("CardColor"))
                .ignoresSafeArea()
                .matchedGeometryEffect(id: "feedSwitcher", in: namespace)
            
            VStack(spacing: 20) {
                ForEach(StoryType.allCases, id: \.self) { storyType in
                    ZStack {
                        
                        if storyType == vm.storyType {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white)
                                .frame(width: 200, height: 50)
                                .matchedGeometryEffect(id: "storySelector", in: namespace)
                                
                        }
                        
                        
                        Text(storyType.rawValue)
                            .padding()
                            .foregroundColor(.black)
                            .fontWeight(.semibold)
                            .onTapGesture {
                                
                                withAnimation(.easeInOut) {
                                    vm.storyType = storyType
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
