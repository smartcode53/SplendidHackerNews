//
//  BookmarksView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/24/22.
//

import SwiftUI

struct BookmarksView: View {
    
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
//    @StateObject var vm = BookmarksViewModel()
    @State var selectedStory: Story?
    @State var bookmarkToDelete: Bookmark?
    
    var body: some View {
        NavigationStack {
            ZStack {
                
                Color("BackgroundColor").ignoresSafeArea()
                
                if globalSettings.bookmarks.isEmpty {
                    VStack {
                        Text("You've not bookmarked any stories yet. To do so, tap the bookmark button (\(Image(systemName: "bookmark"))) on a story within the story feed.")
                    }
                    .padding()
                    
                } else {
                    ScrollView {
                        LazyVStack {
                            Rectangle()
                                .fill(.primary)
                                .frame(height: 2)
                                .padding(.bottom, 10)
                            
                            ForEach(globalSettings.bookmarks) { bookmark in
                                SingleBookmarkView(bookmark: bookmark, selectedStory: $selectedStory, bookmarkToDelete: $bookmarkToDelete)
                            }
                        }
                        .navigationTitle("Saved Stories")
                        .navigationBarTitleDisplayMode(.automatic)
                        .toolbarBackground(Color("CardColor"), for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Menu {
                                    ForEach(SortType.allCases, id: \.self) { type in
                                        Button(type.rawValue) {
                                            globalSettings.selectedSortType = type
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.up.arrow.down.square")
                                        Text("Sort")
                                    }
                                }

                            }
                        }
                    }
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .inactive {
                    globalSettings.saveBookmarksToDisk()
                }
            }
            .onChange(of: bookmarkToDelete) { bookmark in
                if let bookmark {
                    if let index = globalSettings.bookmarks.firstIndex(of: bookmark) {
                        withAnimation(.spring()) {
                            _ = globalSettings.bookmarks.remove(at: index)
                        }
                    }
                    bookmarkToDelete = nil
                }
             }
        }
    }
}

struct BookmarksView_Previews: PreviewProvider {
    static var previews: some View {
        BookmarksView()
    }
}
