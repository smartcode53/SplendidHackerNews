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
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
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
            if globalSettings.appError != nil {
                ToastView(text: globalSettings.toastText, textColor: globalSettings.toastTextColor)
                    .zIndex(2)
                    .transition(.asymmetric(insertion: .move(edge: .top), removal: .move(edge: .top)))
            }
        }
        .onAppear {
            vm.notificationsManager.requestAuthorization()
        }
        .onChange(of: vm.subError) { error in
            globalSettings.appError = error
        }
        .onChange(of: vm.subToastText) { text in
            globalSettings.toastText = text
        }
        .onChange(of: vm.subToastTextColor) { color in
            globalSettings.toastTextColor = color
        }
    }
}


// View Components
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
                if !vm.storiesLoaded {
                    Task {
                        await vm.loadStoriesTheFirstTime()
                    }
                }
            } else {
                vm.storiesDict = vm.getStoriesFromDisk()
                
                if vm.storiesDict.isEmpty {
                    vm.showNoInternetScreen = true
                } else {
                    
                    let error = ErrorHandler.noInternet
                    globalSettings.toastText = error.localizedDescription
                    globalSettings.toastTextColor = .red.opacity(0.8)
                    globalSettings.appError = ErrorType(error: .noInternet)
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
//                if vm.hasAskedToReload {
//                    ProgressView()
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .transition(.move(edge: .bottom))
//                } else {
//                    // MARK: GeometryReader for custom Pull-To-Refresh button
//                    GeometryReader { proxy in
//                        EmptyView()
//                            .onChange(of: proxy.frame(in: .named("scrollView")).midY) { newPosition in
//
//                                if ceil(newPosition) > 190 && !vm.functionHasRan {
//                                    vm.functionHasRan = true
//                                    withAnimation(.spring()) {
//                                        vm.hasAskedToReload = true
//                                    }
//
//                                    vm.refreshStories()
//
//                                }
//
//                                if newPosition < 100 {
//                                    vm.functionHasRan = false
//                                }
//                            }
//                            .frame(height: 10)
//                            .frame(maxWidth: .infinity)
//                    }
//
//                }
                            
                
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
        .overlay(alignment: .bottomTrailing) {
            Button {
                vm.refreshStories()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding()
                    .shadow(color: .black.opacity(0.20), radius: 20, x: 0, y: 10)
                
            }
        }
    }
    
    var listView: some View {
        List {
            StorySelectionView(selectedStoryType: $vm.storyType)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            
            listStories
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            vm.refreshStories()
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
                    vm.subToastText = error.localizedDescription
                    vm.subToastTextColor = .red.opacity(0.8)
                    vm.subError = ErrorType(error: .noInternet)
                }
                
            }
        }
        .fullScreenCover(item: $selectedStory) { story in
            if let storyUrl = story.url {
                SafariView(vm: vm, url: storyUrl)
            }
        }
    }
    
    @ViewBuilder var listStories: some View {
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
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                
        } else {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        
        if vm.isLoading {
            ProgressView()
                .padding()
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


struct AppNavbarView_Previews: PreviewProvider {
    static var previews: some View {
        AppNavbarView()
    }
}
