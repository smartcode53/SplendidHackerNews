//
//  ContentView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import SwiftUI

struct StoryFeedView: View {
    
    // MARK: ContentView Properties
    @Environment(\.scenePhase) var scenePhase
    @StateObject var networkChecker = NetworkChecker()
    @StateObject var vm = StoryFeedViewModel()
    @State var selectedStory: Story? = nil
    @Namespace var namespace
    @State private var functionHasRan = false
    @State private var toastText = "All Good!"
    @State private var showToast = false {
        didSet {
            if showToast {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation(.spring()) {
                        showToast = false
                    }
                }
            }
        }
    }
    
    
    // MARK: ContentView Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundColor")
                
                scrollView
            }
        }
        .accentColor(.primary)
        .overlay {
            if showToast {
                ToastView(text: toastText)
                    .zIndex(2)
                    .transition(.asymmetric(insertion: .move(edge: .top), removal: .move(edge: .top)))
            }
        }
    }
}

extension StoryFeedView  {
    
    var stories: some View {
        LazyVStack {
            if !vm.storiesDict[vm.storyType, default: []].isEmpty {
                ForEach(vm.storiesDict[vm.storyType] ?? []) { wrapper in
                    if let story = wrapper.story {
                        PostView(withWrapper: wrapper, story: story)
                                .task {
                                    
                                    guard let lastStoryWrapperIndex = vm.storiesDict[vm.storyType, default: []].last?.index else { return }
                                    
                                    if wrapper.index == lastStoryWrapperIndex {
                                        print("Reached the last story in the array. Now loading infinitely")
                                        await vm.loadInfinitely()
                                    }
                                }
                                .onTapGesture {
                                    selectedStory = story
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
        .onChange(of: scenePhase, perform: { phase in
            if phase == .inactive {
                vm.saveStoriesToDisk()
            }
        })
        .task {
            if networkChecker.isConnected {
                print("YES INTERNET!!")
                Task {
                    await vm.loadStoriesTheFirstTime()
                }
            } else {
                print("NO INTERNET!!!")
                vm.storiesDict = vm.getStoriesFromDisk()
            }
        }
//        .task {
//            await vm.loadStoriesTheFirstTime()
//        }
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
                
                Button {
                    toastText = "Button Pressed"
                    withAnimation(.spring()) {
                        showToast = true
                    }
                } label: {
                    Text("Press here for toast")
                        .padding()
                        .background(.blue)
                        .cornerRadius(12)
                        .padding()
                }
                
                // MARK: ProgressView indicator shown upon pulling down on the ScrollView
                if vm.hasAskedToReload {
                    Rectangle()
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
