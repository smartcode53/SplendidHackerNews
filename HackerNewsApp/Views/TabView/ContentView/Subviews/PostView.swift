//
//  PostView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/8/22.
//

import SwiftUI
import Glur

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
            let cornerRadius: CGFloat = 18
            let cardHeight: CGFloat = 330
            let topBlurHeight: CGFloat = 190
            let bottomBlurHeight: CGFloat = 170

            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    GeometryReader { proxy in
                        ZStack {
                            cardImage(for: story)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()

                            cardImage(for: story)
                                .glur(radius: 18.0, offset: 0.0, interpolation: 0.45, direction: .down, noise: 0.06, drawingGroup: true)
                                .mask(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .white, location: 0),
                                            .init(color: .white, location: 0.45),
                                            .init(color: .white.opacity(0.6), location: 0.7),
                                            .init(color: .white.opacity(0.25), location: 0.85),
                                            .init(color: .clear, location: 1)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .frame(height: topBlurHeight)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                )
                                .frame(width: proxy.size.width, height: proxy.size.height)

                            cardImage(for: story)
                                .glur(radius: 18.0, offset: 0.0, interpolation: 0.45, direction: .up, noise: 0.06, drawingGroup: true)
                                .mask(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .white, location: 0),
                                            .init(color: .white, location: 0.45),
                                            .init(color: .white.opacity(0.6), location: 0.7),
                                            .init(color: .white.opacity(0.25), location: 0.85),
                                            .init(color: .clear, location: 1)
                                        ],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                    .frame(height: bottomBlurHeight)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                )
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                    }

                    Rectangle()
                        .fill(Color.black.opacity(0.35))
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0),
                                    .init(color: .black, location: 0.5),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: topBlurHeight)
                        .frame(maxHeight: .infinity, alignment: .top)

                    Rectangle()
                        .fill(Color.black.opacity(0.35))
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0),
                                    .init(color: .black, location: 0.5),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: bottomBlurHeight)
                        .frame(maxHeight: .infinity, alignment: .bottom)

                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let unsafeUrl = story.url,
                               let urlDomain = vm.networkManager.getSecureUrlString(url: unsafeUrl).urlDomain {
                                Text(urlDomain)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.85))
                            }

                            Button {
                                if let url = story.url, let safe = URL(string: vm.networkManager.getSecureUrlString(url: url)) {
                                    openURL(safe, prefersInApp: true)
                                }
                                Task { await feedVM.openStory(story) }
                            } label: {
                                Text(story.url != nil ? "\(story.title) \(Image(systemName: "arrow.up.forward.app"))" : "\(story.title)")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.9)
                                    .opacity(isRead ? 0.55 : 1)
                                    .shadow(color: Color.black.opacity(0.6), radius: 10, x: 0, y: 4)
                                    .multilineTextAlignment(.leading)
                            }
                            .buttonStyle(.plain)

                            HStack(spacing: 6) {
                                Text(Date.getTimeInterval(with: story.time))
                                Text("•")
                                    .foregroundColor(.white.opacity(0.75))
                                Text(story.by)
                            }
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .opacity(isRead ? 0.55 : 1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        Spacer(minLength: 0)

                        let controlIconFont: Font = .system(size: 17, weight: .semibold)

                        HStack(spacing: 14) {
                            Text(story.score == 1 ? "\(story.score) point" : "\(story.score) points")
                                .font(.callout.weight(.semibold))
                                .foregroundColor(.white.opacity(0.85))

                            Spacer()

                            Button {
                                let bookmark = Bookmark(story: story)
                                globalSettings.tempBookmarks.append(bookmark)
                            } label: {
                                Image(systemName: "bookmark")
                                    .font(controlIconFont)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .contentShape(Rectangle())

                            if let unsafeUrl = story.url {
                                ShareLink(item: vm.networkManager.getSecureUrlString(url: unsafeUrl)) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(controlIconFont)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.white.opacity(0.9))
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                            }

                            CommentsButtonView(vm: vm) {
                                path.append(.comments(story))
                                Task { await feedVM.openComments(story) }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.white.opacity(0.9))
                            .font(controlIconFont)
                            .frame(height: 40)
                            .padding(.horizontal, 12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    if isRead {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                            .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                            .padding(10)
                    }
                }

            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.04), lineWidth: 1)
            )
            .task {
                if vm.imageUrl == nil && vm.cachedImage == nil, let unsafeUrl = story.url {
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
    @ViewBuilder
    private func cardImage(for story: Story) -> some View {
        if let cachedImage = vm.cachedImage {
            cachedImage
                .resizable()
                .scaledToFill()
        } else if let imageUrl = vm.imageUrl {
            AsyncImage(url: imageUrl, transaction: Transaction(animation: .easeInOut(duration: 0.25))) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(.thinMaterial)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .onAppear {
                            vm.cacheImageIfNeeded(image, storyId: story.id)
                        }
                case .failure:
                    Rectangle()
                        .fill(Color("CardColor"))
                @unknown default:
                    Rectangle()
                        .fill(Color("CardColor"))
                }
            }
        } else {
            Rectangle()
                .fill(Color("CardColor"))
        }
    }

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
