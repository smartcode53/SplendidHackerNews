//
//  ContentView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import SwiftUI
import UIKit
import Combine

struct ContentView: View {
    
    // MARK: ContentView Properties
    @Binding var path: [AppRoute]
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
#if DEBUG
    @EnvironmentObject var account: HNAccount
#endif
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
        scrollView
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
        Group {
#if DEBUG
            FeedUIKitScreen(
                vm: vm,
                path: $path,
                globalSettings: globalSettings,
                account: account,
                onOpenStory: handleOpenStory,
                onOpenComments: handleOpenComments,
                onSetStoryType: vm.setStoryType,
                onSetHideRead: vm.setHideRead,
                storyTypeProvider: { vm.storyType },
                hideReadProvider: { vm.hideRead },
                isRead: vm.isRead,
                featuredStoriesProvider: { featuredStories }
            )
#else
            FeedUIKitScreen(
                vm: vm,
                path: $path,
                globalSettings: globalSettings,
                onOpenStory: handleOpenStory,
                onOpenComments: handleOpenComments,
                onSetStoryType: vm.setStoryType,
                onSetHideRead: vm.setHideRead,
                storyTypeProvider: { vm.storyType },
                hideReadProvider: { vm.hideRead },
                isRead: vm.isRead,
                featuredStoriesProvider: { featuredStories }
            )
#endif
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

struct FeedUIKitScreen: UIViewControllerRepresentable {
    @ObservedObject var vm: ContentViewModel
    @Binding var path: [AppRoute]
    let globalSettings: GlobalSettingsViewModel
#if DEBUG
    let account: HNAccount
#endif
    let onOpenStory: (Story) -> Void
    let onOpenComments: (Story) -> Void
    let onSetStoryType: (StoryType) -> Void
    let onSetHideRead: (Bool) -> Void
    let storyTypeProvider: () -> StoryType
    let hideReadProvider: () -> Bool
    let isRead: (Int) -> Bool
    let featuredStoriesProvider: () -> [Story]

    func makeUIViewController(context: Context) -> FeedUIKitViewController {
        FeedUIKitViewController(
            vm: vm,
            path: $path,
            onOpenStory: onOpenStory,
            onOpenComments: onOpenComments,
            onSetStoryType: onSetStoryType,
            onSetHideRead: onSetHideRead,
            storyTypeProvider: storyTypeProvider,
            hideReadProvider: hideReadProvider,
            isRead: isRead,
            featuredStoriesProvider: featuredStoriesProvider,
            postViewBuilder: { story, index, isFeatured in
                makePostView(story: story, index: index, isFeatured: isFeatured)
            }
        )
    }

    func updateUIViewController(_ uiViewController: FeedUIKitViewController, context: Context) {
        uiViewController.updateBindings(
            path: $path,
            onOpenStory: onOpenStory,
            onOpenComments: onOpenComments,
            onSetStoryType: onSetStoryType,
            onSetHideRead: onSetHideRead,
            storyTypeProvider: storyTypeProvider,
            hideReadProvider: hideReadProvider,
            isRead: isRead,
            featuredStoriesProvider: featuredStoriesProvider,
            postViewBuilder: { story, index, isFeatured in
                makePostView(story: story, index: index, isFeatured: isFeatured)
            }
        )
    }

    private func makePostView(story: Story, index: Int, isFeatured: Bool) -> AnyView {
        let baseView = PostView(
            withStory: story,
            index: index,
            isRead: isRead(story.id),
            isFeatured: isFeatured,
            path: $path,
            onOpenStory: onOpenStory,
            onOpenComments: onOpenComments
        )
        .environmentObject(globalSettings)

#if DEBUG
        return AnyView(baseView.environmentObject(account))
#else
        return AnyView(baseView)
#endif
    }
}

@MainActor
final class FeedUIKitViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITableViewDataSourcePrefetching {
    private enum FeedRow {
        case refreshError(String)
        case resume
        case story(index: Int, story: Story)
        case featured([Story])
        case loadTrigger
        case loading
        case loadMoreError(String)
    }

    private let vm: ContentViewModel
    private var path: Binding<[AppRoute]>
    private var onOpenStory: (Story) -> Void
    private var onOpenComments: (Story) -> Void
    private var onSetStoryType: (StoryType) -> Void
    private var onSetHideRead: (Bool) -> Void
    private var storyTypeProvider: () -> StoryType
    private var hideReadProvider: () -> Bool
    private var isRead: (Int) -> Bool
    private var featuredStoriesProvider: () -> [Story]
    private var postViewBuilder: (Story, Int, Bool) -> AnyView

    private var rows: [FeedRow] = []
    private var cancellables: Set<AnyCancellable> = []
    private var didAttemptRestore = false
    private var showResume = false
    private var pendingLastSeenID: Int?
    private var lastSeenTask: Task<Void, Never>?
    private var isTriggerLoadVisible = false

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let refreshControl = UIRefreshControl()

    init(
        vm: ContentViewModel,
        path: Binding<[AppRoute]>,
        onOpenStory: @escaping (Story) -> Void,
        onOpenComments: @escaping (Story) -> Void,
        onSetStoryType: @escaping (StoryType) -> Void,
        onSetHideRead: @escaping (Bool) -> Void,
        storyTypeProvider: @escaping () -> StoryType,
        hideReadProvider: @escaping () -> Bool,
        isRead: @escaping (Int) -> Bool,
        featuredStoriesProvider: @escaping () -> [Story],
        postViewBuilder: @escaping (Story, Int, Bool) -> AnyView
    ) {
        self.vm = vm
        self.path = path
        self.onOpenStory = onOpenStory
        self.onOpenComments = onOpenComments
        self.onSetStoryType = onSetStoryType
        self.onSetHideRead = onSetHideRead
        self.storyTypeProvider = storyTypeProvider
        self.hideReadProvider = hideReadProvider
        self.isRead = isRead
        self.featuredStoriesProvider = featuredStoriesProvider
        self.postViewBuilder = postViewBuilder
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation()
        configureTableView()
        bindViewModel()
        rebuildRows()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.prefersLargeTitles = true
        applyNavigationItems()
    }

    private func configureNavigation() {
        navigationItem.largeTitleDisplayMode = .automatic
        applyNavigationItems()
    }

    private func applyNavigationItems() {
        let selectorImage = UIImage(systemName: "line.3.horizontal.decrease.circle")
        let menuButton = UIBarButtonItem(image: selectorImage, menu: makeFeedMenu())

        navigationItem.title = vm.storyType.rawValue
        navigationItem.rightBarButtonItem = menuButton

        parent?.navigationItem.title = vm.storyType.rawValue
        parent?.navigationItem.largeTitleDisplayMode = .automatic
        parent?.navigationItem.rightBarButtonItem = UIBarButtonItem(image: selectorImage, menu: makeFeedMenu())
    }

    func updateBindings(
        path: Binding<[AppRoute]>,
        onOpenStory: @escaping (Story) -> Void,
        onOpenComments: @escaping (Story) -> Void,
        onSetStoryType: @escaping (StoryType) -> Void,
        onSetHideRead: @escaping (Bool) -> Void,
        storyTypeProvider: @escaping () -> StoryType,
        hideReadProvider: @escaping () -> Bool,
        isRead: @escaping (Int) -> Bool,
        featuredStoriesProvider: @escaping () -> [Story],
        postViewBuilder: @escaping (Story, Int, Bool) -> AnyView
    ) {
        self.path = path
        self.onOpenStory = onOpenStory
        self.onOpenComments = onOpenComments
        self.onSetStoryType = onSetStoryType
        self.onSetHideRead = onSetHideRead
        self.storyTypeProvider = storyTypeProvider
        self.hideReadProvider = hideReadProvider
        self.isRead = isRead
        self.featuredStoriesProvider = featuredStoriesProvider
        self.postViewBuilder = postViewBuilder
        rebuildRows()
    }

    private func configureTableView() {
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = true
        tableView.contentInsetAdjustmentBehavior = .automatic
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 168
        tableView.prefetchDataSource = self
        tableView.isPrefetchingEnabled = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FeedHostingCell")
        tableView.accessibilityIdentifier = "feed.list"

        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func bindViewModel() {
        vm.$stories
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildRows()
            }
            .store(in: &cancellables)

        vm.$isLoading
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildRows()
            }
            .store(in: &cancellables)

        vm.$isRefreshing
            .receive(on: RunLoop.main)
            .sink { [weak self] isRefreshing in
                guard let self else { return }
                if !isRefreshing, self.refreshControl.isRefreshing {
                    self.refreshControl.endRefreshing()
                }
                self.rebuildRows()
            }
            .store(in: &cancellables)

        vm.$refreshErrorMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildRows()
            }
            .store(in: &cancellables)

        vm.$loadMoreState
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildRows()
            }
            .store(in: &cancellables)

