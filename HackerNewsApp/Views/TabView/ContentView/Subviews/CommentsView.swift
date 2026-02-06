//
//  CommentsView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/26/22.
//

import SwiftUI
import Glur

struct CommentsView<T>: View where T: CommentsButtonProtocol, T: SafariViewLoader {
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject var vm: T
    @StateObject private var threadVM = CommentsThreadViewModel()
    @State private var searchText = ""
    @State private var didAttemptRestore = false
    @State private var showResume = false
    @State private var pendingLastSeenID: Int?
    @State private var lastSeenTask: Task<Void, Never>?
    @State private var restoreTask: Task<Void, Never>?
    @State private var headerImageURL: URL?
    @State private var headerImageAvailability: Bool?
    @State private var showSearch = false
    @FocusState private var isSearchFocused: Bool
#if DEBUG
    @ObservedObject private var debug = DebugEnvironment.shared
#endif
    
    
    var body: some View {
        if let story = vm.story {
            VStack(spacing: 0) {
                
                ScrollViewReader { proxy in
                    ScrollView {
                        if showSearch {
                            searchBar
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                        }

                        headerView(for: story)
                            .padding(.bottom, 8)

                        commentControls()

                        if showResume {
                            HStack {
                                Button("Resume") {
                                    didAttemptRestore = false
                                    Task { await attemptRestore(proxy: proxy) }
                                }
                                .buttonStyle(.bordered)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }

                        // Visual divider
                        Rectangle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)

                        // Comment count
                        if let commentCount = story.descendants {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(commentCount == 1 ? "\(commentCount) comment" : "\(commentCount) comments")
                                        .font(.title3.weight(.semibold))
                                        .foregroundColor(.primary)

                                    Text("Tap thread lines to collapse")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                        }

                        VStack(spacing: 0) {
                            commentsContent
                        }
                        .padding(.horizontal, 12)
                    }
                    .background(Color("BackgroundColor"))
                    .onAppear {
                        Task { await threadVM.loadComments(using: vm, storyID: story.id) }
                    }
                    .task {
                        await loadHeaderImageIfNeeded(for: story)
                    }
                    .task {
                        if vm.comments != nil {
                            if let (numComments, points) = await vm.getCommentAndPointCounts(forPostWithId: story.id) {
                                vm.story?.descendants = numComments
                                vm.story?.score = points
                            }
                        }
                    }
                    .onChange(of: vm.comments?.children?.count ?? 0) { _ in
                        scheduleRestore(proxy: proxy)
                    }
                    .onAppear {
                        scheduleRestore(proxy: proxy)
                    }
                    .onDisappear {
                        restoreTask?.cancel()
                        restoreTask = nil
                    }
                }
            }
            .background(Color("BackgroundColor"))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Comments View")
            .accessibilityIdentifier("comments.view")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSearch.toggle()
                        if showSearch {
                            isSearchFocused = true
                        } else {
                            searchText = ""
                            isSearchFocused = false
                        }
                    } label: {
                        Image(systemName: showSearch ? "xmark.circle.fill" : "magnifyingglass")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .accessibilityIdentifier("comments.search.toggle")
                }
            }
            .background(
                NavigationLink(destination: SafariView(vm: vm, url: story.url), isActive: $vm.showStoryInComments) {
                    EmptyView()
                }
                .hidden()
            )
        }
    }
}

extension CommentsView {
    private func loadHeaderImageIfNeeded(for story: Story) async {
        guard headerImageAvailability == nil else { return }
        guard let storyUrl = story.url else {
            headerImageAvailability = false
            return
        }
        let availabilityCache = UltimatePostViewModel.ImageAvailabilityCache.instance
        let urlCache = UltimatePostViewModel.ImageURLCache.instance
        let key = String(story.id)

        if let cachedURL = urlCache.getFromCache(withKey: key) {
            headerImageURL = cachedURL
            headerImageAvailability = true
            return
        }

        if let cachedAvailability = availabilityCache.getFromCache(withKey: key), cachedAvailability == false {
            headerImageAvailability = false
            return
        }

        let resultUrl = await vm.networkManager.getImage(fromUrl: storyUrl)
        headerImageURL = resultUrl
        headerImageAvailability = resultUrl != nil
        if let resultUrl {
            urlCache.saveToCache(resultUrl, withKey: key)
            availabilityCache.saveToCache(true, withKey: key)
        } else {
            availabilityCache.saveToCache(false, withKey: key)
        }
    }

