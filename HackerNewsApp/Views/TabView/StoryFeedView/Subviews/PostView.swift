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
    

    var body: some View {
        if globalSettings.selectedCardStyle == .normal {
            normalCard
        } else {
            compactCard
        }
        
    }
}

extension PostView {
    
    // MARK: Compact Card
    @ViewBuilder var compactCard: some View {
        if let story = vm.story {
            VStack(spacing: 0) {
                
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
                        
                        Text(story.url != nil ? "\(story.title) \(Image(systemName: "arrow.up.forward.app"))" : "\(story.title)")
                            .foregroundColor(Color("PostTitle"))
                            .font(.headline.weight(.bold))
                            .padding(.bottom, 10)
                        
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
                                .shadow(color: .black, radius: 20, x: 0, y: 10)
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
//                        .foregroundColor(.secondary)
//                        .padding(.leading, 15)
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        //Bookmark Button
                        if wrapper.bookmarkSaved {
                            Image(systemName: "bookmark.fill")
//                                .foregroundColor(.secondary)
//                                .fontWeight(.medium)
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
                        
                        // Comment Button
                        CommentsButtonView(vm: vm)
                    }
                    .foregroundColor(Color("ButtonColor"))
                    .font(.subheadline.weight(.semibold))
                    
                }
                .padding(20)
//                .overlay(alignment: .top) {
//                    Rectangle()
//                        .fill(.regularMaterial)
//                        .frame(height: 2)
//                        .padding(.horizontal, 20)
//                }
                
//                Rectangle()
////                    .fill(Color("BackgroundColor"))
//                    .fill(Color.clear)
//                    .frame(height: 5)
                
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
                    if let storyTitle = story.title {
                        Text(story.url != nil ? "\(storyTitle) \(Image(systemName: "arrow.up.forward.app"))" : "\(storyTitle)")
                            .font(.title3.weight(.bold))
                            .foregroundColor(Color("PostTitle"))
                            .padding(.bottom, 10)
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
                            CommentsButtonView(vm: vm)
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
    init(withWrapper wrapper: StoryWrapper, story: Story) {
        self._vm = StateObject(wrappedValue: UltimatePostViewModel(withStory: story))
        self._wrapper = State(initialValue: wrapper)
    }
}

