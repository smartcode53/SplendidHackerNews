//
//  PostView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/8/22.
//

import SwiftUI

struct PostView: View {
    
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    @StateObject var vm: UltimatePostViewModel
    @State private var wrapper: StoryWrapper
    @Namespace var namespace
    @Binding var selectedStory: Story?
    

    var body: some View {
        
        CustomNavLink {
            CommentsView(vm: vm)
                .customNavBarItems(title: "Comments", backButtonHidden: false)
        } label: {
            if globalSettings.selectedCardStyle == .normal {
                normalCard
            } else {
                compactCard
            }
        }
    }
}

extension PostView {
    
    // MARK: Compact Card
    @ViewBuilder var compactCard: some View {
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
                                .foregroundColor(Color("PostTitle"))
                                .font(.headline.weight(.bold))
                                .multilineTextAlignment(.leading)
                                .contentShape(Circle())
                        }
                        .padding(.bottom, 5)
                        
                        
                        
                        HStack {
                            Text(Date.getTimeInterval(with: story.time))
                            Text("|")
                                .foregroundColor(Color("DateNameSeparator"))
                            Text(story.by)
                            
                            Spacer()
                        }
                        .foregroundColor(Color("PostDateName"))
                        .font(.caption.weight(.semibold))
                        
                    }
                    
                    Spacer()
                    
                    if let imageUrl = vm.imageUrl {
                        if let cachedImage = vm.imageCacheManager.getFromCache(withKey: String(story.id)) {
                            cachedImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipped()
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                        } else {
                            AsyncImage(url: imageUrl) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                                    .onAppear {
                                        vm.imageCacheManager.saveToCache(image, withKey: String(story.id))
                                    }
                            } placeholder: {
                                ImagePlaceholderView(height: 100, width: 100)
                            }
                        }
                    }
                    
                    
                }
                .padding(20)
                .padding(.bottom, 10)
                
                HStack {
                    Text(story.score == 1 ? "\(story.score) point" : "\(story.score.compressedNumber) points")
                        .font(.subheadline.weight(.medium))
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        //Bookmark Button
                        if wrapper.bookmarkSaved {
                            Image(systemName: "bookmark.fill")
                                .matchedGeometryEffect(id: "compactBookmarkButton", in: namespace)
                        } else {
                            Button {
                                let bookmark = Bookmark(story: story)
                                globalSettings.tempBookmarks.append(bookmark)
                                withAnimation(.spring()) {
                                    wrapper.bookmarkSaved = true
                                }
                            } label: {
                                Image(systemName: "bookmark")
                                    .matchedGeometryEffect(id: "compactBookmarkButton", in: namespace)
                            }
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
            .padding(.bottom, 5)
            .task {
                if let unsafeUrl = story.url {
                    let url = vm.networkManager.getSecureUrlString(url: unsafeUrl)
                    vm.loadImage(fromUrl: url)
                }
            }
        }
    }
    
    
    // MARK: Normal Card
    @ViewBuilder var normalCard: some View {
        if let story = vm.story {
            VStack {
                
                VStack(alignment: .leading, spacing: 0) {
                    
                    
                    // Domain Name
                    if let unsafeUrl = story.url,
                       let url = vm.networkManager.getSecureUrlString(url: unsafeUrl),
                       let urlDomain = url.urlDomain {
                        Text(urlDomain)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.orange)
                            .padding(.bottom, 5)
                    }
                    
                    // Story Title
                    Button {
                        selectedStory = story
                    } label: {
                        Text(story.url != nil ? "\(story.title) \(Image(systemName: "arrow.up.forward.app"))" : "\(story.title)")
                            .font(.title3.weight(.bold))
                            .foregroundColor(Color("PostTitle"))
                            .padding(.bottom, 10)
                            .multilineTextAlignment(.leading)
                            .contentShape(Circle())
                    }
                    
                    
                    // Meta info
                    HStack {
                        Text(Date.getTimeInterval(with: story.time))
                        Text("|")
                            .foregroundColor(Color("DateNameSeparator"))
                        Text(story.by)
                        
                        Spacer()
                    }
                    .foregroundColor(Color("PostDateName"))
                    .padding(.bottom, 16)
                    .font(.caption.weight(.semibold))
                }
                .padding([.horizontal, .top])
                
                if let imageUrl = vm.imageUrl {
                    if let cachedImage = vm.imageCacheManager.getFromCache(withKey: String(story.id)) {
                        cachedImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: UIScreen.main.bounds.width * 0.977)
                            .frame(height: 220)
                            .clipped()
                    } else {
                        AsyncImage(url: imageUrl) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: UIScreen.main.bounds.width)
                                .frame(height: 220)
                                .clipped()
                                .onAppear {
                                    vm.imageCacheManager.saveToCache(image, withKey: String(story.id))
                                }
                        } placeholder: {
                            ImagePlaceholderView(height: 220, width: UIScreen.main.bounds.width)
                        }
                    }
                }
                    
                
                // Points and Actionable Buttons
                VStack {
                    HStack {
                        Text(story.score == 1 ? "\(story.score) point" : "\(story.score.compressedNumber) points")
                                .font(.headline)
                        
                        Spacer()
                        
                        HStack(spacing: 20) {
                            if wrapper.bookmarkSaved {
                                Image(systemName: "bookmark.fill")
                                    .matchedGeometryEffect(id: "bookmarkButton", in: namespace)
                            } else {
                                Button {
                                    let bookmark = Bookmark(story: story)
                                    globalSettings.tempBookmarks.append(bookmark)
                                    withAnimation(.spring()) {
                                        wrapper.bookmarkSaved = true
                                    }
                                } label: {
                                    Image(systemName: "bookmark")
                                        .matchedGeometryEffect(id: "bookmarkButton", in: namespace)
                                }
                                
                            }
                            
                            
                            // Share Button
                            if let unsafeUrl = story.url,
                               let url = vm.networkManager.getSecureUrlString(url: unsafeUrl) {
                                ShareLink(item: url) {
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                        
                            //Comments Button
                            if let commentCount = story.descendants {
                                Label(String(commentCount.compressedNumber), systemImage: "bubble.right")
                            }
                        }
                        .foregroundColor(Color("ButtonColor"))
                        .font(.subheadline.weight(.semibold))
                        
                    }
                    .padding()
                }
                
                Rectangle()
                    .fill(Color("BackgroundColor"))
                    .frame(height: 5)
            }
            .background(Color("CardColor"))
            .task {
                if let unsafeUrl = story.url {
                    let url = vm.networkManager.getSecureUrlString(url: unsafeUrl)
                    vm.loadImage(fromUrl: url)
                }
            }
        }

    }
    
}

extension PostView {
    init(withWrapper wrapper: StoryWrapper, story: Story, selectedStory: Binding<Story?>) {
        self._vm = StateObject(wrappedValue: UltimatePostViewModel(withStory: story))
        self._wrapper = State(initialValue: wrapper)
        self._selectedStory = selectedStory
    }
}

