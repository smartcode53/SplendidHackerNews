//
//  PostView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/8/22.
//

import SwiftUI

struct PostView: View {
    
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @StateObject var vm: UltimatePostViewModel
    @State private var wrapper: StoryWrapper
    @Namespace var namespace
    @Binding var selectedStory: Story?
    @State private var imageWidth: CGFloat = UIScreen.main.bounds.width
    @State private var imageLoaded: Bool = false
    let story: Story
    
    // Body
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
        .createPressableButton()
        .onAppear { vm.updateBookmarkStatus(globalSettings: globalSettings, story: story) }
    }
}

// Card Styles
extension PostView {
    
    @ViewBuilder var compactCard: some View {
        if horizontalSizeClass == .compact {
            smallCompactCardContent
        } else if horizontalSizeClass == .regular {
            largeCompactCardContent
        }
    }
    
    @ViewBuilder var normalCard: some View {
        if horizontalSizeClass == .compact {
            smallNormalCardContent
        } else if horizontalSizeClass == .regular {
            largeNormalCardContent
        }
    }
}

// Card Styles based on device and their respective orientations
extension PostView {
    var smallCompactCardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // Domain Label
                    urlDomainLabel
                    
                    // Title label attached to a button
                    compactInteractiveTitleLabel
                    
                    // Meta info labels
                    compactMetaInfoLabel
                    
                }
                
                Spacer()
                
                // Image View
                
                CustomAsyncImageView(url: story.url, id: story.id, sizeType: .compact)
                                
            }
            .padding(20)
            .padding(.bottom, 10)
            
            HStack {
                compactScoreLabel
                
                Spacer()
                
                HStack(spacing: 20) {
                    //Bookmark Button
                    bookmarkButton
                    
                    // Share button
                    shareButton
                    
                    // Comment Label
                    commentsLabel
                }
                .foregroundColor(Color("ButtonColor"))
                .font(.subheadline.weight(.semibold))
                
            }
            .padding(20)
            
        }
        .background(Color("CardColor"))
        .cornerRadius(12)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }
    
    var largeCompactCardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // Domain Label
                    urlDomainLabel
                    
                    // Title label attached to a button
                    compactInteractiveTitleLabel
                    
                    // Meta info labels
                    compactMetaInfoLabel
                    
                }
                
                Spacer()
                
                // Image View
                CustomAsyncImageView(url: story.url, id: story.id, sizeType: .compact)
                
            }
            .padding(20)
            .padding(.bottom, 10)
            
            HStack {
                compactScoreLabel
                
                Spacer()
                
                HStack(spacing: 20) {
                    //Bookmark Button
                    bookmarkButton
                    
                    // Share button
                    shareButton
                    
                    // Comment Label
                    commentsLabel
                }
                .foregroundColor(Color("ButtonColor"))
                .font(.subheadline.weight(.semibold))
                
            }
            .padding(20)
            
        }
        .frame(width: UIScreen.main.bounds.width * 0.7)
        .background(Color("CardColor"))
        .cornerRadius(12)
        .padding(.vertical, 5)
