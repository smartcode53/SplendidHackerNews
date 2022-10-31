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
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @StateObject var networkChecker = NetworkChecker()
    @StateObject var vm = StoryFeedViewModel()
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    @State var selectedStory: Story? = nil
    @Namespace var namespace
    
    var body: some View {
        CustomNavView {
            ZStack {
                Color("BackgroundColor").ignoresSafeArea()
                
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
        VStack(spacing: 0) {
            if !vm.isInitiallyLoading {
                ForEach(vm.storiesDict[vm.storyType] ?? []) { wrapper in
                    if let story = wrapper.story {
                        PostView(withWrapper: wrapper, story: story, selectedStory: $selectedStory)
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
    }
    
    var scrollView: some View {
        ScrollView {
            
            // MARK: View Foreground
            VStack(spacing: 0) {
                
                StorySelectionView(selectedStoryType: $vm.storyType)
                
                if horizontalSizeClass == .regular && verticalSizeClass == .regular {
                    stories
                        .fullScreenCover(item: $selectedStory) { story in
                            if let storyUrl = story.url {
                                SafariView(vm: vm, url: storyUrl)
                            }
                        }
                } else {
                    stories
                        .sheet(item: $selectedStory) { story in
                            if let storyUrl = story.url {
                                SafariView(vm: vm, url: storyUrl)
                            }
                        }
                }
                
            }
            .navigationTitle(Text(vm.storyType.rawValue))
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTitleDisplayMode(.automatic)
            .toolbarBackground(Color("NavigationBarColor"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            
            
            if vm.showBlankColor {
                LazyVStack {
                    Color.clear
                        .frame(width: 0, height: 0)
                        .onAppear {
                            Task {
                                await vm.loadInfinitely()
                            }
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            
        }
        .coordinateSpace(name: "scrollView")
        .overlay(alignment: .bottomTrailing) {
            DragToRefreshView(refreshFunc: vm.refreshStories)
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
