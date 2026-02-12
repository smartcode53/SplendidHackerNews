//
//  CommentsView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/26/22.
//

import SwiftUI

struct CommentsView<T>: View where T: CommentsButtonProtocol, T: SafariViewLoader {
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject var vm: T
    var onOpenReader: ((Story) -> Void)? = nil
    @StateObject private var threadVM = CommentsThreadViewModel()
    @State private var searchText = ""
    @State private var didAttemptRestore = false
    @State private var showResume = false
    @State private var pendingLastSeenID: Int?
    @State private var lastSeenTask: Task<Void, Never>?
    @State private var restoreTask: Task<Void, Never>?
    @State private var headerImageURL: URL?
    @State private var headerImageAvailability: Bool?
    @State private var scrollOffsetY: CGFloat = 0
    @State private var initialHeaderMinY: CGFloat?
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
                    .onPreferenceChange(CommentsHeaderMinYPreferenceKey.self) { minY in
                        if initialHeaderMinY == nil {
                            initialHeaderMinY = minY
                        }
                        if let initialHeaderMinY {
                            scrollOffsetY = max(0, initialHeaderMinY - minY)
                        }
                    }
                    .overlay(alignment: .top) {
                        compactHeader(for: story)
                    }
                    .task(id: story.id) {
                        await threadVM.loadComments(using: vm, storyID: story.id)
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
                    .onChange(of: vm.comments?.children?.count ?? 0) { _, _ in
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
            .navigationDestination(isPresented: $vm.showStoryInComments) {
                SafariView(vm: vm, url: story.url)
            }
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
        let progress = headerCollapseProgress
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                headerImageBackground
                    .scaleEffect(x: 1 - (0.12 * progress), y: 1 - (0.08 * progress), anchor: .center)
                    .offset(y: -18 * progress)
                    .opacity(1 - progress)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            if let urlDomain = story.url?.urlDomain {
                Text(urlDomain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 10) {
                headerThumbnail(size: 44)
                    .opacity(progress)
                    .scaleEffect(0.85 + (0.15 * progress), anchor: .leading)
                    .animation(.easeInOut(duration: 0.15), value: progress)

                Text(story.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }

            HStack(spacing: 8) {
                Text(Date.getTimeInterval(with: story.time))
                Text("|")
                    .foregroundStyle(.tertiary)
                Text(story.by)
                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text(story.score == 1 ? "\(story.score) point" : "\(story.score) points")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                if let storyUrl = story.url {
                    Button {
                        onOpenReader?(story)
                    } label: {
                        Image(systemName: "text.book.closed")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button {
                        vm.showStoryInComments = true
                    } label: {
                        Image(systemName: "safari")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    ShareLink(item: storyUrl) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: CommentsHeaderMinYPreferenceKey.self,
                    value: geo.frame(in: .global).minY
                )
            }
        )
    }

    @ViewBuilder
    private func compactHeader(for story: Story) -> some View {
        let progress = headerCollapseProgress
        if progress > 0.001 {
            HStack(spacing: 10) {
                headerThumbnail(size: 44)

                Text(story.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .opacity(min(1, max(0, (progress - 0.45) / 0.55)))
            .scaleEffect(0.92 + (0.08 * progress), anchor: .top)
            .animation(.easeInOut(duration: 0.18), value: progress)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func headerThumbnail(size: CGFloat) -> some View {
        ZStack {
            headerImage(for: headerImageURL)
        }
        .frame(width: size, height: size)
        .clipped()
        .clipShape(.rect(cornerRadius: 10))
    }

    private var headerCollapseProgress: CGFloat {
        let collapseDistance: CGFloat = 200
        return max(0, min(1, scrollOffsetY / collapseDistance))
    }

    @ViewBuilder
    private func headerImage(for url: URL?) -> some View {
        if let url {
            AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        } else {
            headerPlaceholder
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
    }

    private var headerImageBackground: some View {
        headerImage(for: headerImageURL)
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

private struct CommentsHeaderMinYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
        _ = proxy
        didAttemptRestore = true
        showResume = false
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
            threadVM.applySearch(query: searchText)
        }
        .onChange(of: vm.comments?.children?.count ?? 0) { _, _ in
            if let comments = vm.comments?.children {
                Task { await threadVM.setComments(comments) }
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
            if !threadVM.visibleRows.isEmpty || vm.comments?.children?.isEmpty == false {
                #if DEBUG
                if debug.fixtureMode {
                    VStack(spacing: 0) {
                        ForEach(threadVM.visibleRows) { row in
                            SingleCommentView(
                                comment: row.comment,
                                threadVM: threadVM,
                                indentLevel: row.depth,
                                descendantCount: row.descendantCount
                            )
                            .id(row.id)
                            .onAppear {
                                scheduleLastSeenUpdate(commentID: row.id)
                            }
                        }
                    }
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(threadVM.visibleRows) { row in
                            SingleCommentView(
                                comment: row.comment,
                                threadVM: threadVM,
                                indentLevel: row.depth,
                                descendantCount: row.descendantCount
                            )
                            .id(row.id)
                            .onAppear {
                                scheduleLastSeenUpdate(commentID: row.id)
                            }
                        }
                    }
                }
                #else
                LazyVStack(spacing: 0) {
                    ForEach(threadVM.visibleRows) { row in
                        SingleCommentView(
                            comment: row.comment,
                            threadVM: threadVM,
                            indentLevel: row.depth,
                            descendantCount: row.descendantCount
                        )
                        .id(row.id)
                        .onAppear {
                            scheduleLastSeenUpdate(commentID: row.id)
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