//        .task {
//            if let unsafeUrl = story.url {
//                let url = vm.networkManager.getSecureUrlString(url: unsafeUrl)
//                vm.loadImage(fromUrl: url)
//            }
//        }
    }
    
    @ViewBuilder var smallNormalCardContent: some View {
        if let story = vm.story {
            VStack {
                
                VStack(alignment: .leading, spacing: 0) {
                    
                    // Domain Label
                    urlDomainLabel
                    
                    // Story Title label wrapped in a button
                    normalInteractiveTitleLabel
                    
                    // Meta info labels
                    normalMetaInfoLabel
                }
                .padding([.horizontal, .top])
                
                // Image
                
                CustomAsyncImageView(url: story.url, id: story.id, sizeType: .large)
                
                
                // Points and Actionable Buttons
                VStack {
                    HStack {
                        normalScoreLabel
                        
                        Spacer()
                        
                        HStack(spacing: 20) {
                            
                            bookmarkButton
                            
                            
                            // Share Button
                            shareButton
                            
                            //Comments Button
                            commentsLabel
                        }
                        .foregroundColor(Color("ButtonColor"))
                        .font(.subheadline.weight(.semibold))
                        
                    }
                    .padding()
                }
//                .overlay {
//                    GeometryReader { proxy in
//                        Color.clear
//                            .onAppear {
//                                imageWidth = proxy.frame(in: .local).width
//                            }
//                    }
//                }
            }
            .background(Color("CardColor"))
            .cornerRadius(12)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
    }
    
    @ViewBuilder var largeNormalCardContent: some View {
        if let story = vm.story {
            VStack {
                
                VStack(alignment: .leading, spacing: 0) {
                    
                    // Domain Label
                    urlDomainLabel
                    
                    // Story Title label wrapped in a button
                    normalInteractiveTitleLabel
                    
                    // Meta info labels
                    normalMetaInfoLabel
                }
                .padding([.horizontal, .top])
                
                // Image
                CustomAsyncImageView(url: story.url, id: story.id, sizeType: .large)
                
                
                // Points and Actionable Buttons
                VStack {
                    HStack {
                        normalScoreLabel
                        
                        Spacer()
                        
                        HStack(spacing: 20) {
                            
                            bookmarkButton
                            
                            
                            // Share Button
                            shareButton
                            
                            //Comments Button
                            commentsLabel
                        }
                        .foregroundColor(Color("ButtonColor"))
                        .font(.subheadline.weight(.semibold))
                        
                    }
                    .padding()
                }
//                .overlay {
//                    GeometryReader { proxy in
//                        Color.clear
//                            .onAppear {
//                                imageWidth = proxy.frame(in: .local).width
//                            }
//                    }
//                }
            }
            .frame(width: UIScreen.main.bounds.width * 0.7)
            .background(Color("CardColor"))
            .cornerRadius(12)
            .padding(.vertical, 5)
        }
    }
}

// Card Components
extension PostView {
    
    @ViewBuilder var bookmarkButton: some View {
        if vm.isBookmarked {
            Image(systemName: "bookmark.fill")
                .matchedGeometryEffect(id: "compactBookmarkButton", in: namespace)
        } else {
            Button {
                let bookmark = Bookmark(story: story)
                globalSettings.bookmarks.append(bookmark)
                withAnimation(.spring()) {
                    vm.isBookmarked = true
                }
            } label: {
                Image(systemName: "bookmark")
                    .matchedGeometryEffect(id: "compactBookmarkButton", in: namespace)
            }
            .createRegularButton()
        }
    }
    
    @ViewBuilder var urlDomainLabel: some View {
        if let url = story.url,
           let urlDomain = url.urlDomain {
            Text(urlDomain)
                .foregroundColor(.orange)
                .font(.caption.weight(.semibold))
                .padding(.bottom, 5)
        }
    }
    
