//
//  AppNavbarView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/15/22.
//

import SwiftUI

struct AppNavbarView: View {
    
    // MARK: ContentView Properties
    @Environment(\.scenePhase) var scenePhase
    @StateObject var networkChecker = NetworkChecker()
    @StateObject var vm = StoryFeedViewModel()
    @State var selectedStory: Story? = nil
    @Namespace var namespace
    
    var body: some View {
        CustomNavView {
            ZStack {
                LinearGradient(colors: [.orange, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                    .opacity(0.5)
                
                if vm.showNoInternetScreen {
                    NoInternetView(vm: vm)
                } else {
                    scrollView
                }
                
                
                
            }
            .customNavigationTitle("Top Stories")
            .customNavigationBarBackButtonHidden(true)
        }
        .overlay {
            if vm.appError != nil {
                ToastView(text: vm.toastText, textColor: vm.toastTextColor)
                    .zIndex(2)
                    .transition(.asymmetric(insertion: .move(edge: .top), removal: .move(edge: .top)))
            }
        }
    }
}


extension AppNavbarView  {
    
    var stories: some View {
        LazyVStack(spacing: 0) {
            if !vm.storiesDict[vm.storyType, default: []].isEmpty {
                ForEach(vm.storiesDict[vm.storyType] ?? []) { wrapper in
                    if let story = wrapper.story {
                        
                        PostView(withWrapper: wrapper, story: story, selectedStory: $selectedStory)
                                .task {

                                    guard let lastStoryWrapperIndex = vm.storiesDict[vm.storyType, default: []].last?.index else { return }

                                    if wrapper.index == lastStoryWrapperIndex {
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
        .onChange(of: scenePhase, perform: { phase in
            if phase == .inactive {
                vm.saveStoriesToDisk()
            }
        })
        .task {
            if networkChecker.isConnected {
                Task {
                    await vm.loadStoriesTheFirstTime()
                }
            } else {
                vm.storiesDict = vm.getStoriesFromDisk()
                
                if vm.storiesDict.isEmpty {
                    vm.showNoInternetScreen = true
                } else {
                    
                    let error = ErrorHandler.noInternet
                    vm.toastText = error.localizedDescription
                    vm.toastTextColor = .red.opacity(0.8)
                    vm.appError = ErrorType(error: .noInternet)
                }
                
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
                
                StorySelectionView(selectedStoryType: $vm.storyType)
                
                
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
                                if newPosition > 190 && !vm.functionHasRan {
                                    vm.functionHasRan = true
                                    withAnimation(.spring()) {
                                        vm.hasAskedToReload = true
                                    }

                                    vm.refreshStories()
                                    
                                }
                                
                                if newPosition < 100 {
                                    vm.functionHasRan = false
                                }
                            }
                            .frame(height: 10)
                            .frame(maxWidth: .infinity)
                    }

                }
                            
                
                // MARK: List of stories
                
                stories
                
                
            }
            .navigationTitle(Text(vm.storyType.rawValue))
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTitleDisplayMode(.automatic)
            .toolbarBackground(Color("NavigationBarColor"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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


struct AppNavbarView_Previews: PreviewProvider {
    static var previews: some View {
        AppNavbarView()
    }
}
