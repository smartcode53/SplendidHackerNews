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
    @Binding var selectedStory: Story?
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
            VStack {
                
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
                            .font(.title3.weight(.bold))
                            .padding(.bottom, 10)
                            .onTapGesture {
                                selectedStory = story
                            }
                        
                        HStack {
                            Text(Date.getTimeInterval(with: story.time))
                            Text("|")
                                .foregroundColor(Color("DateNameSeparator"))
                            Text(story.by)
                            
                            Spacer()
                        }
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
                    
                    //Bookmark Button
                    if wrapper.bookmarkSaved {
                        Image(systemName: "bookmark.fill")
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
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
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                                .matchedGeometryEffect(id: "compactBookmarkButton", in: namespace)
                        }
                        .buttonStyle(.bordered)
                        
                    }
                    
                    // Share button
                    
                    if let unsafeUrl = story.url,
                       let url = vm.networkManager.getSecureUrlString(url: unsafeUrl) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Comment Button
                    CommentsButtonView(vm: vm)
                    
                }
            }
            .padding(15)
            .background(Color("CardColor"))
            .cornerRadius(12)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
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
                            .font(.caption.weight(.bold))
                            .foregroundColor(.orange)
                            .padding(.bottom, 10)
                    }
                    
                    // Story Title
                    if let storyTitle = story.title {
                        Text(story.url != nil ? "\(storyTitle) \(Image(systemName: "arrow.up.forward.app"))" : "\(storyTitle)")
                            .font(.title2.weight(.bold))
                            .foregroundColor(Color("PostTitle"))
                            .padding(.bottom, 16)
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
                    .font(.subheadline)
                }
                .padding([.horizontal, .top])
                .onTapGesture {
                    if story.url != nil {
                        selectedStory = vm.story
                    }
                    
                }
                
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
                                .frame(width: UIScreen.main.bounds.width * 0.977)
                                .frame(height: 220)
                                .clipped()
                                .onAppear {
                                    vm.imageCacheManager.saveToCache(image, withKey: String(story.id))
                                }
                        } placeholder: {
                            ImagePlaceholderView(height: 220, width: UIScreen.main.bounds.width * 0.977)
                        }
                    }
                }
                
                
                // Story Image
                    
                
                // Points and Actionable Buttons
                VStack {
                    HStack {
                        if let points = story.score {
                            Text(points == 1 ? "\(points) point" : "\(points) points")
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        //Bookmark Button
                        if wrapper.bookmarkSaved {
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
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
                                    .foregroundColor(.primary)
                                    .fontWeight(.medium)
                                    .matchedGeometryEffect(id: "bookmarkButton", in: namespace)
                            }
                            .buttonStyle(.bordered)
                            
                        }
                        
                        
                        // Share Button
                        if let unsafeUrl = story.url,
                           let url = vm.networkManager.getSecureUrlString(url: unsafeUrl) {
                            ShareLink(item: url) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.bordered)
                        }
                    
                        //Comments Button
                        CommentsButtonView(vm: vm)
                        
                    }
                    .padding()
                }
            }
            .background(Color("CardColor"))
            .cornerRadius(12)
            .padding(.horizontal, 5)
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
    init(withWrapper wrapper: StoryWrapper, selectedStory: Binding<Story?>, story: Story) {
        self._vm = StateObject(wrappedValue: UltimatePostViewModel(withStory: story))
        self._wrapper = State(initialValue: wrapper)
        self._selectedStory = selectedStory
    }
}

