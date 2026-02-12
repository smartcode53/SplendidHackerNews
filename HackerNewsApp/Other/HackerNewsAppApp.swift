import UIKit
import Combine
import SafariServices

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private let globalSettings = GlobalSettingsViewModel()
    private var cancellables: Set<AnyCancellable> = []

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let root = HNTabBarController(globalSettings: globalSettings)
        window.rootViewController = root
        self.window = window
        applyTheme()
        observeSettings()
        window.makeKeyAndVisible()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        globalSettings.saveSettings()
    }

    private func observeSettings() {
        globalSettings.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyTheme()
            }
            .store(in: &cancellables)
    }

    private func applyTheme() {
        let style: UIUserInterfaceStyle
        switch globalSettings.selectedTheme {
        case .automatic:
            style = .unspecified
        case .dark:
            style = .dark
        case .light:
            style = .light
        }
        window?.overrideUserInterfaceStyle = style
    }
}

@MainActor
final class HNTabBarController: UITabBarController {
    private let globalSettings: GlobalSettingsViewModel

    init(globalSettings: GlobalSettingsViewModel) {
        self.globalSettings = globalSettings
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        configureTabs()
    }

    private func configureTabs() {
        let feedVC = FeedViewController(globalSettings: globalSettings)
        let savedVC = SavedStoriesViewController(globalSettings: globalSettings)
        let settingsVC = SettingsUIKitViewController(globalSettings: globalSettings)

        let feedNav = UINavigationController(rootViewController: feedVC)
        feedNav.tabBarItem = UITabBarItem(title: "Feed", image: UIImage(systemName: "newspaper"), tag: 0)
        feedNav.tabBarItem.accessibilityIdentifier = "tab.feed"

        let savedNav = UINavigationController(rootViewController: savedVC)
        savedNav.tabBarItem = UITabBarItem(title: "Saved Stories", image: UIImage(systemName: "bookmark"), tag: 1)
        savedNav.tabBarItem.accessibilityIdentifier = "tab.saved"

        let settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gear"), tag: 2)
        settingsNav.tabBarItem.accessibilityIdentifier = "tab.settings"

        [feedNav, savedNav, settingsNav].forEach {
            $0.navigationBar.prefersLargeTitles = true
        }

        viewControllers = [feedNav, savedNav, settingsNav]

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = .systemOrange
    }
}

@MainActor
private final class FeedViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITableViewDataSourcePrefetching {
    private let vm = ContentViewModel()
    private let globalSettings: GlobalSettingsViewModel
    private var cancellables: Set<AnyCancellable> = []

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let refreshControl = UIRefreshControl()
    private let toastLabel = UILabel()
    private let feedBackgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground

    init(globalSettings: GlobalSettingsViewModel) {
        self.globalSettings = globalSettings
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = vm.storyType.rawValue
        view.backgroundColor = feedBackgroundColor
        configureTableView()
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

    private func configureNavigation() {
        navigationItem.largeTitleDisplayMode = .automatic
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            menu: makeMenu()
        )
    }

    private func makeMenu() -> UIMenu {
        let storyActions = StoryType.allCases.map { type in
            UIAction(title: type.rawValue, state: vm.storyType == type ? .on : .off) { [weak self] _ in
                self?.vm.setStoryType(type)
            }
        }

        let hideRead = UIAction(title: "Hide Read", state: vm.hideRead ? .on : .off) { [weak self] _ in
            guard let self else { return }
            self.vm.setHideRead(!self.vm.hideRead)
        }

        return UIMenu(children: storyActions + [hideRead])
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.isOpaque = false
        tableView.backgroundColor = feedBackgroundColor
        let clearBackground = UIView()
        clearBackground.backgroundColor = feedBackgroundColor
        tableView.backgroundView = clearBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 180
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
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reloadData() }
            .store(in: &cancellables)

