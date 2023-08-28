//
//  AppNavbarView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/15/22.
//

import SwiftUI

struct FeedView: View {
    
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    @EnvironmentObject var nav: GlobalNavigator
    
    @Namespace var namespace
    
    @StateObject var vm: FeedViewModel
    @State var selectedStory: Story?
    
    var body: some View {
        NavigationStack(path: $nav.feedRoutes) {
            Group {
                if vm.showNoInternetScreen {
                    NoInternetView(vm: vm)
                } else {
                    scrollView
                }
            }
            .navigationTitle("Story Feed")
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Logo()
                        .frame(width: 30, height: 30)
                        .foregroundStyle(LinearGradient(colors: [.orange, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            })
            .overlay {
                if globalSettings.appError != nil {
                    ToastView(text: globalSettings.toastText, textColor: globalSettings.toastTextColor)
                        .zIndex(2)
                        .transition(.asymmetric(insertion: .move(edge: .top), removal: .move(edge: .top)))
                }
            }
            .onChange(of: vm.subError, perform: setError)
            .onChange(of: vm.subToastText, perform: setToastText)
            .onChange(of: vm.subToastTextColor, perform: setToastTextColor)
            .navigationDestination(for: FeedRoute.self) { route in
                switch route {
                case .postDetailView:
                    Text("Post Detail View in FeedRoute")
                }
            }
        }
    }
}


// MARK: Custom Initializer
extension FeedView {
    init(dependencies: Dependencies) {
        self._vm = StateObject(wrappedValue: FeedViewModel(dependencies: dependencies))
        self._selectedStory = State(wrappedValue: nil)
    }
}

// View Components
extension FeedView  {
    
    var scrollView: some View {
        ScrollView {
            
            // MARK: View Foreground
            VStack(spacing: 0) {
                
                StorySelectionView(selectedStoryType: $vm.storyType)
                
                if horizontalSizeClass == .regular && verticalSizeClass == .regular {
                    StoriesListView(vm: vm, selectedStory: $selectedStory)
                        .fullScreenCover(item: $selectedStory) { story in
                            if let storyUrl = story.url {
                                SafariView(vm: vm, url: storyUrl)
                            }
                        }
                } else {
                    StoriesListView(vm: vm, selectedStory: $selectedStory)
                        .sheet(item: $selectedStory) { story in
                            if let storyUrl = story.url {
                                SafariView(vm: vm, url: storyUrl)
                            }
                        }
                }
                
            }
            
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
    
}

// MARK: Functions
extension FeedView {
    private func setError(_ errorType: ErrorType?) {
        globalSettings.appError = errorType
    }
    
    private func setToastText(_ text: String) {
        globalSettings.toastText = text
    }
    
    private func setToastTextColor(_ color: Color) {
        globalSettings.toastTextColor = color
    }
}


struct AppNavbarView_Previews: PreviewProvider {
    static var previews: some View {
        FeedView(dependencies: Dependencies())
    }
}