    @ViewBuilder
private func headerView(for story: Story) -> some View {
    let heroHeight: CGFloat = 280
    let overlayHeight: CGFloat = 140
    let topBlurHeight: CGFloat = 190
    let bottomBlurHeight: CGFloat = 170
    let isHero = headerImageAvailability == true
    let primaryColor: Color = isHero ? .white : .primary
    let secondaryColor: Color = isHero ? .white.opacity(0.85) : .secondary

    ZStack(alignment: .bottom) {
        if isHero {
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    headerImageBackground
                        .frame(width: size.width, height: size.height)
                        .clipped()

                    headerImageBackground
                        .glur(radius: 28.0, offset: 0.0, interpolation: 0.55, direction: .up, noise: 0.06, drawingGroup: true)
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
            }
            .frame(maxWidth: .infinity, minHeight: heroHeight, maxHeight: heroHeight)
            .ignoresSafeArea(edges: .top)
        } else {
            Color("BackgroundColor")
                .frame(maxWidth: .infinity, minHeight: heroHeight, maxHeight: heroHeight)
                .ignoresSafeArea(edges: .top)
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
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(height: bottomBlurHeight)
            .frame(maxHeight: .infinity, alignment: .bottom)

        VStack(alignment: .leading, spacing: 0) {
            if let urlDomain = story.url?.urlDomain {
                Text(urlDomain)
                    .foregroundColor(isHero ? .white.opacity(0.9) : .accentColor)
                    .font(.caption.weight(.semibold))
                    .padding(.bottom, 5)
            }

            Text(story.title)
                .font(.title3.weight(.semibold))
                .padding(.bottom, 8)
                .foregroundColor(primaryColor)
                .shadow(color: isHero ? Color.black.opacity(0.35) : .clear, radius: 8, x: 0, y: 3)

            HStack {
                Text(Date.getTimeInterval(with: story.time))
                Text("|")
                    .foregroundColor(secondaryColor)
                Text(story.by)
                Spacer()
            }
            .foregroundColor(secondaryColor)
            .font(.subheadline)

            HStack {
                Text(story.score == 1 ? "\(story.score) point" : "\(story.score) points")
                    .foregroundColor(secondaryColor)
                    .font(.headline)
                Spacer()
                if let storyUrl = story.url {
                    Button {
                        vm.showStoryInComments = true
                    } label: {
                        Image(systemName: "safari")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                    ShareLink(item: storyUrl) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, minHeight: overlayHeight, maxHeight: overlayHeight, alignment: .bottom)
    }
}

    @ViewBuilder
    private var headerImageBackground: some View {
        if let headerImageURL {
            AsyncImage(url: headerImageURL, transaction: Transaction(animation: .easeInOut(duration: 0.25))) { phase in
                switch phase {
                case .empty:
                    headerPlaceholder
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    headerPlaceholder
                @unknown default:
                    headerPlaceholder
                }
            }
            .clipped()
        } else {
            headerPlaceholder
        }
    }

    private var headerPlaceholder: some View {
        LinearGradient(
            colors: [
                Color("CardColor"),
                Color("CardColor").opacity(0.6)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension CommentsView {
    private func scheduleLastSeenUpdate(commentID: Int) {
        pendingLastSeenID = commentID
        lastSeenTask?.cancel()
        lastSeenTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            guard let id = pendingLastSeenID, let storyId = vm.story?.id else { return }
            await CommentsScrollStore.shared.setLastSeen(storyID: storyId, commentID: id)
        }
    }

    @MainActor
    private func attemptRestore(proxy: ScrollViewProxy) async {
        didAttemptRestore = true
        showResume = false
        return
        guard !didAttemptRestore else { return }
        guard let storyId = vm.story?.id else { return }
        guard let comments = vm.comments?.children, !comments.isEmpty else { return }

        didAttemptRestore = true
        showResume = false

        let lastSeen = await CommentsScrollStore.shared.getLastSeen(storyID: storyId)
        guard let lastSeen else { return }

        let topLevelIDs = comments.map { $0.id }
        if topLevelIDs.contains(lastSeen) {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(lastSeen, anchor: .top)
            }
        } else {
            showResume = true
        }
    }
    @ViewBuilder
    private func commentControls() -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    threadVM.collapseTopLevel()
                } label: {
                    Label("Collapse All", systemImage: "rectangle.compress.vertical")
                }
                .buttonStyle(.plain)
                .modifier(CommentsControlPillModifier())
                .accessibilityIdentifier("comments.collapseAll")

                Button {
                    threadVM.expandTopLevel()
                } label: {
                    Label("Expand All", systemImage: "rectangle.expand.vertical")
                }
                .buttonStyle(.plain)
                .modifier(CommentsControlPillModifier())
                .accessibilityIdentifier("comments.expandAll")

                Spacer()
            }
            
            if !searchText.isEmpty {
                HStack {
                    Text("\(threadVM.matchCount) matches")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .task(id: searchText) {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if let comments = vm.comments?.children {
                threadVM.setComments(comments)
                threadVM.applySearch(query: searchText)
            }
        }
        .onChange(of: vm.comments?.children?.count ?? 0) { _ in
            if let comments = vm.comments?.children {
                threadVM.setComments(comments)
            }
        }
    }
}

extension CommentsView {
    private func scheduleRestore(proxy: ScrollViewProxy) {
        restoreTask?.cancel()
        restoreTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            await attemptRestore(proxy: proxy)
        }
    }
}

extension CommentsView {
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search comments", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isSearchFocused)
                .accessibilityIdentifier("comments.search")

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color("CardColor"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct CommentsControlPillModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .frame(minHeight: 36)
    }
}

extension CommentsView {
    @ViewBuilder
    private var commentsContent: some View {
        switch threadVM.loadState {
        case .idle, .loading:
            ProgressView("Loading comments...")
                .foregroundColor(.secondary)
                .padding(.top, 12)
        case .empty:
            LoadStateView(
                title: "No comments yet.",
                message: "Be the first to comment.",
                retryTitle: "Reload"
            ) {
                Task { await reloadComments() }
            }
        case .error(let message, let canRetry):
            LoadStateView(
                title: "Couldn't load comments.",
                message: message,
                retryAction: canRetry ? { Task { await reloadComments() } } : nil
            )
        case .loaded:
            if let comments = vm.comments?.children {
                #if DEBUG
                if debug.fixtureMode {
                    VStack(spacing: 0) {
                        ForEach(comments) { comment in
                            if threadVM.isVisible(comment.id) {
                                SingleCommentView(comment: comment, threadVM: threadVM, indentLevel: 0)
                                    .id(comment.id)
                                    .onAppear {
                                        scheduleLastSeenUpdate(commentID: comment.id)
                                    }
                            }
                        }
                    }
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(comments) { comment in
                            if threadVM.isVisible(comment.id) {
                                SingleCommentView(comment: comment, threadVM: threadVM, indentLevel: 0)
                                    .id(comment.id)
                                    .onAppear {
                                        scheduleLastSeenUpdate(commentID: comment.id)
                                    }
                            }
                        }
                    }
                }
                #else
                LazyVStack(spacing: 0) {
                    ForEach(comments) { comment in
                        if threadVM.isVisible(comment.id) {
                            SingleCommentView(comment: comment, threadVM: threadVM, indentLevel: 0)
                                .id(comment.id)
                                .onAppear {
                                    scheduleLastSeenUpdate(commentID: comment.id)
                                }
                        }
                    }
                }
                #endif
            }
        }
    }

    private func reloadComments() async {
        guard let story = vm.story else { return }
        await threadVM.loadComments(using: vm, storyID: story.id)
    }
}
