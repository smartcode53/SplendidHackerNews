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
    @Binding var selectedStory: Story?
    @Binding var bookmarkToDelete: Bookmark?
    
    
    var body: some View {
        if let story = vm.story {
            VStack(alignment: .leading, spacing: 0) {
                
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        if let unsafeUrl = story.url,
                           let url = vm.networkManager.getSecureUrlString(url: unsafeUrl),
                           let urlDomain = url.urlDomain {
                            Text(urlDomain)
                                .foregroundColor(.orange)
                                .font(.caption.weight(.semibold))
                                .padding(.bottom, 5)
                        }
                        
                        Button {
                            selectedStory = story
                        } label: {
                            Text(story.url != nil ? "\(story.title) \(Image(systemName: "arrow.up.forward.app"))" : "\(story.title)")
                                .foregroundColor(.primary)
                                .font(.headline.weight(.bold))
                                .multilineTextAlignment(.leading)
                                .contentShape(Circle())
                        }
                        .padding(.bottom, 5)
                        
                        
                        Text("by \(story.by)")
                            .foregroundColor(.blue)
                            .font(.caption.weight(.semibold))
                        
                    }
                    
                    Spacer()
                    
                    
                    CustomAsyncImageView(url: story.url, id: story.id, sizeType: .compact)
                    
                    
                }
                .padding(20)
                .padding(.bottom, 10)
                
                HStack {
                    Text(story.score == 1 ? "\(story.score) point" : "\(story.score.compressedNumber) points")
                        .font(.subheadline.weight(.medium))
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        //Bookmark Button
                        Button {
                            bookmarkToDelete = bookmark
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red.opacity(0.7))
                        }
                        
                        // Share button
                        
                        if let unsafeUrl = story.url,
                           let url = vm.networkManager.getSecureUrlString(url: unsafeUrl) {
                            ShareLink(item: url) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        
                        // Comment Label
                        if let commentCount = story.descendants {
                            Label(String(commentCount.compressedNumber), systemImage: "bubble.right")
                        }
                    }
                    .foregroundColor(Color("ButtonColor"))
                    .font(.subheadline.weight(.semibold))
                    
                }
                .padding(20)
            }
            .background(Color("CardColor"))
            .cornerRadius(12)
            .padding(.bottom, 5)
            .padding(.horizontal, 10)
            .task {
                vm.imageUrl = await vm.getImageUrl(fromUrl: story.url)
            }
            .sheet(item: $selectedStory) { story in
                SafariView(vm: vm, url: story.url)
            }
        }
    }
    
    init(bookmark: Bookmark, selectedStory: Binding<Story?>, bookmarkToDelete: Binding<Bookmark?>) {
        self.bookmark = bookmark
        self._vm = StateObject(wrappedValue: SingleBookmarkViewModel(withStory: bookmark.story))
        self._selectedStory = selectedStory
        self._bookmarkToDelete = bookmarkToDelete
    }
}

