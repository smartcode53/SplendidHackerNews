import UIKit
import Combine
import SafariServices
import ImageIO

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

actor FeedImagePipeline {
    static let shared = FeedImagePipeline()
    nonisolated private static let imageCache = NSCache<NSString, UIImage>()

    private var inFlightImages: [String: Task<UIImage?, Never>] = [:]
    private var prefetchTasks: [Int: Task<Void, Never>] = [:]
    private let urlCache = UltimatePostViewModel.ImageURLCache.instance
    private let availabilityCache = UltimatePostViewModel.ImageAvailabilityCache.instance
    private let networkManager = NetworkManager.instance

    init() {
        Self.imageCache.countLimit = 180
    }

    nonisolated static func cachedImage(for storyID: Int) -> UIImage? {
        imageCache.object(forKey: String(storyID) as NSString)
    }

    func image(for story: Story) async -> UIImage? {
        let storyKey = String(story.id)
        if let cached = Self.imageCache.object(forKey: storyKey as NSString) {
            return cached
        }

        guard let imageURL = await resolveImageURL(for: story) else { return nil }
        let urlKey = imageURL.absoluteString
        if let task = inFlightImages[urlKey] {
            let image = await task.value
            if let image {
                Self.imageCache.setObject(image, forKey: storyKey as NSString)
            }
            return image
        }

        let task = Task<UIImage?, Never> {
            guard let (data, _) = try? await URLSession.shared.data(from: imageURL) else {
                return nil
            }
            return Self.decodeDownsampledImage(data: data, maxPixel: 900)
        }
        inFlightImages[urlKey] = task

        let image = await task.value
        inFlightImages[urlKey] = nil

        if let image {
            Self.imageCache.setObject(image, forKey: storyKey as NSString)
        }
        return image
    }

    func prefetch(stories: [Story], maxItems: Int = 10) {
        let boundedCount = min(maxItems, 4)
        let candidates = Array(stories.prefix(boundedCount))
        for story in candidates where prefetchTasks[story.id] == nil {
            prefetchTasks[story.id] = Task {
                _ = await self.image(for: story)
                await self.clearPrefetchTask(storyID: story.id)
            }
        }
    }

    func cancelPrefetch(storyIDs: [Int]) {
        for storyID in storyIDs {
            prefetchTasks[storyID]?.cancel()
            prefetchTasks[storyID] = nil
        }
    }

    private func clearPrefetchTask(storyID: Int) {
        prefetchTasks[storyID] = nil
    }

    private func resolveImageURL(for story: Story) async -> URL? {
        guard let rawURL = story.url, !rawURL.isEmpty else {
            availabilityCache.saveToCache(false, withKey: String(story.id))
            return nil
        }

        let key = String(story.id)
        if let cachedURL = urlCache.getFromCache(withKey: key) {
            return cachedURL
        }
        if let cachedAvailability = availabilityCache.getFromCache(withKey: key), cachedAvailability == false {
            return nil
        }

        let result = await networkManager.getImage(fromUrl: rawURL)
        if let result {
            urlCache.saveToCache(result, withKey: key)
            availabilityCache.saveToCache(true, withKey: key)
            return result
        } else {
            availabilityCache.saveToCache(false, withKey: key)
            return nil
        }
    }

    private static func decodeDownsampledImage(data: Data, maxPixel: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else { return nil }
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Radial Sun Gradient View

private final class SunGradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    private var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        setupGradient()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupGradient() {
        gradientLayer.type = .radial
        gradientLayer.startPoint = CGPoint(x: 1.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: -0.2, y: 1.2)
        updateColors()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    private func updateColors() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let orange = UIColor.systemOrange
        gradientLayer.colors = [
            orange.withAlphaComponent(isDark ? 0.45 : 0.38).cgColor,
            orange.withAlphaComponent(isDark ? 0.22 : 0.18).cgColor,
            orange.withAlphaComponent(isDark ? 0.08 : 0.06).cgColor,
            UIColor.clear.cgColor
        ]
        gradientLayer.locations = [0, 0.25, 0.55, 1.0]
    }
}

@MainActor
private final class FeedViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITableViewDataSourcePrefetching {
    private let vm = ContentViewModel()
    private let globalSettings: GlobalSettingsViewModel
    private let imagePipeline = FeedImagePipeline.shared
    private var cancellables: Set<AnyCancellable> = []
    private var renderedStoryIDs: [Int] = []

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let refreshControl = UIRefreshControl()
    private let toastLabel = UILabel()
    private let feedBackgroundColor = UIColor.systemGroupedBackground
    private let sunGradient = SunGradientView()

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

        navigationController?.navigationBar.scrollEdgeAppearance = transparentAppearance
        navigationController?.navigationBar.standardAppearance = scrolledAppearance
        navigationController?.navigationBar.compactAppearance = scrolledAppearance

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
            .receive(on: RunLoop.main)
            .sink { [weak self] stories in self?.applyStoriesChange(stories) }
            .store(in: &cancellables)

        vm.$isLoading
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyLoadingState() }
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

        cell.imagePipeline = imagePipeline
        cell.onOpenSource = { [weak self] in self?.openSourceWebsite(story) }
        cell.onOpenComments = { [weak self] in self?.openComments(story) }
        cell.onShare = { [weak self] in self?.shareStory(story, sourceView: cell) }
        cell.onBookmark = { [weak self] in self?.saveStory(story) }
        cell.configure(story: story, isRead: isRead, isSaved: isSaved, style: globalSettings.selectedCardStyle)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openComments(vm.stories[indexPath.row])
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard indexPath.row < vm.stories.count else { return }
        let row = indexPath.row
        Task { await vm.loadMoreIfNeeded(currentIndex: row) }
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

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        // Fade the gradient over the first 120 points of scroll
        let progress = min(max(offset / 120, 0), 1)
        sunGradient.alpha = 1 - progress
    }
}

