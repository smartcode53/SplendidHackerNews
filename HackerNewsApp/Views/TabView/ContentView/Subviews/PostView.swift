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
#if DEBUG
    @EnvironmentObject var account: HNAccount
#endif
    @Environment(\.openURL) var openURL
    @StateObject var vm: UltimatePostViewModel
    let index: Int
    let isRead: Bool
    let isFeatured: Bool
    @Binding var path: [AppRoute]
    @State private var showVoteAlert = false
    @State private var voteAlertMessage = ""
    @State private var didVote = false
    @State private var isVoting = false

    
    
    var body: some View {
        if isFeatured {
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
            VStack(spacing: 8) {
                if let imageView = compactImage(for: story) {
                    imageView
                        .padding(.top, 4)
                }

                VStack(alignment: .leading, spacing: 0) {
                    if let unsafeUrl = story.url,
                        let urlDomain = vm.networkManager.getSecureUrlString(url: unsafeUrl).urlDomain {
                        Text(urlDomain)
                            .foregroundColor(.accentColor)
                            .font(.caption.weight(.semibold))
                            .padding(.bottom, 5)
                    }
                    
                    Button {
                        openSourceDestination(story)
                    } label: {
                        titleLabel(for: story)
                            .padding(.bottom, 10)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("feed.row.\(story.id).open")
                        
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
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .modifier(ControlPillModifier())
                    
                    // Share button
                    
                    if let unsafeUrl = story.url {
                        ShareLink(item: vm.networkManager.getSecureUrlString(url: unsafeUrl)) {
                            Image(systemName: "square.and.arrow.up")
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                        .modifier(ControlPillModifier())
                    }
                    
                    // Comment Button
                    CommentsButtonView(vm: vm, action: {
                        path.append(.comments(story))
                        Task { await feedVM.openComments(story) }
                    }, accessibilityIdentifier: "feed.row.\(story.id).comments", showCount: false)
                    .modifier(ControlPillModifier())

                    Button {
                        openReaderDestination(story)
                    } label: {
                        Image(systemName: "text.book.closed")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .modifier(ControlPillModifier())
                    .disabled(story.url == nil)

#if DEBUG
                    if globalSettings.isHNWriteEnabled && account.isLoggedIn {
                        Button {
                            Task { await handleStoryVote(storyId: story.id) }
                        } label: {
                            Image(systemName: "arrow.up")
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.plain)
                        .modifier(ControlPillModifier())
                        .opacity(didVote ? 0.4 : 1)
                        .disabled(didVote || isVoting)
                    }
#endif
                    
                }
                Divider()
                    .overlay(Color.primary.opacity(0.08))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .task {
                if let unsafeUrl = story.url {
                    let url = vm.networkManager.getSecureUrlString(url: unsafeUrl)
                    await vm.loadImage(fromUrl: url)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                path.append(.comments(story))
                Task { await feedVM.openComments(story) }
            }
            .overlay(alignment: .topLeading) {
                Text("Feed Row")
                    .font(.caption2)
                    .opacity(0.01)
                    .accessibilityLabel("Feed Row \(story.id)")
                    .accessibilityIdentifier("feed.row.\(story.id)")
            }
            .alert("Vote", isPresented: $showVoteAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(voteAlertMessage)
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
                        let size = proxy.size
                        ZStack {
                            cardImage(for: story)
                                .frame(width: size.width, height: size.height)
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
                                .frame(width: size.width, height: size.height)

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
                                .frame(width: size.width, height: size.height)
                        }
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .saturation(isRead ? 0.2 : 1)
                        .brightness(isRead ? -0.05 : 0)
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
                        openSourceDestination(story)
                    } label: {
                        Text(story.title)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)
                            .shadow(color: Color.black.opacity(0.6), radius: 10, x: 0, y: 4)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("feed.row.\(story.id).open")

                            HStack(spacing: 6) {
                                Text(Date.getTimeInterval(with: story.time))
                                Text("•")
                                    .foregroundColor(.white.opacity(0.75))
                                Text(story.by)
                            }
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        Spacer(minLength: 0)

                        let controlIconFont: Font = .system(size: 17, weight: .semibold)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(story.score == 1 ? "\(story.score) point" : "\(story.score) points")
                                .font(.callout.weight(.semibold))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)

                            HStack(spacing: 14) {
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

                                CommentsButtonView(vm: vm, action: {
                                    path.append(.comments(story))
                                    Task { await feedVM.openComments(story) }
                                }, accessibilityIdentifier: "feed.row.\(story.id).comments")
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
                                Spacer(minLength: 0)
                            }

#if DEBUG
                            if globalSettings.isHNWriteEnabled && account.isLoggedIn {
                                Button {
                                    Task { await handleStoryVote(storyId: story.id) }
                                } label: {
                                    Image(systemName: "arrow.up")
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
                                .opacity(didVote ? 0.4 : 1)
                                .disabled(didVote || isVoting)
                            }
#endif
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
                .overlay(alignment: .topLeading) {
                    if isRead {
                        Text("Read")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .padding(12)
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
                    await vm.loadImage(fromUrl: url)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                openSourceDestination(story)
            }
            .overlay(alignment: .topLeading) {
                Text("Feed Row")
                    .font(.caption2)
                    .opacity(0.01)
                    .accessibilityLabel("Feed Row \(story.id)")
                    .accessibilityIdentifier("feed.row.\(story.id)")
            }
            .alert("Vote", isPresented: $showVoteAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(voteAlertMessage)
            }
        }

    }
    
}

#if DEBUG
extension PostView {
    @MainActor
    private func handleStoryVote(storyId: Int) async {
        guard !isVoting else { return }
        isVoting = true
        didVote = true
        do {
            let result = try await account.upvoteStory(id: storyId)
            switch result {
            case .voted:
                break
            case .alreadyVoted:
                voteAlertMessage = "Already voted."
                showVoteAlert = true
            case .verificationFailed:
                didVote = false
                voteAlertMessage = "Vote sent, but verification failed."
                showVoteAlert = true
            }
        } catch {
            didVote = false
            voteAlertMessage = error.localizedDescription
            showVoteAlert = true
            HNDebugLog.error("Story upvote failed: \(error)")
        }
        isVoting = false
    }
}
#endif

extension PostView {
    private func openSourceDestination(_ story: Story) {
        if let url = story.url, let safe = URL(string: vm.networkManager.getSecureUrlString(url: url)) {
            openURL(safe, prefersInApp: true)
        }
        Task { await feedVM.openStory(story) }
    }

    private func openReaderDestination(_ story: Story) {
        guard story.url != nil else { return }
        path.append(.reader(story))
        Task { await feedVM.openStory(story) }
    }

    @ViewBuilder
    private func cardImage(for story: Story) -> some View {
        ZStack {
            if let cachedImage = vm.cachedImage {
                cachedImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let imageUrl = vm.imageUrl {
                AsyncImage(url: imageUrl, transaction: Transaction(animation: .easeInOut(duration: 0.25))) { phase in
                    switch phase {
                    case .empty:
                        CardPlaceholderPattern()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .onAppear {
                                vm.cacheImageIfNeeded(image, storyId: story.id)
                            }
                    case .failure:
                        CardPlaceholderPattern()
                    @unknown default:
                        CardPlaceholderPattern()
                    }
                }
            } else {
                CardPlaceholderPattern()
            }
        }
    }

    private func compactImage(for story: Story) -> AnyView? {
        let height: CGFloat = 180

        if let cachedImage = vm.cachedImage {
            return AnyView(
                GeometryReader { proxy in
                    cachedImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width, height: height)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                }
                .frame(height: height)
                .contentShape(Rectangle())
            )
        }

        guard vm.imageAvailability == .available else {
            return nil
        }

        if let imageUrl = vm.imageUrl {
            return AnyView(
                GeometryReader { proxy in
                    AsyncImage(url: imageUrl, transaction: Transaction(animation: .easeInOut(duration: 0.25))) { phase in
                        switch phase {
                        case .empty:
                            CardPlaceholderPattern()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .onAppear {
                                    vm.cacheImageIfNeeded(image, storyId: story.id)
                                }
                        case .failure:
                            CardPlaceholderPattern()
                        @unknown default:
                            CardPlaceholderPattern()
                        }
                    }
                    .frame(width: proxy.size.width, height: height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
                .frame(height: height)
                .contentShape(Rectangle())
            )
        }

        return AnyView(
            GeometryReader { proxy in
                CardPlaceholderPattern()
                    .frame(width: proxy.size.width, height: height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }
            .frame(height: height)
        )
    }

    private func titleLabel(for story: Story) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(story.title)
                .foregroundColor(.primary)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if story.url != nil {
                Image(systemName: "arrow.up.right.square")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        self.isFeatured = false
        self._path = path
    }

    init(withStory story: Story, index: Int, isRead: Bool, isFeatured: Bool, path: Binding<[AppRoute]>) {
        self._vm = StateObject(wrappedValue: UltimatePostViewModel(withStory: story))
        self.index = index
        self.isRead = isRead
        self.isFeatured = isFeatured
        self._path = path
    }
}

private struct ControlPillModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.callout.weight(.semibold))
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color("BackgroundColor"))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .frame(minWidth: 44, minHeight: 36)
    }
}

private struct CardPlaceholderPattern: View {
    private let base = Color(red: 0.88, green: 0.95, blue: 0.92)
    private let accent = Color(red: 0.55, green: 0.75, blue: 0.70)
    private let accent2 = Color(red: 0.70, green: 0.82, blue: 0.78)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [base, base.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Canvas { context, size in
                    let cell: CGFloat = 80
                    for x in stride(from: 0, through: size.width + cell, by: cell) {
                        for y in stride(from: 0, through: size.height + cell, by: cell) {
                            let origin = CGPoint(x: x, y: y)
                            let phase = (x + y).truncatingRemainder(dividingBy: 160) / 160
                            let color = phase < 0.5 ? accent.opacity(0.18) : accent2.opacity(0.18)

                            var circle = Path()
                            circle.addEllipse(in: CGRect(x: origin.x + 10, y: origin.y + 8, width: 18, height: 18))
                            context.fill(circle, with: .color(color))

                            var rounded = Path()
                            rounded.addRoundedRect(in: CGRect(x: origin.x + 36, y: origin.y + 14, width: 26, height: 12), cornerSize: CGSize(width: 6, height: 6))
                            context.fill(rounded, with: .color(color))

                            var squiggle = Path()
                            squiggle.move(to: CGPoint(x: origin.x + 12, y: origin.y + 46))
                            squiggle.addCurve(
                                to: CGPoint(x: origin.x + 56, y: origin.y + 46),
                                control1: CGPoint(x: origin.x + 24, y: origin.y + 34),
                                control2: CGPoint(x: origin.x + 44, y: origin.y + 58)
                            )
                            context.stroke(squiggle, with: .color(color), lineWidth: 2)

                            var capsule = Path()
                            capsule.addRoundedRect(in: CGRect(x: origin.x + 18, y: origin.y + 58, width: 40, height: 10), cornerSize: CGSize(width: 5, height: 5))
                            context.fill(capsule, with: .color(color))
                        }
                    }
                }
                .blendMode(.overlay)
            }
        }
        .clipped()
    }
}

//struct PostView_Previews: PreviewProvider {
//    static var previews: some View {
//        PostView()
//    }
//}
