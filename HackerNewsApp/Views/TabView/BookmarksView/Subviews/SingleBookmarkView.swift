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
        CustomNavLink {
            CommentsView(vm: vm)
                .customNavigationTitle("Comments")
        } label: {
            card
        }
    }
    
}

// Initializer
extension SingleBookmarkView {
    init(bookmark: Bookmark, selectedStory: Binding<Story?>, bookmarkToDelete: Binding<Bookmark?>) {
        self.bookmark = bookmark
        self._vm = StateObject(wrappedValue: SingleBookmarkViewModel(withStory: bookmark.story))
        self._selectedStory = selectedStory
        self._bookmarkToDelete = bookmarkToDelete
    }
}

// Card
extension SingleBookmarkView {
    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            infoSection
            
            HStack {
                scoreLabel
                
                Spacer()
                
                buttons
                
            }
            .padding(20)
        }
        .background(Color("CardColor"))
        .cornerRadius(12)
        .padding(.bottom, 5)
        .padding(.horizontal, 10)
        .task {
            if let story = vm.story {
                vm.imageUrl = await vm.getImageUrl(fromUrl: story.url)
            }
            
            
        }
        .sheet(item: $selectedStory) { story in
            SafariView(vm: vm, url: story.url)
        }
    }
}

// Card Components
extension SingleBookmarkView {
    
    private var infoSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
               
                domainLabel
                
                titleLabel
                
                authorLabel
                
            }
            
            Spacer()
            if let story = vm.story {
                CustomAsyncImageView(url: story.url, id: story.id, sizeType: .compact)
            }
        }
        .padding(20)
        .padding(.bottom, 10)
    }
    
    @ViewBuilder private var domainLabel: some View {
        if let story = vm.story,
           let unsafeUrl = story.url,
           let urlDomain = vm.networkManager.getSecureUrlString(url: unsafeUrl).urlDomain {
            Text(urlDomain)
                .foregroundColor(.orange)
                .font(.caption.weight(.semibold))
                .padding(.bottom, 5)
        }
    }
    
    @ViewBuilder private var titleLabel: some View {
        if let story = vm.story {
            Text(story.url != nil ? "\(story.title) \(Image(systemName: "arrow.up.forward.app"))" : "\(story.title)")
                .foregroundColor(.primary)
                .font(.headline.weight(.bold))
                .multilineTextAlignment(.leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedStory = story
                }
                .padding(.bottom, 5)
        }
        
    }
    
   @ViewBuilder private var authorLabel: some View {
       if let story = vm.story {
           Text("by \(story.by)")
               .foregroundColor(.blue)
               .font(.caption.weight(.semibold))
       }
    }
    
    @ViewBuilder private var scoreLabel: some View {
        if let story = vm.story {
            Text(story.score == 1 ? "\(story.score) point" : "\(story.score.compressedNumber) points")
                .font(.subheadline.weight(.medium))
        }
    }
    
    private var buttons: some View {
        HStack(spacing: 20) {
            
            //Bookmark Button
            deleteButton
            
            // Share button
            shareButton
            
            // Comment Label
            commentLabel
        }
        .foregroundColor(Color("ButtonColor"))
        .font(.subheadline.weight(.semibold))
    }
    
    private var deleteButton: some View {
        Button {
            vm.deleteBookmark = true
        } label: {
            Image(systemName: "trash")
                .foregroundColor(.red.opacity(0.7))
        }
        .alert("Are you sure you want to delete this bookmark?", isPresented: $vm.deleteBookmark) {
            
            Button("Cancel", role: .cancel) {}
            
            Button("Delete", role: .destructive) {
                bookmarkToDelete = bookmark
            }
            
        }
    }
    
    @ViewBuilder private var shareButton: some View {
        if let story = vm.story,
           let unsafeUrl = story.url {
            ShareLink(item: vm.networkManager.getSecureUrlString(url: unsafeUrl)) {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }
    
    @ViewBuilder private var commentLabel: some View {
        if let story = vm.story,
           let commentCount = story.descendants {
            Label(String(commentCount.compressedNumber), systemImage: "bubble.right")
        }
    }
}

