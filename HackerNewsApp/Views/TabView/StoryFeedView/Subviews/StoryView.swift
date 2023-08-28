//
//  PostView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/8/22.
//

import SwiftUI

struct StoryView: View {
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    @EnvironmentObject var nav: GlobalNavigator
    
    @Namespace var namespace
    
    @StateObject var storyVm: StoryViewModel
    @State private var wrapper: StoryWrapper
    @State private var imageWidth: CGFloat = UIScreen.main.bounds.width
    @State private var imageLoaded: Bool = false
    @State var bindedCommentCount: Int? = nil
    @State var bindedPostPoints: Int? = nil
    @Binding var selectedStory: Story?
    
    let story: Story
    
    // Body
    var body: some View {
        CustomNavLink {
            CommentsView(vm: storyVm, bindedCommentCount: $bindedCommentCount, bindedPostPoints: $bindedPostPoints)
                .customNavBarItems(title: "Comments", backButtonHidden: false)
        } label: {
            if globalSettings.selectedCardStyle == .normal {
                normalCard
            } else {
                compactCard
            }
        }
        .createPressableButton()
        .onAppear(perform: updateBookmarkStatus)
        .onChange(of: bindedCommentCount, perform: updateCommentCount)
        .onChange(of: bindedPostPoints, perform: updateStoryPoints)
    }
}

// MARK: Card Styles
extension StoryView {
    
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

// MARK: Card Styles based on device and their respective orientations
extension StoryView {
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
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
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
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
    }
    
    @ViewBuilder var smallNormalCardContent: some View {
        if let story = storyVm.story {
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
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        }
    }
    
    @ViewBuilder var largeNormalCardContent: some View {
        if let story = storyVm.story {
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
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        }
    }
}

// MARK: Card Components
extension StoryView {
    
    @ViewBuilder var bookmarkButton: some View {
        if storyVm.isBookmarked {
            Image(systemName: "bookmark.fill")
                .matchedGeometryEffect(id: "compactBookmarkButton", in: namespace)
        } else {
            Button {
                let bookmark = Bookmark(story: story)
                globalSettings.bookmarks.append(bookmark)
                withAnimation(.spring()) {
                    storyVm.isBookmarked = true
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
            Text("\(story.title) \(Image(systemName: "arrow.up.forward.app"))")
                .foregroundColor(.primary)
                .font(.headline.weight(.bold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedStory = story
                }
                .padding(.bottom, 5)
        } else {
            Text(story.title)
                .foregroundColor(.primary)
                .font(.headline.weight(.bold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 5)
        }
    }
    
    @ViewBuilder var normalInteractiveTitleLabel: some View {
        if story.url != nil {
            Text("\(story.title) \(Image(systemName: "arrow.up.forward.app"))")
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)
                .padding(.bottom, 10)
                .multilineTextAlignment(.leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedStory = story
                }
                .createRegularButton()
        } else {
            Text(story.title)
                .font(.title3.weight(.bold))
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
        .foregroundColor(.blue)
        .padding(.bottom, 16)
        .font(.caption.weight(.semibold))
    }
    
    
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
            ShareLink(item: storyVm.networkManager.getSecureUrlString(url: url)) {
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

// MARK: Initializer
extension StoryView {
    init(withWrapper wrapper: StoryWrapper, story: Story, selectedStory: Binding<Story?>, storyFeedVm: FeedViewModel) {
        self._storyVm = StateObject(wrappedValue: StoryViewModel(withStory: story, storyFeedVm: storyFeedVm))
        self._wrapper = State(initialValue: wrapper)
        self._selectedStory = selectedStory
        self.story = story
    }
}

// MARK: Functions
extension StoryView {
    private func updateCommentCount(_ count: Int?) {
        if count != nil {
            let currentStoryType = storyVm.storyFeedVm.storyType
            var storyArray = storyVm.storyFeedVm.cacheManager.getFromCache(withKey: currentStoryType.rawValue)
            if storyArray != nil {
                var currentStory = storyArray!.filter { wrapper in
                    wrapper.id == self.wrapper.id
                }[0]
                currentStory.story?.descendants = count
                storyArray!.removeAll { wrapper in
                    wrapper.id == self.wrapper.id
                }
                storyArray!.append(currentStory)
                storyArray!.sort { wrapper1, wrapper2 in
                    wrapper1.index < wrapper2.index
                }
                storyVm.storyFeedVm.cacheManager.removeFromCache(key: currentStoryType.rawValue)
                storyVm.storyFeedVm.cacheManager.saveToCache(storyArray!, withKey: currentStoryType.rawValue)
            }
            bindedCommentCount = nil
        }
    }
    
    private func updateStoryPoints(_ count: Int?) {
        if count != nil {
            let currentStoryType = storyVm.storyFeedVm.storyType
            var storyArray = storyVm.storyFeedVm.cacheManager.getFromCache(withKey: currentStoryType.rawValue)
            if storyArray != nil {
                var currentStory = storyArray!.filter { wrapper in
                    wrapper.id == self.wrapper.id
                }[0]
                currentStory.story?.score = count!
                storyArray!.removeAll { wrapper in
                    wrapper.id == self.wrapper.id
                }
                storyArray!.append(currentStory)
                storyArray!.sort { wrapper1, wrapper2 in
                    wrapper1.index < wrapper2.index
                }
                storyVm.storyFeedVm.cacheManager.removeFromCache(key: currentStoryType.rawValue)
                storyVm.storyFeedVm.cacheManager.saveToCache(storyArray!, withKey: currentStoryType.rawValue)
            }
            bindedPostPoints = nil
        }
    }
    
    private func updateBookmarkStatus() {
        storyVm.updateBookmarkStatus(globalSettings: globalSettings, story: story)
    }
}