// MARK: - Shimmer Layer

private final class ShimmerLayer: CAGradientLayer {
    private let animationKey = "shimmerSlide"

    override init() {
        super.init()
        commonInit()
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    private func commonInit() {
        startPoint = CGPoint(x: 0, y: 0.5)
        endPoint = CGPoint(x: 1, y: 0.5)
        let base = UIColor.tertiarySystemFill.cgColor
        let highlight = UIColor.quaternarySystemFill.cgColor
        colors = [base, highlight, base]
        locations = [0, 0.5, 1]
    }

    func startAnimating() {
        guard animation(forKey: animationKey) == nil else { return }
        let anim = CABasicAnimation(keyPath: "locations")
        anim.fromValue = [-1.0, -0.5, 0.0]
        anim.toValue = [1.0, 1.5, 2.0]
        anim.duration = 1.2
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        add(anim, forKey: animationKey)
    }

    func stopAnimating() {
        removeAnimation(forKey: animationKey)
    }
}

// MARK: - FeedStoryCell

private final class FeedStoryCell: UITableViewCell {
    static let reuseID = "FeedStoryCell"

    var onOpenSource: (() -> Void)?
    var onOpenComments: (() -> Void)?
    var onShare: (() -> Void)?
    var onBookmark: (() -> Void)?
    var imagePipeline: FeedImagePipeline?

    // MARK: Card
    private let card = UIView()

    // MARK: Image
    private let imageContainer = UIView()
    private let heroImage = UIImageView()
    private let shimmerView = UIView()
    private let shimmerLayer = ShimmerLayer()
    private let placeholderIcon = UIImageView()

    // MARK: Content
    private let domainPill = UIView()
    private let domainLabel = UILabel()
    private let titleRow = UIView()
    private let titleLabel = UILabel()
    private let safariIndicator = UIImageView()
    private let metaLabel = UILabel()

    // MARK: Separator
    private let divider = UIView()

    // MARK: Actions
    private let actionsBar = UIStackView()
    private let commentsButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    private let bookmarkButton = UIButton(type: .system)
    private let pointsBadge = UIView()
    private let pointsIcon = UIImageView()
    private let pointsLabel = UILabel()

    private var imageTask: Task<Void, Never>?
    private var currentStoryID: Int?
    private var imageHeightConstraint: NSLayoutConstraint?
    private var imageContainerTopConstraint: NSLayoutConstraint?
    private var domainTopToImageConstraint: NSLayoutConstraint?
    private var domainTopToCardConstraint: NSLayoutConstraint?

    private static let imageHeight: CGFloat = 200

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
        currentStoryID = nil
        heroImage.image = nil
        heroImage.alpha = 0
        setImageVisible(false, animated: false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shimmerLayer.frame = shimmerView.bounds
    }