        vm.$hideRead
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.applyNavigationItems()
            }
            .store(in: &cancellables)

        vm.$storyType
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] newType in
                guard let self else { return }
                self.didAttemptRestore = false
                self.showResume = false
                self.navigationItem.title = newType.rawValue
                self.applyNavigationItems()
                self.rebuildRows()
            }
            .store(in: &cancellables)
    }

    private func rebuildRows() {
        var newRows: [FeedRow] = []

        if vm.stories.isEmpty {
            rows = []
            tableView.reloadData()
            applyEmptyBackground()
            return
        }

        tableView.backgroundView = nil

        if let refreshErrorMessage = vm.refreshErrorMessage {
            newRows.append(.refreshError(refreshErrorMessage))
        }

        if showResume {
            newRows.append(.resume)
        }

        for (index, story) in vm.stories.enumerated() {
            newRows.append(.story(index: index + 1, story: story))
            if index == 2 {
                let featuredStories = featuredStoriesProvider()
                if !featuredStories.isEmpty {
                    newRows.append(.featured(featuredStories))
                }
            }
        }

        if !vm.stories.isEmpty {
            newRows.append(.loadTrigger)
        }

        if vm.isLoading && !vm.stories.isEmpty {
            newRows.append(.loading)
        }

        if case .error(let message, let canRetry) = vm.loadMoreState, canRetry {
            newRows.append(.loadMoreError(message))
        }

        rows = newRows
        tableView.reloadData()
        attemptRestoreIfNeeded()
    }

    private func applyEmptyBackground() {
        switch vm.initialLoadState {
        case .idle, .loading:
            let stack = UIStackView()
            stack.axis = .vertical
            stack.alignment = .center
            stack.spacing = 10

            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            let label = UILabel()
            label.text = "Loading stories..."
            label.textColor = .secondaryLabel
            label.font = .preferredFont(forTextStyle: .body)

            stack.addArrangedSubview(spinner)
            stack.addArrangedSubview(label)
            tableView.backgroundView = stack

        case .empty:
            tableView.backgroundView = makeStateBackground(
                title: "No stories yet.",
                message: "Pull to refresh or try again.",
                retryTitle: "Retry"
            ) { [weak self] in
                guard let self else { return }
                Task { await self.vm.refresh() }
            }

        case .error(let message, let canRetry):
            tableView.backgroundView = makeStateBackground(
                title: "Couldn't load stories.",
                message: message,
                retryTitle: canRetry ? "Retry" : nil
            ) { [weak self] in
                guard let self else { return }
                Task { await self.vm.refresh() }
            }

        case .loaded:
            tableView.backgroundView = nil
        }
    }

    private func makeStateBackground(
        title: String,
        message: String?,
        retryTitle: String?,
        retryAction: @escaping () -> Void
    ) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.isLayoutMarginsRelativeArrangement = true

        let image = UIImageView(image: UIImage(systemName: "exclamationmark.triangle"))
        image.tintColor = .secondaryLabel
        image.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 32)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        stack.addArrangedSubview(image)
        stack.addArrangedSubview(titleLabel)

        if let message {
            let messageLabel = UILabel()
            messageLabel.text = message
            messageLabel.font = .preferredFont(forTextStyle: .subheadline)
            messageLabel.textColor = .secondaryLabel
            messageLabel.textAlignment = .center
            messageLabel.numberOfLines = 0
            stack.addArrangedSubview(messageLabel)
        }

        if let retryTitle {
            let retryButton = UIButton(type: .system)
            retryButton.setTitle(retryTitle, for: .normal)
            retryButton.configuration = .borderedProminent()
            retryButton.addAction(UIAction { _ in retryAction() }, for: .touchUpInside)
            stack.addArrangedSubview(retryButton)
        }

        return stack
    }

    private func makeFeedMenu() -> UIMenu {
        let storyActions = StoryType.allCases.map { type in
            UIAction(
                title: type.rawValue,
                state: storyTypeProvider() == type ? .on : .off
            ) { [weak self] _ in
                self?.onSetStoryType(type)
            }
        }

        let hideReadAction = UIAction(
            title: "Hide Read",
            state: hideReadProvider() ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            self.onSetHideRead(!self.hideReadProvider())
        }

        return UIMenu(children: storyActions + [hideReadAction])
    }

    @objc private func handleRefresh() {
        Task {
            await vm.refresh()
            refreshControl.endRefreshing()
        }
    }

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

    private func attemptRestoreIfNeeded() {
        guard !didAttemptRestore else { return }
        guard !vm.stories.isEmpty else { return }
        guard !vm.isLoading && !vm.isRefreshing else { return }

        didAttemptRestore = true
        showResume = false

        Task { [weak self] in
            guard let self else { return }
            let lastSeen = await FeedScrollStore.shared.getLastSeen(feed: self.vm.storyType)
            guard let lastSeen else { return }

            if self.vm.hideRead && self.vm.isRead(lastSeen) {
                if let firstStoryID = self.vm.stories.first?.id {
                    _ = self.scrollToStory(withID: firstStoryID, animated: true)
                }
                return
            }

            if self.scrollToStory(withID: lastSeen, animated: true) {
                return
            }

            let found = await self.vm.ensureStoryLoaded(targetID: lastSeen, maxPages: 5)
            guard !Task.isCancelled else { return }
            if found {
                self.rebuildRows()
                _ = self.scrollToStory(withID: lastSeen, animated: true)
            } else {
                self.showResume = true
                self.rebuildRows()
            }
        }
    }

    private func scrollToStory(withID storyID: Int, animated: Bool) -> Bool {
        guard let rowIndex = rows.firstIndex(where: { row in
            if case .story(_, let story) = row {
                return story.id == storyID
            }
            return false
        }) else {
            return false
        }

        tableView.scrollToRow(at: IndexPath(row: rowIndex, section: 0), at: .top, animated: animated)
        return true
    }

    private func hostingConfiguration<Content: View>(@ViewBuilder _ content: () -> Content) -> UIHostingConfiguration<Content, EmptyView> {
        UIHostingConfiguration {
            content()
        }
        .margins(.all, 0)
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FeedHostingCell", for: indexPath)
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear

        switch rows[indexPath.row] {
        case .refreshError(let message):
            cell.contentConfiguration = hostingConfiguration {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.top, 6)
                .padding(.bottom, 6)
                .padding(.leading, 20)
                .padding(.trailing, 20)
            }

        case .resume:
            cell.contentConfiguration = hostingConfiguration {
                HStack {
                    Button("Resume") {
                        self.didAttemptRestore = false
                        self.attemptRestoreIfNeeded()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .padding(.top, 6)
                .padding(.bottom, 6)
                .padding(.leading, 20)
                .padding(.trailing, 20)
            }

        case .story(let index, let story):
            cell.contentConfiguration = hostingConfiguration {
                postViewBuilder(story, index, false)
                .padding(.top, 6)
                .padding(.bottom, 6)
                .padding(.leading, 20)
                .padding(.trailing, 20)
            }

        case .featured(let stories):
            cell.contentConfiguration = hostingConfiguration {
                VStack(alignment: .leading, spacing: 14) {
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
                            ForEach(stories, id: \.id) { story in
                                self.postViewBuilder(story, 0, true)
                                .frame(width: 280)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 10)
            }

        case .loadTrigger:
            cell.contentConfiguration = hostingConfiguration {
                Color.clear
                    .frame(height: 1)
            }

        case .loading:
            cell.contentConfiguration = hostingConfiguration {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            }

        case .loadMoreError(let message):
            cell.contentConfiguration = hostingConfiguration {
                LoadMoreRetryRow(message: message) {
                    Task { await self.vm.loadNextPage() }
                }
                .padding(.top, 6)
                .padding(.bottom, 6)
                .padding(.leading, 20)
                .padding(.trailing, 20)
            }
        }

        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard indexPath.row < rows.count else { return }
        switch rows[indexPath.row] {
        case .story(_, let story):
            scheduleLastSeenUpdate(storyID: story.id)
            Task { await vm.loadMoreIfNeeded(currentID: story.id) }
        case .loadTrigger:
            if !isTriggerLoadVisible {
                isTriggerLoadVisible = true
                Task { [weak self] in
                    await self?.vm.loadNextPage()
                }
            }
        default:
            break
        }
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row < rows.count, case .loadTrigger = rows[indexPath.row] {
            isTriggerLoadVisible = false
        }
    }

    // MARK: - UITableViewDataSourcePrefetching

    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            guard indexPath.row < rows.count else { continue }
            if case .story(_, let story) = rows[indexPath.row] {
                Task { await vm.loadMoreIfNeeded(currentID: story.id) }
            }
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
