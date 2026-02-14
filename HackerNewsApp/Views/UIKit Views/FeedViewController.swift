import UIKit
import Combine
import SafariServices

@MainActor
final class FeedViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITableViewDataSourcePrefetching {
    private let vm = ContentViewModel()
    private let offlineVM = OfflineViewModel()
    private let globalSettings: GlobalSettingsViewModel
    private let initialStoryType: StoryType
    private let initialFilter: FeedFilter?
    private let customFeedTitle: String?
    private let imagePipeline = FeedImagePipeline.shared
    private let hnAccount = HNAccount.shared
    private let proFeatureGate = ProFeatureGate.shared
    private var cancellables: Set<AnyCancellable> = []
    private var renderedStoryIDs: [Int] = []

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let refreshControl = UIRefreshControl()
    private let toastLabel = UILabel()
    private let feedBackgroundColor = UIColor.systemGroupedBackground
    private let sunGradient = SunGradientView()

    init(
        globalSettings: GlobalSettingsViewModel,
        initialStoryType: StoryType = .topstories,
        initialFilter: FeedFilter? = nil,
        customFeedTitle: String? = nil
    ) {
        self.globalSettings = globalSettings
        self.initialStoryType = initialStoryType
        self.initialFilter = initialFilter
        self.customFeedTitle = customFeedTitle
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        vm.configureInitialFeed(type: initialStoryType, filter: initialFilter)
        title = customFeedTitle ?? vm.storyType.rawValue
        view.backgroundColor = feedBackgroundColor
        configureTableView()
        configureSunGradient()
        configureToast()
        configureNavigation()
        bind()

        Task { await vm.loadInitial() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        mergePendingBookmarksIfNeeded()
    }

    private func mergePendingBookmarksIfNeeded() {
        guard !globalSettings.tempBookmarks.isEmpty else { return }
        globalSettings.syncBookmarkedStoryIDs(from: globalSettings.tempBookmarks)
    }

    private func configureSunGradient() {
        sunGradient.translatesAutoresizingMaskIntoConstraints = false
        // Add gradient ABOVE the table so it overlays the top area
        // isUserInteractionEnabled is false so touches pass through
        view.addSubview(sunGradient)
        NSLayoutConstraint.activate([
            sunGradient.topAnchor.constraint(equalTo: view.topAnchor),
            sunGradient.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 40),
            sunGradient.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 1.2),
            sunGradient.heightAnchor.constraint(equalToConstant: 300)
        ])
    }

    private func configureNavigation() {
        navigationItem.largeTitleDisplayMode = .automatic

        // Make navigation bar transparent so the sun gradient shows through
        let transparentAppearance = UINavigationBarAppearance()
        transparentAppearance.configureWithTransparentBackground()
        transparentAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        transparentAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]

        // Scrolled (compact) appearance keeps transparent to let gradient control the feel
        let scrolledAppearance = UINavigationBarAppearance()
        scrolledAppearance.configureWithDefaultBackground()
        scrolledAppearance.shadowColor = .clear

        // Set on navigationItem (not navigationController.navigationBar) so each VC
        // owns its own appearance and transitions between VCs don't fight each other.
        navigationItem.scrollEdgeAppearance = transparentAppearance
        navigationItem.standardAppearance = scrolledAppearance
        navigationItem.compactAppearance = scrolledAppearance

        if customFeedTitle == nil {
            updateRightBarButtons()
            updateFilterButton()
        } else {
            navigationItem.rightBarButtonItems = nil
            navigationItem.leftBarButtonItem = nil
        }
    }

    private func updateRightBarButtons() {
        let menuButton = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal"),
            menu: makeMenu()
        )
        if proFeatureGate.isPro {
            let searchButton = UIBarButtonItem(
                image: UIImage(systemName: "magnifyingglass"),
                style: .plain,
                target: self,
                action: #selector(openAdvancedSearch)
            )
            navigationItem.rightBarButtonItems = [menuButton, searchButton]
        } else {
            navigationItem.rightBarButtonItems = [menuButton]
        }
    }

    private func updateFilterButton() {
        guard proFeatureGate.isPro else {
            navigationItem.leftBarButtonItem = nil
            return
        }
        let isActive = vm.activeFilter?.isActive == true
        let symbol = isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: symbol),
            style: .plain,
            target: self,
            action: #selector(openFilterSheet)
        )
        navigationItem.leftBarButtonItem?.tintColor = isActive ? ThemeManager.shared.accentColor(from: globalSettings.settings) : .label
    }

    @objc private func openFilterSheet() {
        guard proFeatureGate.isPro else {
            proFeatureGate.triggerPaywall(from: self)
            return
        }

        let filterVC = FeedFilterViewController(filter: vm.activeFilter) { [weak self] filter in
            self?.vm.setActiveFilter(filter)
        }
        let nav = UINavigationController(rootViewController: filterVC)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    @objc private func openAdvancedSearch() {
        guard proFeatureGate.isPro else {
            proFeatureGate.triggerPaywall(from: self)
            return
        }
        navigationController?.pushViewController(SearchViewController(), animated: true)
    }

    private func makeMenu() -> UIMenu {
        let availableTypes = StoryType.allCases.filter { type in
            if type == .smartfeed {
                return proFeatureGate.isPro
            }
            return true
        }

        let storyActions = availableTypes.map { type in
            UIAction(title: type.rawValue, state: vm.storyType == type ? .on : .off) { [weak self] _ in
                guard let self else { return }
                if type == .smartfeed {
                    self.showSmartFeedInfoIfNeeded()
                }
                self.vm.setStoryType(type)
            }
        }

        let hideRead = UIAction(title: "Hide Read", state: vm.hideRead ? .on : .off) { [weak self] _ in
            guard let self else { return }
            self.vm.setHideRead(!self.vm.hideRead)
        }

        return UIMenu(children: storyActions + [hideRead])
    }

    private func showSmartFeedInfoIfNeeded() {
        let key = "smartFeed.info.shown"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let alert = UIAlertController(
            title: "Smart Feed",
            message: "Stories are ranked using your reading history: domain, author, and topic affinity.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.isOpaque = false
        tableView.backgroundColor = .clear
        tableView.backgroundView = nil
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 320
        tableView.dataSource = self
        tableView.delegate = self
        tableView.prefetchDataSource = self
        tableView.register(FeedStoryCell.self, forCellReuseIdentifier: FeedStoryCell.reuseID)
        tableView.accessibilityIdentifier = "feed.list"

        refreshControl.addTarget(self, action: #selector(refreshFeed), for: .valueChanged)
        tableView.refreshControl = refreshControl

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureToast() {
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        toastLabel.text = "Saved"
        toastLabel.font = .preferredFont(forTextStyle: .subheadline)
        toastLabel.textColor = .white
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        toastLabel.layer.cornerRadius = 12
        toastLabel.layer.cornerCurve = .continuous
        toastLabel.layer.masksToBounds = true
        toastLabel.textAlignment = .center
        toastLabel.alpha = 0
        toastLabel.isAccessibilityElement = true
        toastLabel.accessibilityIdentifier = "feed.saved.toast"

        view.addSubview(toastLabel)
        NSLayoutConstraint.activate([
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toastLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),
            toastLabel.heightAnchor.constraint(equalToConstant: 38)
        ])
    }

    private func bind() {
        vm.$stories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stories in self?.applyStoriesChange(stories) }
            .store(in: &cancellables)

        vm.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyLoadingState() }
            .store(in: &cancellables)

        vm.$isRefreshing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRefreshing in
                guard let self else { return }
                if !isRefreshing && self.refreshControl.isRefreshing {
                    self.refreshControl.endRefreshing()
                }
            }
            .store(in: &cancellables)

        vm.$storyType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newType in
                guard let self else { return }
                if let customFeedTitle = self.customFeedTitle {
                    self.title = customFeedTitle
                    return
                }
                self.title = newType.rawValue
                self.updateRightBarButtons()
                self.updateFilterButton()
            }
            .store(in: &cancellables)

        vm.$activeFilter
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard self?.customFeedTitle == nil else { return }
                self?.updateFilterButton()
            }
            .store(in: &cancellables)

        proFeatureGate.$isPro
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.customFeedTitle == nil else {
                    self.tableView.reloadData()
                    return
                }
                self.updateRightBarButtons()
                self.updateFilterButton()
                self.tableView.reloadData()
            }
            .store(in: &cancellables)

        hnAccount.$isLoggedIn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        offlineVM.$offlineStories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        offlineVM.$downloadStates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    private func applyLoadingState() {
        if vm.stories.isEmpty {
            applyEmptyState()
        } else {
            tableView.backgroundView = nil
        }
    }

    private func applyStoriesChange(_ stories: [Story]) {
        let newIDs = stories.map(\.id)
        let oldIDs = renderedStoryIDs
        renderedStoryIDs = newIDs

        if oldIDs.isEmpty || newIDs.isEmpty {
            tableView.reloadData()
            applyLoadingState()
            prefetchVisibleImageWindow()
            return
        }

        if newIDs.count > oldIDs.count && Array(newIDs.prefix(oldIDs.count)) == oldIDs {
            let inserted = (oldIDs.count..<newIDs.count).map { IndexPath(row: $0, section: 0) }
            tableView.performBatchUpdates {
                tableView.insertRows(at: inserted, with: .none)
            }
        } else {
            tableView.reloadData()
        }

        applyLoadingState()
        prefetchVisibleImageWindow()
    }

    private func applyEmptyState() {
        switch vm.initialLoadState {
        case .idle, .loading:
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            tableView.backgroundView = spinner
        case .empty:
            tableView.backgroundView = makeMessageView(title: "No stories yet.")
        case .error(let message, _):
            tableView.backgroundView = makeMessageView(title: message)
        case .loaded:
            tableView.backgroundView = nil
        }
    }

    private func makeMessageView(title: String) -> UIView {
        let label = UILabel()
        label.text = title
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .body)
        return label
    }

    private func openSourceWebsite(_ story: Story) {
        Task { await vm.openStory(story) }
        guard let urlString = story.url else {
            openComments(story)
            return
        }
        let safe = NetworkManager.instance.safelyLoadUrl(url: urlString)
        present(SFSafariViewController(url: safe), animated: true)
    }

    private func openComments(_ story: Story) {
        Task { await vm.openComments(story) }
        if proFeatureGate.isPro {
            let pager = StoryCommentsPagerViewController(
                initialStory: story,
                adjacentProvider: { [weak self] storyID in
                    self?.vm.adjacentStories(for: storyID) ?? (nil, nil)
                },
                onOpenReader: { [weak self] selectedStory in
                    guard let self else { return }
                    self.navigationController?.pushViewController(
                        ReaderViewController(story: selectedStory, globalSettings: self.globalSettings),
                        animated: true
                    )
                }
            )
            navigationController?.pushViewController(pager, animated: true)
        } else {
            let commentsVM = CommentsRouteViewModel(story: story)
            let commentsVC = CommentsUIKitViewController(vm: commentsVM, onOpenReader: { [weak self] selectedStory in
                guard let self else { return }
                self.navigationController?.pushViewController(
                    ReaderViewController(story: selectedStory, globalSettings: self.globalSettings),
                    animated: true
                )
            })
            commentsVC.title = "Comments"
            navigationController?.pushViewController(commentsVC, animated: true)
        }
    }

    private func shareStory(_ story: Story, sourceView: UIView?) {
        var items: [Any] = [story.title]
        if let urlString = story.url {
            items.append(NetworkManager.instance.safelyLoadUrl(url: urlString))
        }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = sourceView ?? view
            popover.sourceRect = sourceView?.bounds ?? CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(activityVC, animated: true)
    }

    private func saveStory(_ story: Story) {
        guard globalSettings.addBookmarkIfNeeded(story: story) else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if let row = vm.stories.firstIndex(where: { $0.id == story.id }) {
            tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
        }

        UIViewPropertyAnimator.runningPropertyAnimator(
            withDuration: 0.18,
            delay: 0,
            options: [.curveEaseOut]
        ) {
            self.toastLabel.alpha = 1
        } completion: { _ in
            UIViewPropertyAnimator.runningPropertyAnimator(
                withDuration: 0.2,
                delay: 1,
                options: [.curveEaseIn]
            ) {
                self.toastLabel.alpha = 0
            }
        }
    }

    private func ensureWriteAccess() -> Bool {
        guard proFeatureGate.isPro else {
            proFeatureGate.triggerPaywall(from: self)
            return false
        }
        guard hnAccount.isLoggedIn else {
            navigationController?.pushViewController(HNAccountViewController(), animated: true)
            return false
        }
        return true
    }

    private func handleStoryUpvote(_ story: Story) {
        guard ensureWriteAccess() else { return }
        Task {
            do {
                let result = try await hnAccount.upvoteStory(id: story.id)
                switch result {
                case .voted:
                    showTransientMessage("Upvoted.")
                case .alreadyVoted:
                    showTransientMessage("Already upvoted.")
                case .verificationFailed:
                    showTransientMessage("Vote sent but verification failed.")
                }
            } catch {
                showTransientMessage(error.localizedDescription)
            }
        }
    }

    private func openUserProfile(username: String) {
        guard proFeatureGate.isPro else {
            proFeatureGate.triggerPaywall(from: self)
            return
        }
        navigationController?.pushViewController(UserProfileViewController(username: username), animated: true)
    }

    private func handleSaveOffline(_ story: Story) {
        guard proFeatureGate.isPro else {
            proFeatureGate.triggerPaywall(from: self)
            return
        }

        if offlineVM.isSaved(storyID: story.id) {
            showTransientMessage("Already saved offline.")
            return
        }

        offlineVM.download(story: story)
    }

    private func showTransientMessage(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            alert.dismiss(animated: true)
        }
    }

    @objc private func refreshFeed() {
        Task { await vm.refresh() }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        vm.stories.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FeedStoryCell.reuseID, for: indexPath) as! FeedStoryCell
        let story = vm.stories[indexPath.row]
        let isRead = vm.isRead(story.id)
        let isSaved = globalSettings.bookmarkedStoryIDs.contains(story.id)
        let canWriteActions = proFeatureGate.isPro && hnAccount.isLoggedIn
        let canOpenAuthorProfile = proFeatureGate.isPro
        let canSaveOffline = proFeatureGate.isPro
        let isOfflineSaved = offlineVM.isSaved(storyID: story.id)
        let isOfflineDownloading = offlineVM.isDownloading(storyID: story.id)

        cell.imagePipeline = imagePipeline
        cell.onOpenSource = { [weak self] in self?.openSourceWebsite(story) }
        cell.onOpenComments = { [weak self] in self?.openComments(story) }
        cell.onShare = { [weak self] in self?.shareStory(story, sourceView: cell) }
        cell.onBookmark = { [weak self] in self?.saveStory(story) }
        cell.onUpvote = { [weak self] in self?.handleStoryUpvote(story) }
        cell.onSaveOffline = { [weak self] in self?.handleSaveOffline(story) }
        cell.onOpenAuthorProfile = { [weak self] in self?.openUserProfile(username: story.by) }
        cell.configure(
            story: story,
            isRead: isRead,
            isSaved: isSaved,
            style: .normal,
            canWriteActions: canWriteActions,
            canOpenAuthorProfile: canOpenAuthorProfile,
            canSaveOffline: canSaveOffline,
            isOfflineSaved: isOfflineSaved,
            isOfflineDownloading: isOfflineDownloading
        )
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openComments(vm.stories[indexPath.row])
    }

    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row < vm.stories.count else { return nil }
        let story = vm.stories[indexPath.row]

        let bookmark = UIContextualAction(style: .normal, title: "Save") { [weak self] _, _, completion in
            self?.saveStory(story)
            completion(true)
        }
        bookmark.backgroundColor = ThemeManager.shared.accentColor(from: globalSettings.settings)
        bookmark.image = UIImage(systemName: "bookmark")

        let config = UISwipeActionsConfiguration(actions: [bookmark])
        config.performsFirstActionWithFullSwipe = true
        return config
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row < vm.stories.count else { return nil }
        let story = vm.stories[indexPath.row]

        let share = UIContextualAction(style: .normal, title: "Share") { [weak self] _, _, completion in
            self?.shareStory(story, sourceView: tableView.cellForRow(at: indexPath))
            completion(true)
        }
        share.backgroundColor = .systemBlue
        share.image = UIImage(systemName: "square.and.arrow.up")

        let offline = UIContextualAction(style: .normal, title: "Offline") { [weak self] _, _, completion in
            self?.handleSaveOffline(story)
            completion(true)
        }
        offline.backgroundColor = ThemeManager.shared.accentColor(from: globalSettings.settings)
        offline.image = UIImage(systemName: "arrow.down.circle")

        let actions: [UIContextualAction]
        if proFeatureGate.isPro {
            actions = [offline, share]
        } else {
            actions = [share]
        }
        let config = UISwipeActionsConfiguration(actions: actions)
        config.performsFirstActionWithFullSwipe = false
        return config
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Pagination is handled in prefetchRowsAt — only trigger here
        // when near the very end as a fallback, to avoid creating
        // excessive Tasks for every visible row during scroll.
        let row = indexPath.row
        let count = vm.stories.count
        guard row >= count - 5, row < count else { return }
        Task { await vm.loadMoreIfNeeded(currentIndex: row) }
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Cancel in-flight image loads for cells that scrolled off-screen
        if let feedCell = cell as? FeedStoryCell {
            feedCell.cancelImageLoad()
        }
    }

    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        let validRows = indexPaths.map(\.row).filter { $0 < vm.stories.count }
        guard !validRows.isEmpty else { return }
        if let maxRow = validRows.max() {
            Task { await vm.loadMoreIfNeeded(currentIndex: maxRow) }
        }
        let stories = validRows.map { vm.stories[$0] }
        Task { await imagePipeline.prefetch(stories: stories, maxItems: stories.count) }
    }

    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        let ids = indexPaths.map(\.row)
            .filter { $0 < vm.stories.count }
            .map { vm.stories[$0].id }
        guard !ids.isEmpty else { return }
        Task { await imagePipeline.cancelPrefetch(storyIDs: ids) }
    }

    // MARK: - Scroll → Sun Gradient Fade

    private var lastGradientAlpha: CGFloat = 1

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        // Fade the gradient over the first 120 points of scroll
        let progress = min(max(offset / 120, 0), 1)
        let newAlpha = 1 - progress
        // Only set alpha when it actually changes to avoid unnecessary layer updates
        if abs(newAlpha - lastGradientAlpha) > 0.01 {
            lastGradientAlpha = newAlpha
            sunGradient.alpha = newAlpha
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        prefetchVisibleImageWindow()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            prefetchVisibleImageWindow()
        }
    }

    private func prefetchVisibleImageWindow() {
        guard !vm.stories.isEmpty else { return }
        let visibleRows = (tableView.indexPathsForVisibleRows ?? []).map(\.row).sorted()
        let start: Int
        let end: Int
        if let first = visibleRows.first, let last = visibleRows.last {
            start = max(0, first - 4)
            end = min(vm.stories.count, last + 18)
        } else {
            start = 0
            end = min(vm.stories.count, 18)
        }
        guard start < end else { return }
        let stories = Array(vm.stories[start..<end])
        Task { await imagePipeline.prefetch(stories: stories, maxItems: stories.count) }
    }
}