    // MARK: - Setup

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        setupCard()
        setupImage()
        setupContent()
        setupDivider()
        setupActions()
        buildHierarchy()
        activateConstraints()
    }

    private func setupCard() {
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 16
        card.layer.cornerCurve = .continuous
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 8
    }

    private func setupImage() {
        imageContainer.translatesAutoresizingMaskIntoConstraints = false
        imageContainer.clipsToBounds = true
        imageContainer.layer.cornerRadius = 12
        imageContainer.layer.cornerCurve = .continuous

        heroImage.translatesAutoresizingMaskIntoConstraints = false
        heroImage.contentMode = .scaleAspectFill
        heroImage.clipsToBounds = true
        heroImage.alpha = 0

        shimmerView.translatesAutoresizingMaskIntoConstraints = false
        shimmerView.clipsToBounds = true
        shimmerView.layer.addSublayer(shimmerLayer)
        shimmerView.backgroundColor = .tertiarySystemFill

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .light)
        placeholderIcon.translatesAutoresizingMaskIntoConstraints = false
        placeholderIcon.image = UIImage(systemName: "photo", withConfiguration: iconConfig)
        placeholderIcon.tintColor = .quaternaryLabel
        placeholderIcon.contentMode = .scaleAspectFit
    }

    private func setupContent() {
        // Domain pill
        domainPill.translatesAutoresizingMaskIntoConstraints = false
        domainPill.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.1)
        domainPill.layer.cornerRadius = 10
        domainPill.layer.cornerCurve = .continuous

        domainLabel.translatesAutoresizingMaskIntoConstraints = false
        domainLabel.font = UIFontMetrics(forTextStyle: .caption2).scaledFont(for: .systemFont(ofSize: 11, weight: .bold))
        domainLabel.adjustsFontForContentSizeCategory = true
        domainLabel.textColor = .systemOrange
        domainLabel.numberOfLines = 1

        // Title row
        titleRow.translatesAutoresizingMaskIntoConstraints = false
        let titleTap = UITapGestureRecognizer(target: self, action: #selector(titleTapped))
        titleRow.addGestureRecognizer(titleTap)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 3
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 17, weight: .semibold))
        titleLabel.adjustsFontForContentSizeCategory = true

        let safariConfig = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        safariIndicator.translatesAutoresizingMaskIntoConstraints = false
        safariIndicator.image = UIImage(systemName: "arrow.up.right", withConfiguration: safariConfig)
        safariIndicator.tintColor = .systemOrange
        safariIndicator.contentMode = .scaleAspectFit
        safariIndicator.setContentHuggingPriority(.required, for: .horizontal)
        safariIndicator.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Meta
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.numberOfLines = 1
        metaLabel.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .systemFont(ofSize: 12, weight: .regular))
        metaLabel.adjustsFontForContentSizeCategory = true
        metaLabel.textColor = .tertiaryLabel
    }

    private func setupDivider() {
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = .separator
    }

    private func setupActions() {
        // Points badge
        pointsBadge.translatesAutoresizingMaskIntoConstraints = false

        let arrowConfig = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        pointsIcon.translatesAutoresizingMaskIntoConstraints = false
        pointsIcon.image = UIImage(systemName: "arrow.up", withConfiguration: arrowConfig)
        pointsIcon.tintColor = .systemOrange
        pointsIcon.contentMode = .scaleAspectFit

        pointsLabel.translatesAutoresizingMaskIntoConstraints = false
        pointsLabel.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .systemFont(ofSize: 12, weight: .bold))
        pointsLabel.adjustsFontForContentSizeCategory = true
        pointsLabel.textColor = .systemOrange

        // Action buttons
        commentsButton.addAction(UIAction { [weak self] _ in self?.onOpenComments?() }, for: .touchUpInside)
        shareButton.addAction(UIAction { [weak self] _ in self?.onShare?() }, for: .touchUpInside)
        bookmarkButton.addAction(UIAction { [weak self] _ in self?.onBookmark?() }, for: .touchUpInside)

        actionsBar.axis = .horizontal
        actionsBar.alignment = .center
        actionsBar.spacing = 4
        actionsBar.translatesAutoresizingMaskIntoConstraints = false
    }

    private func makeActionButton(systemName: String, title: String? = nil) -> UIButton.Configuration {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.baseForegroundColor = .secondaryLabel
        config.baseBackgroundColor = .quaternarySystemFill
        config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12)
        config.image = UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .medium))
        if let title {
            config.imagePadding = 5
            var titleAttr = AttributeContainer()
            titleAttr.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .systemFont(ofSize: 13, weight: .semibold))
            config.attributedTitle = AttributedString(title, attributes: titleAttr)
        }
        return config
    }

    private func buildHierarchy() {
        contentView.addSubview(card)

        // Image
        card.addSubview(imageContainer)
        imageContainer.addSubview(shimmerView)
        imageContainer.addSubview(heroImage)
        shimmerView.addSubview(placeholderIcon)

        // Content
        card.addSubview(domainPill)
        domainPill.addSubview(domainLabel)
        card.addSubview(titleRow)
        titleRow.addSubview(titleLabel)
        titleRow.addSubview(safariIndicator)
        card.addSubview(metaLabel)

        // Divider
        card.addSubview(divider)

        // Actions
        card.addSubview(actionsBar)

        pointsBadge.addSubview(pointsIcon)
        pointsBadge.addSubview(pointsLabel)

        actionsBar.addArrangedSubview(pointsBadge)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        actionsBar.addArrangedSubview(spacer)
        actionsBar.addArrangedSubview(commentsButton)
        actionsBar.addArrangedSubview(shareButton)
        actionsBar.addArrangedSubview(bookmarkButton)
    }

    private func activateConstraints() {
        imageHeightConstraint = imageContainer.heightAnchor.constraint(equalToConstant: 0)
        imageHeightConstraint?.isActive = true

        imageContainerTopConstraint = imageContainer.topAnchor.constraint(equalTo: card.topAnchor, constant: 12)

        // Domain pill top constraints (mutually exclusive)
        domainTopToImageConstraint = domainPill.topAnchor.constraint(equalTo: imageContainer.bottomAnchor, constant: 12)
        domainTopToCardConstraint = domainPill.topAnchor.constraint(equalTo: card.topAnchor, constant: 14)

        // Start with no-image layout
        domainTopToCardConstraint?.isActive = true

        NSLayoutConstraint.activate([
            // Card
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),

            // Image container
            imageContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            imageContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),

            heroImage.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            heroImage.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            heroImage.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            heroImage.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),

            shimmerView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            shimmerView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            shimmerView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            shimmerView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),

            placeholderIcon.centerXAnchor.constraint(equalTo: shimmerView.centerXAnchor),
            placeholderIcon.centerYAnchor.constraint(equalTo: shimmerView.centerYAnchor),

            // Domain pill
            domainPill.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            domainPill.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -14),
            domainLabel.topAnchor.constraint(equalTo: domainPill.topAnchor, constant: 4),
            domainLabel.leadingAnchor.constraint(equalTo: domainPill.leadingAnchor, constant: 8),
            domainLabel.trailingAnchor.constraint(equalTo: domainPill.trailingAnchor, constant: -8),
            domainLabel.bottomAnchor.constraint(equalTo: domainPill.bottomAnchor, constant: -4),

            // Title row
            titleRow.topAnchor.constraint(equalTo: domainPill.bottomAnchor, constant: 8),
            titleRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            titleRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            titleLabel.topAnchor.constraint(equalTo: titleRow.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: titleRow.leadingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: titleRow.bottomAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: safariIndicator.leadingAnchor, constant: -6),

            safariIndicator.centerYAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor, constant: -2),
            safariIndicator.trailingAnchor.constraint(equalTo: titleRow.trailingAnchor),
            safariIndicator.widthAnchor.constraint(equalToConstant: 14),
            safariIndicator.heightAnchor.constraint(equalToConstant: 14),

            // Meta
            metaLabel.topAnchor.constraint(equalTo: titleRow.bottomAnchor, constant: 6),
            metaLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            metaLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            // Divider
            divider.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 12),
            divider.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            divider.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            divider.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),

            // Actions bar
            actionsBar.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 8),
            actionsBar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            actionsBar.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            actionsBar.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),

            // Points badge internal
            pointsIcon.leadingAnchor.constraint(equalTo: pointsBadge.leadingAnchor),
            pointsIcon.centerYAnchor.constraint(equalTo: pointsBadge.centerYAnchor),
            pointsIcon.widthAnchor.constraint(equalToConstant: 14),
            pointsIcon.heightAnchor.constraint(equalToConstant: 14),
            pointsLabel.leadingAnchor.constraint(equalTo: pointsIcon.trailingAnchor, constant: 2),
            pointsLabel.trailingAnchor.constraint(equalTo: pointsBadge.trailingAnchor),
            pointsLabel.centerYAnchor.constraint(equalTo: pointsBadge.centerYAnchor),
            pointsBadge.heightAnchor.constraint(equalToConstant: 28),

            commentsButton.heightAnchor.constraint(equalToConstant: 34),
            shareButton.heightAnchor.constraint(equalToConstant: 34),
            bookmarkButton.heightAnchor.constraint(equalToConstant: 34),
        ])
    }

    // MARK: - Configure

    func configure(story: Story, isRead: Bool, isSaved: Bool, style: Settings.CardStyle) {
        currentStoryID = story.id

        // Domain
        let domain = story.url.flatMap(URL.init(string:))?.host?.replacingOccurrences(of: "www.", with: "") ?? "news.ycombinator.com"
        domainLabel.text = domain

        // Title
        titleLabel.text = story.title
        titleLabel.textColor = isRead ? .secondaryLabel : .label

        // Safari indicator visibility
        safariIndicator.isHidden = story.url == nil || story.url?.isEmpty == true

        // Meta
        metaLabel.text = "\(story.by) · \(Date.getTimeInterval(with: story.time))"

        // Points
        pointsLabel.text = "\(story.score)"

        // Comments button
        let comments = story.descendants ?? 0
        commentsButton.configuration = makeActionButton(systemName: "bubble.right", title: "\(comments)")

        // Share button
        shareButton.configuration = makeActionButton(systemName: "square.and.arrow.up")

        // Bookmark button
        var bmConfig = makeActionButton(systemName: isSaved ? "bookmark.fill" : "bookmark")
        if isSaved {
            bmConfig.baseForegroundColor = .systemOrange
            bmConfig.baseBackgroundColor = UIColor.systemOrange.withAlphaComponent(0.12)
        }
        bookmarkButton.configuration = bmConfig
        bookmarkButton.isEnabled = !isSaved

        // Read state
        card.alpha = isRead ? 0.75 : 1.0

        loadThumbnail(for: story)
    }

    @objc private func titleTapped() {
        onOpenSource?()
    }

    // MARK: - Image Loading

    private func setImageVisible(_ visible: Bool, animated: Bool) {
        let showImage = visible
        let height: CGFloat = showImage ? Self.imageHeight : 0

        imageHeightConstraint?.constant = height

        // Toggle which top constraint is active
        if showImage {
            domainTopToCardConstraint?.isActive = false
            imageContainerTopConstraint?.isActive = true
            domainTopToImageConstraint?.isActive = true
        } else {
            imageContainerTopConstraint?.isActive = false
            domainTopToImageConstraint?.isActive = false
            domainTopToCardConstraint?.isActive = true
        }

        imageContainer.isHidden = !showImage
        shimmerView.isHidden = !showImage
        placeholderIcon.isHidden = !showImage

        if showImage {
            shimmerLayer.startAnimating()
        } else {
            shimmerLayer.stopAnimating()
        }

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                self.contentView.layoutIfNeeded()
            }
        }
    }

    private func loadThumbnail(for story: Story) {
        guard story.url?.isEmpty == false else {
            heroImage.image = nil
            heroImage.alpha = 0
            setImageVisible(false, animated: false)
            return
        }

        if let cached = FeedImagePipeline.cachedImage(for: story.id) {
            heroImage.image = cached
            heroImage.alpha = 1
            shimmerView.isHidden = true
            placeholderIcon.isHidden = true
            shimmerLayer.stopAnimating()
            setImageVisible(true, animated: false)
            return
        }

        // Show shimmer placeholder
        heroImage.image = nil
        heroImage.alpha = 0
        setImageVisible(true, animated: false)

        imageTask?.cancel()
        imageTask = Task { [weak self] in
            guard let self, let pipeline = self.imagePipeline else {
                await MainActor.run { [weak self] in
                    self?.setImageVisible(false, animated: false)
                }
                return
            }

            let image = await pipeline.image(for: story)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self, self.currentStoryID == story.id else { return }
                if let image {
                    self.heroImage.image = image
                    self.shimmerLayer.stopAnimating()
                    self.shimmerView.isHidden = true
                    self.placeholderIcon.isHidden = true
                    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                        self.heroImage.alpha = 1
                    }
                } else {
                    self.setImageVisible(false, animated: false)
                }
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
