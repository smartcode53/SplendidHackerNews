//
//  BookmarksView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/24/22.
//

import SwiftUI

struct BookmarksView: View {
    
    @Binding var path: [AppRoute]
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    @StateObject var vm = BookmarksViewModel()
    @State private var showHistory = false
    @State var bookmarkToDelete: Bookmark?
    
    var body: some View {
        NavigationStack {
            ZStack {
                
                Color("BackgroundColor")
                    .ignoresSafeArea()
                
                if vm.bookmarks.isEmpty {
                    VStack {
                        Text("You've not bookmarked any stories yet. To do so, tap the bookmark button (\(Image(systemName: "bookmark"))) on a story within the story feed.")
                    }
                    .padding()
                    
                } else {
                    ScrollView {
                        LazyVStack {
                            
                            Divider()
                                .padding(.bottom, 10)
                            
                            ForEach(vm.bookmarks) { bookmark in
                                SingleBookmarkView(bookmark: bookmark, bookmarkToDelete: $bookmarkToDelete, path: $path)
                            }
                        }
                        .navigationTitle("Saved Stories")
                        .navigationBarTitleDisplayMode(.automatic)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Menu {
                                    ForEach(BookmarksViewModel.SortType.allCases, id: \.self) { type in
                                        Button(type.rawValue) {
                                            vm.selectedSortType = type
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.up.arrow.down.square")
                                        Text("Sort")
                                    }
                                }

                            }
                            
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button {
                                    showHistory = true
                                } label: {
                                    Image(systemName: "clock.arrow.circlepath")
                                    Text("History")
                                }
                            }
                        }
                    }
                }
            }
            .onAppear {
                vm.bookmarks.append(contentsOf: globalSettings.tempBookmarks)
                globalSettings.tempBookmarks.removeAll()
                globalSettings.syncBookmarkedStoryIDs(from: vm.bookmarks)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .inactive {
                    vm.saveToDisk()
                    globalSettings.syncBookmarkedStoryIDs(from: vm.bookmarks)
                }
            }
            .onChange(of: bookmarkToDelete) { _, bookmark in
                if let bookmark {
                    if let index = vm.bookmarks.firstIndex(of: bookmark) {
                        vm.bookmarks.remove(at: index)
                    }
                    globalSettings.syncBookmarkedStoryIDs(from: vm.bookmarks)
                    bookmarkToDelete = nil
                }
             }
            .navigationDestination(isPresented: $showHistory) {
                HistoryView(path: $path)
            }
        }
    }
}

struct BookmarksView_Previews: PreviewProvider {
    static var previews: some View {
        BookmarksView(path: .constant([]))
    }
}