        vm.$isLoading
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reloadData() }
            .store(in: &cancellables)

        vm.$isRefreshing
            .receive(on: RunLoop.main)
            .sink { [weak self] isRefreshing in
                guard let self else { return }
                if !isRefreshing && self.refreshControl.isRefreshing {
                    self.refreshControl.endRefreshing()
                }
            }
            .store(in: &cancellables)

        vm.$storyType
            .receive(on: RunLoop.main)
            .sink { [weak self] newType in
                guard let self else { return }
                self.title = newType.rawValue
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(
                    image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
                    menu: self.makeMenu()
                )
            }
            .store(in: &cancellables)
    }

    private func reloadData() {
        tableView.reloadData()
        if vm.stories.isEmpty {
            applyEmptyState()
        } else {
            tableView.backgroundView = nil
        }
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
        tableView.reloadData()

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

    @objc private func refreshFeed() {
        Task { await vm.refresh() }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        vm.stories.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: FeedStoryCell.reuseID, for: indexPath) as? FeedStoryCell else {
            return UITableViewCell()
        }
        let story = vm.stories[indexPath.row]
        cell.configure(
            story: story,
            isRead: vm.isRead(story.id),
            isSaved: globalSettings.isStoryBookmarked(story.id),
            style: globalSettings.selectedCardStyle
        )
        cell.onOpenSource = { [weak self] in self?.openSourceWebsite(story) }
        cell.onOpenComments = { [weak self] in self?.openComments(story) }
        cell.onShare = { [weak self, weak cell] in self?.shareStory(story, sourceView: cell) }
        cell.onBookmark = { [weak self] in self?.saveStory(story) }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openComments(vm.stories[indexPath.row])
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard indexPath.row < vm.stories.count else { return }
        let story = vm.stories[indexPath.row]
        Task { await vm.loadMoreIfNeeded(currentID: story.id) }
    }

    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths where indexPath.row < vm.stories.count {
            let story = vm.stories[indexPath.row]
            Task { await vm.loadMoreIfNeeded(currentID: story.id) }
        }
    }
}

private final class FeedStoryCell: UITableViewCell {
    static let reuseID = "FeedStoryCell"

    var onOpenSource: (() -> Void)?
    var onOpenComments: (() -> Void)?
    var onShare: (() -> Void)?
    var onBookmark: (() -> Void)?

    private let card = UIView()
    private let divider = UIView()
    private let urlLabel = UILabel()
    private let titleButton = UIButton(type: .system)
    private let timeUserLabel = UILabel()
    private let pointsLabel = UILabel()
    private let titleLabel = UILabel()
    private let thumbnail = UIImageView()
    private let footerRow = UIStackView()
    private let actionsRow = UIStackView()
    private let commentsButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    private let bookmarkButton = UIButton(type: .system)

