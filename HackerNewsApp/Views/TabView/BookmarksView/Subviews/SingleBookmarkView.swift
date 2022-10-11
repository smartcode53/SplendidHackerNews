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
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        if let urlDomain = story.url?.urlDomain {
                            Text(urlDomain)
                                .foregroundColor(.orange)
                                .font(.caption.weight(.semibold))
                                .padding(.bottom, 5)
                        }
                        
                        Text(story.title)
                            .foregroundColor(Color("PostTitle"))
                            .font(.title3.weight(.bold))
                        
                        Text("by \(story.by)")
                            .foregroundColor(Color("PostDateName"))
                            .font(.subheadline)
                        
                        
                    }
                    
                    Spacer()
                    
                    AsyncImage(url: vm.imageUrl) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipped()
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                    } placeholder: {
                        ImagePlaceholderView(height: 100, width: 100)
                    }
                    
                }
                .padding(.bottom, 16)
                
                HStack {
                    Text(story.score == 1 ? "\(story.score) point" : "\(story.score) points")
                        .font(.callout.weight(.medium))
                    
                    Spacer()
                    
                    //Bookmark Delete Button
                    Button {
                        bookmarkToDelete = bookmark
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.7))
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    
                    // Share button
                    
                    if let url = story.url {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Comment Button
                    CommentsButtonView(vm: vm)
                        .foregroundColor(.primary)
                }
            }
            .padding(15)
            .background(Color("CardColor"))
            .cornerRadius(12)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .task {
                vm.imageUrl = await vm.getImageUrl(fromUrl: story.url)
            }
            .onTapGesture {
                selectedStory = story
            }
            .fullScreenCover(item: $selectedStory) { story in
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

