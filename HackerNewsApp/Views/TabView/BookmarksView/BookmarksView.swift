//
//  BookmarksView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/24/22.
//

import SwiftUI
import StoreKit

struct BookmarksView: View {
    
    @Environment(\.requestReview) var requestReview
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    @State var selectedStory: Story?
    @State var bookmarkToDelete: Bookmark?
    
    var body: some View {
        if globalSettings.bookmarks.isEmpty {
            VStack {
                Text("You've not bookmarked any stories yet. To do so, tap the bookmark button (\(Image(systemName: "bookmark"))) on a story within the story feed.")
            }
            .padding()
        } else {
            CustomNavView {
                content
            }
        }
    }
}

// Card
extension BookmarksView {
    private var content: some View {
        ZStack {
            
            Color("BackgroundColor").ignoresSafeArea()
            
            scrollView
        }
        .customNavigationTitle("Saved Stories")
        .customNavigationBarBackButtonHidden(true)
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
                    globalSettings.saveBookmarksToDisk()
                }
                bookmarkToDelete = nil
            }
        }
    }
}


// Card Components
extension BookmarksView {
    private var scrollView: some View  {
        ScrollView {
            
            if horizontalSizeClass == .regular && verticalSizeClass == .regular {
                SortingView()
                    .frame(width: UIScreen.main.bounds.width * 0.7)
            } else {
                SortingView()
            }
            
            
            LazyVStack {
                ForEach(globalSettings.sortBookmarks()) { bookmark in
                    SingleBookmarkView(bookmark: bookmark, selectedStory: $selectedStory, bookmarkToDelete: $bookmarkToDelete)
                        .onAppear {
                            if globalSettings.bookmarks.count > 5 {
                                requestReview()
                            }
                        }
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