    private var imageTask: Task<Void, Never>?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        imageTask = nil
        thumbnail.image = nil
        thumbnail.isHidden = true
    }

    private func setup() {
        selectionStyle = .none
        isOpaque = false
        backgroundColor = .clear
        let clearBackground = UIBackgroundConfiguration.clear()
        backgroundConfiguration = clearBackground
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .clear
        multipleSelectionBackgroundView = UIView()
        multipleSelectionBackgroundView?.backgroundColor = .clear

        contentView.isOpaque = false
        contentView.backgroundColor = .clear

        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .clear
        card.layer.cornerRadius = 0
        card.layer.borderWidth = 0

        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = (UIColor(named: "NavigationSeparatorLine") ?? .separator).withAlphaComponent(0.45)

        thumbnail.translatesAutoresizingMaskIntoConstraints = false
        thumbnail.contentMode = .scaleAspectFill
        thumbnail.clipsToBounds = true
        thumbnail.layer.cornerRadius = 16
        thumbnail.layer.cornerCurve = .continuous
        thumbnail.isHidden = true

        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        urlLabel.numberOfLines = 1
        urlLabel.font = .preferredFont(forTextStyle: .caption1)
        urlLabel.adjustsFontForContentSizeCategory = true
        urlLabel.textColor = .systemOrange

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 0
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true

        titleButton.translatesAutoresizingMaskIntoConstraints = false
        titleButton.configuration = .plain()
        titleButton.configuration?.contentInsets = .zero
        titleButton.contentHorizontalAlignment = .leading
        titleButton.addAction(UIAction { [weak self] _ in self?.onOpenSource?() }, for: .touchUpInside)

        timeUserLabel.translatesAutoresizingMaskIntoConstraints = false
        timeUserLabel.numberOfLines = 1
        timeUserLabel.font = .preferredFont(forTextStyle: .caption1)
        timeUserLabel.textColor = .secondaryLabel
        timeUserLabel.adjustsFontForContentSizeCategory = true

        pointsLabel.translatesAutoresizingMaskIntoConstraints = false
        pointsLabel.numberOfLines = 1
        pointsLabel.font = .preferredFont(forTextStyle: .subheadline)
        pointsLabel.adjustsFontForContentSizeCategory = true

        commentsButton.configuration = .tinted()
        commentsButton.configuration?.cornerStyle = .capsule
        commentsButton.configuration?.buttonSize = .small
        commentsButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        commentsButton.configuration?.baseForegroundColor = .secondaryLabel
        commentsButton.configuration?.baseBackgroundColor = UIColor.secondarySystemFill
        commentsButton.setImage(UIImage(systemName: "message", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)), for: .normal)
        commentsButton.configuration?.imagePadding = 4
        commentsButton.configuration?.title = "0"
        commentsButton.addAction(UIAction { [weak self] _ in self?.onOpenComments?() }, for: .touchUpInside)
        commentsButton.titleLabel?.lineBreakMode = .byClipping

        shareButton.configuration = .tinted()
        shareButton.configuration?.cornerStyle = .capsule
        shareButton.configuration?.buttonSize = .small
        shareButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        shareButton.configuration?.baseForegroundColor = .secondaryLabel
        shareButton.configuration?.baseBackgroundColor = UIColor.secondarySystemFill
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)), for: .normal)
        shareButton.addAction(UIAction { [weak self] _ in self?.onShare?() }, for: .touchUpInside)

        bookmarkButton.configuration = .tinted()
        bookmarkButton.configuration?.cornerStyle = .capsule
        bookmarkButton.configuration?.buttonSize = .small
        bookmarkButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        bookmarkButton.configuration?.baseForegroundColor = .secondaryLabel
        bookmarkButton.configuration?.baseBackgroundColor = UIColor.secondarySystemFill
        bookmarkButton.addAction(UIAction { [weak self] _ in self?.onBookmark?() }, for: .touchUpInside)

        footerRow.axis = .horizontal
        footerRow.alignment = .center
        footerRow.distribution = .fill
        footerRow.translatesAutoresizingMaskIntoConstraints = false

        actionsRow.axis = .horizontal
        actionsRow.alignment = .center
        actionsRow.spacing = 8
        actionsRow.translatesAutoresizingMaskIntoConstraints = false
        actionsRow.addArrangedSubview(bookmarkButton)
        actionsRow.addArrangedSubview(shareButton)
        actionsRow.addArrangedSubview(commentsButton)

        contentView.addSubview(card)
        card.addSubview(thumbnail)
        card.addSubview(urlLabel)
        card.addSubview(titleButton)
        card.addSubview(timeUserLabel)
        card.addSubview(footerRow)
        card.addSubview(divider)

        footerRow.addArrangedSubview(pointsLabel)
        footerRow.addArrangedSubview(UIView())
        footerRow.addArrangedSubview(actionsRow)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            thumbnail.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            thumbnail.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            thumbnail.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            thumbnail.heightAnchor.constraint(equalToConstant: 190),

            urlLabel.topAnchor.constraint(equalTo: thumbnail.bottomAnchor, constant: 10),
            urlLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            urlLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            titleButton.topAnchor.constraint(equalTo: urlLabel.bottomAnchor, constant: 10),
            titleButton.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            titleButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            timeUserLabel.topAnchor.constraint(equalTo: titleButton.bottomAnchor, constant: 12),
            timeUserLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            timeUserLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            footerRow.topAnchor.constraint(equalTo: timeUserLabel.bottomAnchor, constant: 18),
            footerRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            footerRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            footerRow.bottomAnchor.constraint(equalTo: divider.topAnchor, constant: -10),

            divider.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            divider.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            divider.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale)
        ])
    }

    func configure(story: Story, isRead: Bool, isSaved: Bool, style: Settings.CardStyle) {
        titleLabel.text = story.title
        titleLabel.textColor = isRead ? .secondaryLabel : .label
        urlLabel.text = (story.url.flatMap(URL.init(string:))?.host) ?? "news.ycombinator.com"
        timeUserLabel.text = "\(Date.getTimeInterval(with: story.time)) | \(story.by)"
        pointsLabel.text = "\(story.score) points"

        var titleConfig = UIButton.Configuration.plain()
        titleConfig.contentInsets = .zero
        titleConfig.image = UIImage(
            systemName: "arrow.up.right.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        )
        titleConfig.imagePlacement = .trailing
        titleConfig.imagePadding = 8
        titleConfig.baseForegroundColor = .secondaryLabel
        titleButton.configuration = titleConfig
        titleButton.setTitle(nil, for: .normal)
        titleButton.setAttributedTitle(
            NSAttributedString(
                string: story.title,
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .headline),
                    .foregroundColor: isRead ? UIColor.secondaryLabel : UIColor.label
                ]
            ),
            for: .normal
        )
        titleButton.titleLabel?.numberOfLines = 0
        titleButton.titleLabel?.lineBreakMode = .byWordWrapping

        let comments = story.descendants ?? 0
        commentsButton.configuration?.title = "\(comments)"

        var bookmarkConfig = UIButton.Configuration.tinted()
        bookmarkConfig.cornerStyle = .capsule
        bookmarkConfig.buttonSize = .small
        bookmarkConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        bookmarkConfig.baseBackgroundColor = UIColor.secondarySystemFill
        bookmarkConfig.baseForegroundColor = isSaved ? .tertiaryLabel : .secondaryLabel
        bookmarkConfig.image = UIImage(systemName: isSaved ? "bookmark.fill" : "bookmark")
        bookmarkButton.configuration = bookmarkConfig
        bookmarkButton.isEnabled = !isSaved
        bookmarkButton.tintColor = isSaved ? .tertiaryLabel : .secondaryLabel

        _ = style
        loadThumbnail(for: story)
    }

    private func loadThumbnail(for story: Story) {
        guard let raw = story.url, !raw.isEmpty else {
            thumbnail.isHidden = true
            return
        }

        thumbnail.isHidden = false
        imageTask?.cancel()
        imageTask = Task { [weak self] in
            guard let self else { return }
            guard let ogURL = await NetworkManager.instance.getImage(fromUrl: raw) else {
                await MainActor.run { self.thumbnail.isHidden = true }
                return
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: ogURL)
                guard !Task.isCancelled else { return }
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.thumbnail.isHidden = false
                        self.thumbnail.image = image
                    }
                } else {
                    await MainActor.run { self.thumbnail.isHidden = true }
                }
            } catch {
                await MainActor.run { self.thumbnail.isHidden = true }
            }
        }
    }
}

