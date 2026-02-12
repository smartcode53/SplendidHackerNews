//
//  ContentView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import SwiftUI

struct ContentView: View {
    
    // MARK: ContentView Properties
    @Binding var path: [AppRoute]
    @StateObject var vm = ContentViewModel()
    @Namespace var namespace
    @State var showComments: Bool = false
    @State private var didAttemptRestore = false
    @State private var showResume = false
    @State private var pendingLastSeenID: Int?
    @State private var lastSeenTask: Task<Void, Never>?
#if DEBUG
    @ObservedObject private var debug = DebugEnvironment.shared
#endif
    
    
    // MARK: ContentView Body
    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .ignoresSafeArea()
            
            scrollView
        }
        .navigationTitle("\(vm.storyType.rawValue)")
        .navigationBarTitleDisplayMode(.automatic)
        .task {
            await vm.loadInitial()
        }
#if DEBUG
        .onChange(of: debug.fixtureRefreshToken) { _, _ in
            Task {
                if debug.fixtureMode {
                    await vm.applyFixtureIfNeeded()
                } else {
                    await vm.refresh()
                }
            }
        }
        .onAppear {
            if debug.fixtureMode {
                Task { await vm.applyFixtureIfNeeded() }
            }
        }
#endif
        .onChange(of: vm.storyType) { _, _ in
            didAttemptRestore = false
            showResume = false
        }
    }
}

extension ContentView  {
    private var hideReadBinding: Binding<Bool> {
        Binding(
            get: { vm.hideRead },
            set: { vm.setHideRead($0) }
        )
    }

    private func handleOpenStory(_ story: Story) {
        Task { await vm.openStory(story) }
    }

    private func handleOpenComments(_ story: Story) {
        Task { await vm.openComments(story) }
    }
    
    // MARK: Story array
//    var newPosts: some View {
//        LazyVStack {
//            if !vm.storiesToDisplay.isEmpty {
//                ForEach(Array(zip(vm.stories.indices, vm.stories)), id: \.0) { index, story in
//                    PostView(withStory: story, selectedStory: $selectedStory, index: index)
////                            .task {
////                                if index == vm.stories.count - 1 {
////                                    await vm.altLoadInfinitely()
////                                }
////                            }
//                }
//            } else {
//                ProgressView()
//            }
//
//            if vm.isLoading {
//                ProgressView()
//                    .padding()
//            }
//        }
//        .task {
//            await vm.altLoadStoriesTheFirstTime()
//        }
//        .fullScreenCover(item: $selectedStory) { story in
//            if let storyUrl = story.url {
//                SafariView(vm: vm, url: storyUrl)
//            }
//        }
//    }
    
    var altNewPosts: some View {
        EmptyView()
    }
    
//    var listPosts: some View {
//        List {
//
//            Rectangle()
//                .fill(Color.clear)
//                .frame(maxWidth: .infinity)
//                .frame(height: 2)
//                .listRowInsets(.none)
//                .listRowBackground(Color.clear)
//                .listRowSeparator(.hidden)
//
//            if !vm.storiesToDisplay.isEmpty {
//                ForEach(Array(zip(vm.stories.indices, vm.stories)), id: \.0) { (index, story) in
//                    PostView(withStory: story, selectedStory: $selectedStory, index: index)
////                        .onAppear {
////                            print("current index: \(index), stories count: \(vm.topStories.count)")
////                            if index == vm.topStories.count - 1 {
////                                vm.loadInfinitely()
////                            }
////                        }
//
////                    if vm.isLoading {
////                        ProgressView()
////                    }
//                }
//                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
//                .listRowSeparator(.hidden)
//                .listRowBackground(Color.clear)
//            } else {
//                HStack {
//                    Spacer()
//
//                    ProgressView()
//
//
//                    Spacer()
//                }
//                .listRowBackground(Color.clear)
//                .listRowSeparator(.hidden)
//
//            }
//        }
////        .refreshable {
////            vm.refreshStories()
////        }
//        .listStyle(.plain)
//        .scrollContentBackground(.hidden)
//        .environment(\.defaultMinListRowHeight, 5)
//        .overlay(
//            Rectangle()
//                .fill(.primary)
//                .frame(height: 2)
//            ,
//            alignment: .top
//        )
//        .task {
//            await vm.altLoadStoriesTheFirstTime()
//        }
////        .fullScreenCover(item: $selectedStory) { story in
////            if let storyUrl = story.url {
////                SafariView(vm: vm, url: storyUrl)
////            }
////        }
//        .navigationTitle(Text(vm.storyType.rawValue))
//        .navigationBarTitleDisplayMode(.automatic)
//        .toolbarBackground(Color("CardColor"), for: .navigationBar)
//        .toolbarBackground(.visible, for: .navigationBar)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Menu("Switch Feed") {
//                    ForEach(StoryType.allCases, id: \.self) { type in
//                        Button(type.rawValue) {
//                            vm.storyType = type
//                        }
//                    }
//                }
//                .tint(.orange)
//            }
//        }
//    }
    
