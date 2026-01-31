//
//  SingleBookmarkView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/24/22.
//

import SwiftUI

struct SingleBookmarkView: View {
    
    let bookmark: Bookmark
    
    @StateObject var vm: SingleBookmarkViewModel
    @Binding var bookmarkToDelete: Bookmark?
    @Binding var path: [AppRoute]
    @Environment(\.openURL) var openURL
    
    
    var body: some View {
        if let story = vm.story {
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        if let urlDomain = story.url?.urlDomain {
                            Text(urlDomain)
                                .foregroundColor(.accentColor)
                                .font(.caption.weight(.semibold))
                                .padding(.bottom, 5)
                        }
                        
                        Text(story.title)
                            .foregroundColor(.primary)
                            .font(.title3.weight(.semibold))
                            .onTapGesture {
                                if let url = story.url, let safe = URL(string: vm.networkManager.getSecureUrlString(url: url)) {
                                    openURL(safe, prefersInApp: true)
                                }
                                Task {
                                    await ReadStateStore.shared.markRead(storyID: story.id)
                                    await HistoryStore.shared.addEntry(story: story, feed: .topstories)
                                }
                            }
                        
                    }
                    
                    Spacer()
                    
                    AsyncImage(url: vm.imageUrl) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(.gray.opacity(0.4))
                            .frame(width: 100, height: 100)
                    }
                    .onTapGesture {
                        if let url = story.url, let safe = URL(string: vm.networkManager.getSecureUrlString(url: url)) {
                            openURL(safe, prefersInApp: true)
                        }
                        Task {
                            await ReadStateStore.shared.markRead(storyID: story.id)
                            await HistoryStore.shared.addEntry(story: story, feed: .topstories)
                        }
                    }
                    
                }
                
                HStack {
                    Text(story.score == 1 ? "\(story.score) point" : "\(story.score) points")
                        .font(.callout.weight(.medium))
                    
                    Spacer()
                    
                    //Bookmark Delete Button
                    Button {
                        bookmarkToDelete = bookmark
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    
                    // Share button
                    
                    if let url = story.url {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .tint(.accentColor)
                    }
                    
                    // Comment Button
                    CommentsButtonView(vm: vm) {
                        path.append(.comments(story))
                        Task {
                            await ReadStateStore.shared.markRead(storyID: story.id)
                            await HistoryStore.shared.addEntry(story: story, feed: .topstories)
                        }
                    }
                    
                    
                    
                }
            }
            .padding(15)
            .background(Color("CardColor"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
            .task {
                vm.imageUrl = await vm.getImageUrl(fromUrl: story.url)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                path.append(.comments(story))
                Task {
                    await ReadStateStore.shared.markRead(storyID: story.id)
                    await HistoryStore.shared.addEntry(story: story, feed: .topstories)
                }
            }
        }
    }
    
    init(bookmark: Bookmark, bookmarkToDelete: Binding<Bookmark?>, path: Binding<[AppRoute]>) {
        self.bookmark = bookmark
        self._vm = StateObject(wrappedValue: SingleBookmarkViewModel(withStory: bookmark.story))
        self._bookmarkToDelete = bookmarkToDelete
        self._path = path
    }
}
