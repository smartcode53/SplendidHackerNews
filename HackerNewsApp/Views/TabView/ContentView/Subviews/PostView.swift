//
//  PostView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/8/22.
//

import SwiftUI
import UIKit

struct PostView: View {
    
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
#if DEBUG
    @EnvironmentObject var account: HNAccount
#endif
    @Environment(\.openURL) var openURL
    @StateObject var vm: UltimatePostViewModel
    let index: Int
    let isRead: Bool
    let isFeatured: Bool
    let onOpenStory: (Story) -> Void
    let onOpenComments: (Story) -> Void
    @Binding var path: [AppRoute]
    @State private var showVoteAlert = false
    @State private var voteAlertMessage = ""
    @State private var didVote = false
    @State private var isVoting = false
    @State private var showSavedToast = false
    @State private var savedToastDismissTask: Task<Void, Never>?

    
    
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
                compactImage(for: story)
                    .padding(.top, 4)

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
                    let isSaved = globalSettings.isStoryBookmarked(story.id)
                    
                    Spacer()
                    
                    // Save to bookmarks
                    Button {
                        handleBookmarkTap(story)
                    } label: {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .modifier(ControlPillModifier())
                    .opacity(isSaved ? 0.55 : 1)
                    .disabled(isSaved)
                    
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
                        onOpenComments(story)
                    }, accessibilityIdentifier: "feed.row.\(story.id).comments", showCount: false)
                    .modifier(ControlPillModifier())

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
                onOpenComments(story)
            }
            .onDisappear {
                savedToastDismissTask?.cancel()
                savedToastDismissTask = nil
            }
            .overlay(alignment: .topLeading) {
                Text("Feed Row")
                    .font(.caption2)
                    .opacity(0.01)
                    .accessibilityLabel("Feed Row \(story.id)")
                    .accessibilityIdentifier("feed.row.\(story.id)")
            }
            .overlay(alignment: .topTrailing) {
                if showSavedToast {
                    savedToast
                        .padding(.top, 10)
                        .padding(.trailing, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
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
                    cardImage(for: story)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .saturation(isRead ? 0.2 : 1)
                        .brightness(isRead ? -0.05 : 0)

                    Rectangle()
                        .fill(Color.black.opacity(0.30))
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0),
                                    .init(color: .black, location: 0.55),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: topBlurHeight)
                        .frame(maxHeight: .infinity, alignment: .top)

                    Rectangle()
                        .fill(Color.black.opacity(0.33))
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0),
                                    .init(color: .black, location: 0.55),
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
                            let isSaved = globalSettings.isStoryBookmarked(story.id)

                            HStack(spacing: 14) {
                                Button {
                                    handleBookmarkTap(story)
                                } label: {
                                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
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
                                .opacity(isSaved ? 0.55 : 1)
                                .disabled(isSaved)

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
                                    onOpenComments(story)
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
            .onDisappear {
                savedToastDismissTask?.cancel()
                savedToastDismissTask = nil
            }
            .overlay(alignment: .topLeading) {
                Text("Feed Row")
                    .font(.caption2)
                    .opacity(0.01)
                    .accessibilityLabel("Feed Row \(story.id)")
                    .accessibilityIdentifier("feed.row.\(story.id)")
            }
            .overlay(alignment: .topTrailing) {
                if showSavedToast {
                    savedToast
                        .padding(.top, 10)
                        .padding(.trailing, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
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
    private var savedToast: some View {
        Label("Saved", systemImage: "bookmark.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @MainActor
    private func handleBookmarkTap(_ story: Story) {
        let didSave = globalSettings.addBookmarkIfNeeded(story: story)
        guard didSave else { return }

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            showSavedToast = true
        }

        savedToastDismissTask?.cancel()
        savedToastDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                showSavedToast = false
            }
        }
    }

    private func openSourceDestination(_ story: Story) {
        if let url = story.url, let safe = URL(string: vm.networkManager.getSecureUrlString(url: url)) {
            openURL(safe, prefersInApp: true)
        }
        onOpenStory(story)
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

    @ViewBuilder
    private func compactImage(for story: Story) -> some View {
        let height: CGFloat = 180

        if let cachedImage = vm.cachedImage {
            compactImageContainer(height: height) {
                cachedImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        } else if vm.imageAvailability != .available {
            EmptyView()
        } else if let imageUrl = vm.imageUrl {
            compactImageContainer(height: height) {
                AsyncImage(url: imageUrl, transaction: Transaction(animation: .easeInOut(duration: 0.25))) { phase in
                    switch phase {
                    case .empty:
                        CompactImagePlaceholder()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .onAppear {
                                vm.cacheImageIfNeeded(image, storyId: story.id)
                            }
                    case .failure:
                        CompactImagePlaceholder()
                    @unknown default:
                        CompactImagePlaceholder()
                    }
                }
            }
        } else {
            compactImageContainer(height: height) {
                CompactImagePlaceholder()
            }
        }
    }

    @ViewBuilder
    private func compactImageContainer<Content: View>(
        height: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .contentShape(Rectangle())
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
    
    init(
        withStory story: Story,
        index: Int,
        isRead: Bool,
        path: Binding<[AppRoute]>,
        onOpenStory: @escaping (Story) -> Void = { _ in },
        onOpenComments: @escaping (Story) -> Void = { _ in }
    ) {
        self._vm = StateObject(wrappedValue: UltimatePostViewModel(withStory: story))
        self.index = index
        self.isRead = isRead
        self.isFeatured = false
        self.onOpenStory = onOpenStory
        self.onOpenComments = onOpenComments
        self._path = path
    }

    init(
        withStory story: Story,
        index: Int,
        isRead: Bool,
        isFeatured: Bool,
        path: Binding<[AppRoute]>,
        onOpenStory: @escaping (Story) -> Void = { _ in },
        onOpenComments: @escaping (Story) -> Void = { _ in }
    ) {
        self._vm = StateObject(wrappedValue: UltimatePostViewModel(withStory: story))
        self.index = index
        self.isRead = isRead
        self.isFeatured = isFeatured
        self.onOpenStory = onOpenStory
        self.onOpenComments = onOpenComments
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

private struct CompactImagePlaceholder: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color("CardColor").opacity(0.65),
                Color("CardColor").opacity(0.4)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                .padding(10)
        }
    }
}

//struct PostView_Previews: PreviewProvider {
//    static var previews: some View {
//        PostView()
//    }
//}