    @ViewBuilder
    var scrollView: some View {
        if vm.stories.isEmpty {
            feedEmptyState
        } else {
            ScrollViewReader { proxy in
                #if DEBUG
                if debug.fixtureMode {
                    fixtureScrollView(proxy: proxy)
                } else {
                    regularListView(proxy: proxy)
                }
                #else
                regularListView(proxy: proxy)
                #endif
            }
        }
    }

    private func regularListView(proxy: ScrollViewProxy) -> some View {
        List {
            if let refreshErrorMessage = vm.refreshErrorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(refreshErrorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if showResume {
                HStack {
                    Button("Resume") {
                        didAttemptRestore = false
                        Task { await attemptRestore(proxy: proxy) }
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if !vm.stories.isEmpty {
                ForEach(Array(vm.stories.enumerated()), id: \.element.id) { index, story in
                    PostView(
                        withStory: story,
                        index: index + 1,
                        isRead: vm.isRead(story.id),
                        isFeatured: false,
                        path: $path,
                        onOpenStory: handleOpenStory,
                        onOpenComments: handleOpenComments
                    )
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .onAppear {
                            scheduleLastSeenUpdate(storyID: story.id)
                        }

                    if index == 2 {
                        featuredRow
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 10, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }

                Color.clear
                    .frame(height: 1)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .onAppear {
                        Task { await vm.loadNextPage() }
                    }
            } else if vm.isLoading || vm.isRefreshing {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if vm.isLoading && !vm.stories.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if case .error(let message, let canRetry) = vm.loadMoreState, canRetry {
                LoadMoreRetryRow(message: message) {
                    Task { await vm.loadNextPage() }
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("feed.list")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(StoryType.allCases, id: \.self) { type in
                        Button(type.rawValue) {
                            vm.setStoryType(type)
                        }
                    }

                    Divider()

                    Toggle("Hide Read", isOn: hideReadBinding)
                        .accessibilityIdentifier("feed.hideRead")
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .accessibilityLabel("Switch Feed")
                }
                .tint(.accentColor)
                .accessibilityIdentifier("feed.selector")
            }
        }
        .refreshable {
            await vm.refresh()
        }
        .onChange(of: vm.stories.count) { _, _ in
            Task { await attemptRestore(proxy: proxy) }
        }
        .onAppear {
            Task { await attemptRestore(proxy: proxy) }
        }
    }

    #if DEBUG
    private func fixtureScrollView(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(vm.stories.enumerated()), id: \.element.id) { index, story in
                    PostView(
                        withStory: story,
                        index: index + 1,
                        isRead: vm.isRead(story.id),
                        isFeatured: false,
                        path: $path,
                        onOpenStory: handleOpenStory,
                        onOpenComments: handleOpenComments
                    )
                        .onAppear {
                            scheduleLastSeenUpdate(storyID: story.id)
                        }

                    if index == 2 {
                        featuredRow
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 20)
        }
        .accessibilityIdentifier("feed.list")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(StoryType.allCases, id: \.self) { type in
                        Button(type.rawValue) {
                            vm.setStoryType(type)
                        }
                    }

                    Divider()

                    Toggle("Hide Read", isOn: hideReadBinding)
                        .accessibilityIdentifier("feed.hideRead")
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .accessibilityLabel("Switch Feed")
                }
                .tint(.accentColor)
                .accessibilityIdentifier("feed.selector")
            }
        }
    }
    #endif
    
    var bookmarkConfirmationView: some View {
        VStack {
            Image(systemName: "checkmark.seal")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding()
        .padding()
        .background(Material.regularMaterial)
        .cornerRadius(12)
    }

    private var featuredRow: some View {
        let rowStories = featuredStories
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Spotlight")
                    .font(.headline)
                Spacer()
                Text("Show HN mix")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(rowStories, id: \.id) { story in
                        PostView(
                            withStory: story,
                            index: 0,
                            isRead: vm.isRead(story.id),
                            isFeatured: true,
                            path: $path,
                            onOpenStory: handleOpenStory,
                            onOpenComments: handleOpenComments
                        )
                            .frame(width: 280)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .padding(.vertical, 10)
    }

    private var featuredStories: [Story] {
        let showHN = vm.stories.filter { story in
            story.title.localizedCaseInsensitiveContains("show hn")
        }
        if !showHN.isEmpty {
            return Array(showHN.prefix(10))
        }
        return Array(vm.stories.prefix(10))
    }

    @ViewBuilder
    private var feedEmptyState: some View {
        switch vm.initialLoadState {
        case .idle, .loading:
            ProgressView("Loading stories...")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            LoadStateView(
                title: "No stories yet.",
                message: "Pull to refresh or try again."
            ) {
                Task { await vm.refresh() }
            }
        case .error(let message, let canRetry):
            LoadStateView(
                title: "Couldn't load stories.",
                message: message,
                retryAction: canRetry ? { Task { await vm.refresh() } } : nil
            )
        case .loaded:
            EmptyView()
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(path: .constant([]))
    }
}

extension ContentView {
    private func scheduleLastSeenUpdate(storyID: Int) {
        pendingLastSeenID = storyID
        lastSeenTask?.cancel()
        lastSeenTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            guard let id = pendingLastSeenID else { return }
            await FeedScrollStore.shared.setLastSeen(feed: vm.storyType, storyID: id)
        }
    }

    @MainActor
    private func attemptRestore(proxy: ScrollViewProxy) async {
        guard !didAttemptRestore else { return }
        guard !vm.stories.isEmpty else { return }
        guard !vm.isLoading && !vm.isRefreshing else { return }

        didAttemptRestore = true
        showResume = false

        let lastSeen = await FeedScrollStore.shared.getLastSeen(feed: vm.storyType)
        guard let lastSeen else { return }

        if vm.hideRead && vm.isRead(lastSeen) {
            if let firstID = vm.stories.first?.id {
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(firstID, anchor: .top)
                }
            }
            return
        }

        if vm.stories.contains(where: { $0.id == lastSeen }) {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(lastSeen, anchor: .top)
            }
            return
        }

        let found = await vm.ensureStoryLoaded(targetID: lastSeen, maxPages: 5)
        if found {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(lastSeen, anchor: .top)
            }
        } else {
            showResume = true
        }
    }
}

struct LoadStateView: View {
    let title: String
    let message: String?
    let retryTitle: String
    let retryAction: (() -> Void)?

    init(title: String, message: String? = nil, retryTitle: String = "Retry", retryAction: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let retryAction {
                Button(retryTitle) {
                    retryAction()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LoadMoreRetryRow: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        Button {
            retryAction()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.accentColor)
                Text(message)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("feed.loadMore.retry")
    }
}