@MainActor
private final class SavedStoriesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let vm = BookmarksViewModel()
    private let globalSettings: GlobalSettingsViewModel
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    init(globalSettings: GlobalSettingsViewModel) {
        self.globalSettings = globalSettings
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Saved Stories"
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        configureNavigation()
        configureTable()
        mergePendingBookmarksIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        persist()
    }

    private func configureNavigation() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "clock.arrow.circlepath"),
            primaryAction: UIAction { [weak self] _ in
                guard let self else { return }
                self.navigationController?.pushViewController(HistoryUIKitViewController(globalSettings: self.globalSettings), animated: true)
            }
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.up.arrow.down.square"),
            menu: sortMenu()
        )
    }

    private func sortMenu() -> UIMenu {
        let actions = BookmarksViewModel.SortType.allCases.map { type in
            UIAction(title: type.rawValue, state: vm.selectedSortType == type ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.vm.selectedSortType = type
                self.tableView.reloadData()
            }
        }
        return UIMenu(title: "Sort", children: actions)
    }

    private func configureTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "bookmark")

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func mergePendingBookmarksIfNeeded() {
        if !globalSettings.tempBookmarks.isEmpty {
            vm.bookmarks.append(contentsOf: globalSettings.tempBookmarks)
            globalSettings.tempBookmarks.removeAll()
            syncBookmarks()
        }
        tableView.reloadData()
    }

    private func syncBookmarks() {
        globalSettings.syncBookmarkedStoryIDs(from: vm.bookmarks)
    }

    private func persist() {
        vm.saveToDisk()
        syncBookmarks()
    }

    private func open(_ story: Story) {
        if globalSettings.settings.openInReader {
            navigationController?.pushViewController(ReaderViewController(story: story, globalSettings: globalSettings), animated: true)
        } else if let url = story.url {
            present(SFSafariViewController(url: NetworkManager.instance.safelyLoadUrl(url: url)), animated: true)
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(vm.bookmarks.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "bookmark", for: indexPath)
        var content = UIListContentConfiguration.subtitleCell()

        if vm.bookmarks.isEmpty {
            content.text = "No saved stories yet"
            content.secondaryText = "Bookmark a story from the feed to see it here."
            cell.accessoryType = .none
            cell.selectionStyle = .none
            cell.contentConfiguration = content
            return cell
        }

        let bookmark = vm.bookmarks[indexPath.row]
        content.text = bookmark.story.title
        content.secondaryText = "\(bookmark.story.by) · \(Date.unixToRegular(bookmark.story.time))"
        content.textProperties.numberOfLines = 2
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < vm.bookmarks.count else { return }
        open(vm.bookmarks[indexPath.row].story)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row < vm.bookmarks.count else { return nil }
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            guard let self else { return }
            self.vm.bookmarks.remove(at: indexPath.row)
            self.syncBookmarks()
            tableView.deleteRows(at: [indexPath], with: .automatic)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
}

@MainActor
private final class HistoryUIKitViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let vm = HistoryViewModel()
    private let globalSettings: GlobalSettingsViewModel
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    init(globalSettings: GlobalSettingsViewModel) {
        self.globalSettings = globalSettings
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "History"
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .trash,
            target: self,
            action: #selector(clearHistory)
        )

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "history")

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        Task {
            await vm.load()
            tableView.reloadData()
        }
    }

    @objc private func clearHistory() {
        Task {
            await vm.clear()
            tableView.reloadData()
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(vm.entries.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "history", for: indexPath)
        var content = UIListContentConfiguration.subtitleCell()
        if vm.entries.isEmpty {
            content.text = "No history yet"
            content.secondaryText = "Opened stories will appear here."
            cell.selectionStyle = .none
            cell.accessoryType = .none
            cell.contentConfiguration = content
            return cell
        }

        let entry = vm.entries[indexPath.row]
        content.text = entry.title
        content.secondaryText = "\(entry.feed) · \(Date.unixToRegular(entry.openedAt))"
        content.textProperties.numberOfLines = 2
        cell.accessoryType = .disclosureIndicator
        cell.contentConfiguration = content
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < vm.entries.count else { return }
        let entry = vm.entries[indexPath.row]
        let story = Story(
            by: "history",
            descendants: nil,
            id: entry.storyID,
            score: 0,
            time: entry.openedAt,
            title: entry.title,
            type: "story",
            url: entry.url
        )
        if globalSettings.settings.openInReader {
            navigationController?.pushViewController(ReaderViewController(story: story, globalSettings: globalSettings), animated: true)
        } else if let url = entry.url {
            present(SFSafariViewController(url: NetworkManager.instance.safelyLoadUrl(url: url)), animated: true)
        }
    }
}

