//
//  StoriesListView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/28/23.
//

import SwiftUI

struct StoriesListView: View {
    
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    
    @ObservedObject var vm: FeedViewModel
    @Binding var selectedStory: Story?
    
    var body: some View {
        VStack(spacing: 0) {
            if !vm.isInitiallyLoading {
                ForEach(vm.storiesDict[vm.storyType] ?? []) { wrapper in
                    if let story = wrapper.story {
                        StoryView(withWrapper: wrapper, story: story, selectedStory: $selectedStory, storyFeedVm: vm)
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
        .onChange(of: scenePhase, perform: persistStories)
        .task { checkNetwork() }
    }
}

// MARK: Functions
extension StoriesListView {
    private func checkNetwork() {
        if vm.networkChecker.isConnected {
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
    
    private func persistStories(for phase: ScenePhase) {
        if phase == .inactive {
            vm.saveStoriesToDisk()
        }
    }
}

struct StoriesListView_Previews: PreviewProvider {
    static var previews: some View {
        StoriesListView(vm: FeedViewModel(dependencies: Dependencies()), selectedStory: .constant(nil))
    }
}
