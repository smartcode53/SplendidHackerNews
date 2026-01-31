//
//  PostView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/8/22.
//

import SwiftUI

struct PostView: View {
    
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    @EnvironmentObject var feedVM: ContentViewModel
    @Environment(\.openURL) var openURL
    @StateObject var vm: UltimatePostViewModel
    let index: Int
    let isRead: Bool
    @Binding var path: [AppRoute]

    
    
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
                        let urlDomain = vm.networkManager.getSecureUrlString(url: unsafeUrl).urlDomain {
                        Text(urlDomain)
                            .foregroundColor(.accentColor)
                            .font(.caption.weight(.semibold))
                            .padding(.bottom, 5)
                    }
                    
                    Text(story.url != nil ? "\(story.title) \(Image(systemName: "arrow.up.forward.app"))" : "\(story.title)")
                            .foregroundColor(.primary)
                            .font(.title3.weight(.semibold))
                            .padding(.bottom, 10)
                            .opacity(isRead ? 0.55 : 1)
                            .onTapGesture {
                                if let url = story.url, let safe = URL(string: vm.networkManager.getSecureUrlString(url: url)) {
                                    openURL(safe, prefersInApp: true)
                                }
                                Task { await feedVM.openStory(story) }
                            }
                        
                        HStack {
                            Text(Date.getTimeInterval(with: story.time))
                            Text("|")
                                .foregroundColor(.secondary)
                            Text(story.by)
                            
                            Spacer()
                        }
                        .foregroundColor(.secondary)
                        .padding(.bottom, 16)
                        .font(.subheadline)
                        .opacity(isRead ? 0.55 : 1)
                        
                    }
                    
                    Spacer()
                    
                    AsyncImage(url: vm.imageUrl) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipped()
                    } placeholder: {
                        EmptyView()
                    }
                    .onTapGesture {
                        if let url = story.url, let safe = URL(string: vm.networkManager.getSecureUrlString(url: url)) {
                            openURL(safe, prefersInApp: true)
                        }
                        Task { await feedVM.openStory(story) }
                    }
                    
                }
                
                HStack {
                    Text(story.score == 1 ? "\(story.score) point" : "\(story.score) points")
                        .font(.callout.weight(.medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    //Bookmark Delete Button
                    Button {
                        
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    
                    // Share button
                    
                    if let unsafeUrl = story.url {
                        ShareLink(item: vm.networkManager.getSecureUrlString(url: unsafeUrl)) {
                            Image(systemName: "square.and.arrow.up")
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .tint(.accentColor)
                    }
                    
                    // Comment Button
                    CommentsButtonView(vm: vm) {
                        path.append(.comments(story))
                        Task { await feedVM.openComments(story) }
                    }
                    
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(Color("CardColor"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.vertical, 2)
            .task {
                if let unsafeUrl = story.url {
                    let url = vm.networkManager.getSecureUrlString(url: unsafeUrl)
                    vm.loadImage(fromUrl: url)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                path.append(.comments(story))
                Task { await feedVM.openComments(story) }
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
                       let urlDomain = vm.networkManager.getSecureUrlString(url: unsafeUrl).urlDomain {
                        Text(urlDomain)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.accentColor)
                            .padding(.bottom, 10)
                    }
                    
                    // Story Title
                    
                    Text(story.url != nil ? "\(story.title) \(Image(systemName: "arrow.up.forward.app"))" : "\(story.title)")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.primary)
                            .padding(.bottom, 16)
                            .opacity(isRead ? 0.55 : 1)
                            .onTapGesture {
                                if let url = story.url, let safe = URL(string: vm.networkManager.getSecureUrlString(url: url)) {
                                    openURL(safe, prefersInApp: true)
                                }
                                Task { await feedVM.openStory(story) }
                            }
                    
                    
                    
                    // Meta info
                    HStack {
                        Text(Date.getTimeInterval(with: story.time))
                        Text("|")
                            .foregroundColor(.secondary)
                        Text(story.by)
                        
                        Spacer()
                    }
                    .foregroundColor(.secondary)
                    .padding(.bottom, 16)
                    .font(.subheadline)
                    .opacity(isRead ? 0.55 : 1)
                }
                .padding([.horizontal, .top])
                
                if let imageUrl = vm.imageUrl {
                    RemoteImageView(url: imageUrl, height: 200)
                        .onTapGesture {
                            if let url = story.url, let safe = URL(string: vm.networkManager.getSecureUrlString(url: url)) {
                                openURL(safe, prefersInApp: true)
                            }
                            Task { await feedVM.openStory(story) }
                        }
                }
                
                
                // Story Image
                    
                
                // Points and Actionable Buttons
                VStack {
                    HStack {
                        Text(story.score == 1 ? "\(story.score) point" : "\(story.score) points")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        //Bookmark Button
                        Button {
                            let bookmark = Bookmark(story: story)
                            globalSettings.tempBookmarks.append(bookmark)
                        } label: {
                            Image(systemName: "bookmark")
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .tint(.accentColor)
                        
                        // Share Button
                        if let unsafeUrl = story.url
                           {
                            ShareLink(item: vm.networkManager.getSecureUrlString(url: unsafeUrl)) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                            .tint(.accentColor)
                        }
                    
                        //Comments Button
                        CommentsButtonView(vm: vm) {
                            path.append(.comments(story))
                            Task { await feedVM.openComments(story) }
                        }
                        
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color("CardColor"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .task {
                if let unsafeUrl = story.url {
                    let url = vm.networkManager.getSecureUrlString(url: unsafeUrl)
                    vm.loadImage(fromUrl: url)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                path.append(.comments(story))
                Task { await feedVM.openComments(story) }
            }
        }

    }
    
}

extension PostView {
    private struct RemoteImageView: View {
        let url: URL
        let height: CGFloat
        
        var body: some View {
            GeometryReader { proxy in
                ZStack {
                    Rectangle()
                        .fill(.thinMaterial)
                    
                    AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: proxy.size.width, height: height)
                        case .failure:
                            EmptyView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                .frame(width: proxy.size.width, height: height)
                .clipped()
            }
            .frame(height: height)
        }
    }
    
    init(withStory story: Story, index: Int, isRead: Bool, path: Binding<[AppRoute]>) {
        self._vm = StateObject(wrappedValue: UltimatePostViewModel(withStory: story))
        self.index = index
        self.isRead = isRead
        self._path = path
    }
}

//struct PostView_Previews: PreviewProvider {
//    static var previews: some View {
//        PostView()
//    }
//}