@MainActor
private final class SettingsUIKitViewController: UIViewController {
    private let globalSettings: GlobalSettingsViewModel

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let cardStyleControl = UISegmentedControl(items: Settings.CardStyle.allCases.map(\.rawValue))
    private let themeControl = UISegmentedControl(items: Settings.Theme.allCases.map(\.rawValue))
    private let openInReaderSwitch = UISwitch()
    private let openReaderLinksSwitch = UISwitch()
    private let fontScaleSlider = UISlider()
    private let lineSpacingSlider = UISlider()
    private let fontScaleValueLabel = UILabel()
    private let lineSpacingValueLabel = UILabel()

    init(globalSettings: GlobalSettingsViewModel) {
        self.globalSettings = globalSettings
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        configureLayout()
        configureState()
        wireActions()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        globalSettings.saveSettings()
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 14
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true

        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor)
        ])

        stack.addArrangedSubview(makeCard(title: "Story Feed Card Style", body: cardStyleControl))
        stack.addArrangedSubview(makeCard(title: "Theme", body: themeControl))

        stack.addArrangedSubview(makeSwitchCard(
            title: "Open stories in Reader",
            subtitle: "Open story taps in in-app reader by default.",
            control: openInReaderSwitch
        ))

        stack.addArrangedSubview(makeSwitchCard(
            title: "Open reader links in Reader",
            subtitle: "In Reader, open article links in Reader when possible.",
            control: openReaderLinksSwitch
        ))

        fontScaleSlider.minimumValue = 0.9
        fontScaleSlider.maximumValue = 1.4
        fontScaleSlider.isContinuous = true
        stack.addArrangedSubview(makeSliderCard(
            title: "Reader Font Scale",
            subtitleLabel: fontScaleValueLabel,
            slider: fontScaleSlider
        ))

        lineSpacingSlider.minimumValue = 0
        lineSpacingSlider.maximumValue = 6
        stack.addArrangedSubview(makeSliderCard(
            title: "Reader Line Spacing",
            subtitleLabel: lineSpacingValueLabel,
            slider: lineSpacingSlider
        ))
    }

    private func makeCard(title: String, body: UIView) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(named: "CardColor") ?? .secondarySystemBackground
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous

        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.text = title

        let stack = UIStackView(arrangedSubviews: [titleLabel, body])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        return card
    }

    private func makeSwitchCard(title: String, subtitle: String, control: UISwitch) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(named: "CardColor") ?? .secondarySystemBackground
        card.layer.cornerRadius = 14

        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.text = title
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.text = subtitle

        let top = UIStackView(arrangedSubviews: [titleLabel, UIView(), control])
        top.axis = .horizontal
        top.alignment = .center

        let stack = UIStackView(arrangedSubviews: [top, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        return card
    }

    private func makeSliderCard(title: String, subtitleLabel: UILabel, slider: UISlider) -> UIView {
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel

        let v = UIStackView(arrangedSubviews: [subtitleLabel, slider])
        v.axis = .vertical
        v.spacing = 8
        return makeCard(title: title, body: v)
    }

    private func configureState() {
        cardStyleControl.selectedSegmentIndex = Settings.CardStyle.allCases.firstIndex(of: globalSettings.selectedCardStyle) ?? 0
        themeControl.selectedSegmentIndex = Settings.Theme.allCases.firstIndex(of: globalSettings.selectedTheme) ?? 0

        openInReaderSwitch.isOn = globalSettings.settings.openInReader
        openReaderLinksSwitch.isOn = globalSettings.settings.openReaderLinksInReader

        fontScaleSlider.value = Float(globalSettings.settings.readerFontScale)
        lineSpacingSlider.value = Float(globalSettings.settings.readerLineSpacing)
        refreshTypographyLabels()
    }

    private func wireActions() {
        cardStyleControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.globalSettings.settings.cardStyleString = Settings.CardStyle.allCases[self.cardStyleControl.selectedSegmentIndex].rawValue
        }, for: .valueChanged)

        themeControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.globalSettings.settings.themeString = Settings.Theme.allCases[self.themeControl.selectedSegmentIndex].rawValue
        }, for: .valueChanged)

        openInReaderSwitch.addAction(UIAction { [weak self] _ in
            self?.globalSettings.settings.openInReader = self?.openInReaderSwitch.isOn ?? false
        }, for: .valueChanged)

        openReaderLinksSwitch.addAction(UIAction { [weak self] _ in
            self?.globalSettings.settings.openReaderLinksInReader = self?.openReaderLinksSwitch.isOn ?? false
        }, for: .valueChanged)

        fontScaleSlider.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.globalSettings.settings.readerFontScale = Double(self.fontScaleSlider.value)
            self.refreshTypographyLabels()
        }, for: .valueChanged)

        lineSpacingSlider.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.globalSettings.settings.readerLineSpacing = Double(self.lineSpacingSlider.value)
            self.refreshTypographyLabels()
        }, for: .valueChanged)
    }

    private func refreshTypographyLabels() {
        fontScaleValueLabel.text = String(format: "Scale %.2f", globalSettings.settings.readerFontScale)
        lineSpacingValueLabel.text = String(format: "Spacing %.1f", globalSettings.settings.readerLineSpacing)
    }
}