    @ViewBuilder var compactInteractiveTitleLabel: some View {
        
        if story.url != nil {
            Button {
                selectedStory = story
            } label: {
                Text("\(story.title) \(Image(systemName: "arrow.up.forward.app"))")
//                    .foregroundColor(Color("PostTitle"))
                    .foregroundColor(.primary)
                    .font(.headline.weight(.bold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Circle())
            }
            .padding(.bottom, 5)
            .createRegularButton()
        } else {
            Text(story.title)
//                .foregroundColor(Color("PostTitle"))
                .foregroundColor(.primary)
                .font(.headline.weight(.bold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    @ViewBuilder var normalInteractiveTitleLabel: some View {
        if story.url != nil {
            Button {
                selectedStory = story
            } label: {
                Text("\(story.title) \(Image(systemName: "arrow.up.forward.app"))")
                    .font(.title3.weight(.bold))
//                    .foregroundColor(Color("PostTitle"))
                    .foregroundColor(.primary)
                    .padding(.bottom, 10)
                    .multilineTextAlignment(.leading)
            }
            .contentShape(Rectangle())
            .createRegularButton()
        } else {
            Text(story.title)
                .font(.title3.weight(.bold))
//                .foregroundColor(Color("PostTitle"))
                .foregroundColor(.primary)
                .padding(.bottom, 10)
                .multilineTextAlignment(.leading)
        }
        
        
    }
    
    var compactMetaInfoLabel: some View {
        HStack {
            Text(Date.getTimeInterval(with: story.time))
            Text("|")
                .foregroundColor(Color("DateNameSeparator"))
            Text(story.by)
            
            Spacer()
        }
//        .foregroundColor(Color("PostDateName"))
        .foregroundColor(.blue)
        .font(.caption.weight(.semibold))
    }
    
    var normalMetaInfoLabel: some View {
        HStack {
            Text(Date.getTimeInterval(with: story.time))
            Text("|")
                .foregroundColor(Color("DateNameSeparator"))
            Text(story.by)
            
            Spacer()
        }
//        .foregroundColor(Color("PostDateName"))
        .foregroundColor(.blue)
        .padding(.bottom, 16)
        .font(.caption.weight(.semibold))
    }
    
//    @ViewBuilder var compactImage: some View {
//        if let imageUrl = vm.imageUrl {
//            if let cachedImage = vm.imageCacheManager.getFromCache(withKey: String(story.id)) {
//                cachedImage
//                    .resizable()
//                    .scaledToFill()
//                    .frame(width: 100, height: 100)
//                    .clipped()
//                    .cornerRadius(8)
//                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
//            } else {
//                AsyncImage(url: imageUrl) { image in
//                    image
//                        .resizable()
//                        .scaledToFill()
//                        .frame(width: 100, height: 100)
//                        .clipped()
//                        .cornerRadius(8)
//                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
//                        .onAppear {
//                            vm.imageCacheManager.saveToCache(image, withKey: String(story.id))
//                        }
//                } placeholder: {
//                    ImagePlaceholderView(height: 100, width: 100)
//                }
//            }
//        }
//    }
    
//    @ViewBuilder var normalImage: some View {
//        if horizontalSizeClass == .compact && verticalSizeClass == .regular || horizontalSizeClass == .regular && verticalSizeClass == .compact {
//            if let imageUrl = vm.imageUrl {
//                if let cachedImage = vm.imageCacheManager.getFromCache(withKey: String(story.id)) {
//                    cachedImage
//                        .resizable()
//                        .scaledToFill()
//                        .frame(width: imageWidth)
//                        .frame(height: 270)
//                        .clipped()
//                } else {
//                    AsyncImage(url: imageUrl) { image in
//                        image
//                            .resizable()
//                            .scaledToFill()
//                            .frame(width: imageWidth)
//                            .frame(height: 270)
//                            .clipped()
//                            .onAppear {
//                                vm.imageCacheManager.saveToCache(image, withKey: String(story.id))
//                            }
//                    } placeholder: {
//                        ImagePlaceholderView(height: 270, width: imageWidth)
//                    }
//                }
//            }
//        } else if  horizontalSizeClass == .regular && verticalSizeClass == .regular {
//            if let imageUrl = vm.imageUrl {
//                if let cachedImage = vm.imageCacheManager.getFromCache(withKey: String(story.id)) {
//                    cachedImage
//                        .resizable()
//                        .scaledToFill()
//                        .frame(width: imageWidth)
//                        .frame(height: 400)
//                        .clipped()
//                } else {
//                    AsyncImage(url: imageUrl) { image in
//                        image
//                            .resizable()
//                            .scaledToFill()
//                            .frame(width: imageWidth)
//                            .frame(height: 400)
//                            .clipped()
//                            .onAppear {
//                                vm.imageCacheManager.saveToCache(image, withKey: String(story.id))
//                            }
//                    } placeholder: {
//                        ImagePlaceholderView(height: 400, width: imageWidth)
//                    }
//                }
//            }
//        }
//
//
//
//    }
    
    var compactScoreLabel: some View {
        Text(story.score == 1 ? "\(story.score) point" : "\(story.score.compressedNumber) points")
            .font(.subheadline.weight(.medium))
    }
    
    var normalScoreLabel: some View {
        Text(story.score == 1 ? "\(story.score) point" : "\(story.score.compressedNumber) points")
            .font(.headline.weight(.medium))
    }
    
    @ViewBuilder var shareButton: some View {
        if let url = story.url {
            ShareLink(item: vm.networkManager.getSecureUrlString(url: url)) {
                Image(systemName: "square.and.arrow.up")
            }
            .createRegularButton()
        }
    }
    
    @ViewBuilder var commentsLabel: some View {
        if let commentCount = story.descendants {
            HStack {
                Image(systemName: "bubble.right")
                Text(commentCount.compressedNumber)
            }
        }
    }
    
    var customSeparator: some View {
        Rectangle()
            .fill(Color("BackgroundColor"))
            .frame(height: 5)
    }
    
}

// Initializer
extension PostView {
    init(withWrapper wrapper: StoryWrapper, story: Story, selectedStory: Binding<Story?>) {
        self._vm = StateObject(wrappedValue: UltimatePostViewModel(withStory: story))
        self._wrapper = State(initialValue: wrapper)
        self._selectedStory = selectedStory
        self.story = story
    }
}