@MainActor
private final class ReaderViewController: UIViewController, UITextViewDelegate {
    private let vm: ReaderViewModel
    private let globalSettings: GlobalSettingsViewModel

    private let textView = UITextView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let messageLabel = UILabel()

    init(story: Story, globalSettings: GlobalSettingsViewModel) {
        self.vm = ReaderViewModel(story: story)
        self.globalSettings = globalSettings
        super.init(nibName: nil, bundle: nil)
    }

    init(url: URL, title: String, globalSettings: GlobalSettingsViewModel) {
        self.vm = ReaderViewModel(url: url, title: title)
        self.globalSettings = globalSettings
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Reader"
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        configureNavigation()
        configureViews()

        Task {
            await vm.load()
            render()
        }
    }

    private func configureNavigation() {
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "textformat.size"), primaryAction: UIAction { [weak self] _ in self?.showTypographyMenu() }),
            UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), primaryAction: UIAction { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.vm.reload()
                    self.render()
                }
            }),
            UIBarButtonItem(image: UIImage(systemName: "safari"), primaryAction: UIAction { [weak self] _ in self?.openInSafari() })
        ]
    }

    private func configureViews() {
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 22, right: 16)
        textView.delegate = self
        textView.adjustsFontForContentSizeCategory = true

        spinner.translatesAutoresizingMaskIntoConstraints = false

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.textColor = .secondaryLabel
        messageLabel.font = .preferredFont(forTextStyle: .body)

        view.addSubview(textView)
        view.addSubview(spinner)
        view.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            messageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func render() {
        switch vm.loadState {
        case .idle, .loading:
            spinner.startAnimating()
            messageLabel.isHidden = true
            textView.isHidden = true
        case .empty:
            spinner.stopAnimating()
            textView.isHidden = true
            messageLabel.isHidden = false
            messageLabel.text = "Couldn't extract readable text."
        case .error(let message, _):
            spinner.stopAnimating()
            textView.isHidden = true
            messageLabel.isHidden = false
            messageLabel.text = message
        case .loaded:
            spinner.stopAnimating()
            messageLabel.isHidden = true
            textView.isHidden = false
            textView.attributedText = makeAttributedContent()
        }
    }

    private func makeAttributedContent() -> NSAttributedString {
        guard let content = vm.content else { return NSAttributedString(string: "") }

        let basePointSize = UIFont.preferredFont(forTextStyle: .body).pointSize * globalSettings.settings.readerFontScale
        let bodyFont = UIFont.systemFont(ofSize: basePointSize)
        let headingFont = UIFont.boldSystemFont(ofSize: basePointSize * 1.28)
        let subheadingFont = UIFont.boldSystemFont(ofSize: basePointSize * 1.12)

        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.lineSpacing = globalSettings.settings.readerLineSpacing

        let result = NSMutableAttributedString()

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: basePointSize * 1.35),
            .foregroundColor: UIColor.label
        ]
        result.append(NSAttributedString(string: content.title + "\n\n", attributes: titleAttrs))

        for block in content.blocks {
            switch block {
            case .heading(let text, let level):
                let font = level <= 2 ? headingFont : subheadingFont
                result.append(NSAttributedString(string: text + "\n", attributes: [
                    .font: font,
                    .foregroundColor: UIColor.label
                ]))
            case .paragraph(let spans):
                let paragraphText = NSMutableAttributedString()
                for span in spans {
                    switch span {
                    case .text(let text):
                        paragraphText.append(NSAttributedString(string: text, attributes: [
                            .font: bodyFont,
                            .foregroundColor: UIColor.label,
                            .paragraphStyle: bodyParagraph
                        ]))
                    case .link(let text, let url):
                        paragraphText.append(NSAttributedString(string: text, attributes: [
                            .font: bodyFont,
                            .foregroundColor: UIColor.systemOrange,
                            .paragraphStyle: bodyParagraph,
                            .link: url
                        ]))
                    }
                }
                result.append(paragraphText)
                result.append(NSAttributedString(string: "\n\n"))
            case .quote(let text):
                result.append(NSAttributedString(string: "\u{201C}\(text)\u{201D}\n\n", attributes: [
                    .font: UIFont.italicSystemFont(ofSize: basePointSize),
                    .foregroundColor: UIColor.secondaryLabel,
                    .paragraphStyle: bodyParagraph
                ]))
            case .code(let text):
                result.append(NSAttributedString(string: text + "\n\n", attributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: max(basePointSize - 1, 12), weight: .regular),
                    .foregroundColor: UIColor.label
                ]))
            }
        }

        return result
    }

    private func openInSafari() {
        guard let safeURL = vm.safeURL else { return }
        present(SFSafariViewController(url: safeURL), animated: true)
    }

    private func showTypographyMenu() {
        let menu = UIAlertController(title: "Typography", message: nil, preferredStyle: .actionSheet)
        menu.addAction(UIAlertAction(title: "Reset to Default", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            self.globalSettings.settings.readerFontScale = 1.0
            self.globalSettings.settings.readerLineSpacing = 2.0
            self.render()
        }))
        menu.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(menu, animated: true)
    }

    func textView(
        _ textView: UITextView,
        shouldInteractWith url: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        switch ReaderLinkHandler.resolve(
            url: url,
            prefersReader: globalSettings.settings.openReaderLinksInReader,
            fallbackTitle: url.host ?? "Linked Article"
        ) {
        case .openInReader(let linkedURL, let title):
            navigationController?.pushViewController(
                ReaderViewController(url: linkedURL, title: title, globalSettings: globalSettings),
                animated: true
            )
            return false
        case .showAction(let action):
            let menu = UIAlertController(title: "Open Link", message: action.url.absoluteString, preferredStyle: .actionSheet)
            if action.canOpenInReader {
                menu.addAction(UIAlertAction(title: "Open in Reader", style: .default) { [weak self] _ in
                    guard let self else { return }
                    self.navigationController?.pushViewController(
                        ReaderViewController(url: action.url, title: action.url.host ?? "Linked Article", globalSettings: self.globalSettings),
                        animated: true
                    )
                })
            }
            menu.addAction(UIAlertAction(title: "Open in Safari", style: .default) { [weak self] _ in
                self?.present(SFSafariViewController(url: action.url), animated: true)
            })
            menu.addAction(UIAlertAction(title: "Copy Link", style: .default) { _ in
                UIPasteboard.general.url = action.url
            })
            menu.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(menu, animated: true)
            return false
        }
    }
}
