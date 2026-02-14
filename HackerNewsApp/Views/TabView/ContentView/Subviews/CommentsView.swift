//
//  CommentsView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/26/22.
//

import UIKit
import Combine
import SafariServices

@MainActor
final class CommentsUIKitViewController<VM>: UIViewController, UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate, UISearchResultsUpdating where VM: CommentsButtonProtocol, VM: SafariViewLoader {
    private let vm: VM
    private let hnAccount = HNAccount.shared
    private let proFeatureGate = ProFeatureGate.shared
    private var onOpenReader: ((Story) -> Void)?
    private let threadVM = CommentsThreadViewModel()
    private var rows: [CommentsThreadViewModel.CommentRow] = []
    private var cancellables: Set<AnyCancellable> = []
    private var headerImageTask: Task<Void, Never>?
    private var parsedTextCache: [String: String] = [:]
    private var pendingLastSeenID: Int?
    private var lastSeenTask: Task<Void, Never>?
    private var compactBarVisible = false
    private var animatedCommentIDs: Set<Int> = []

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let headerRoot = UIView()
    private let heroClipView = UIView()
    private let heroImageView = UIImageView()
    private let domainLabel = UILabel()
    private let titleLabel = UILabel()
    private let metaLabel = UILabel()
    private let scoreLabel = UILabel()
    private let commentCountLabel = UILabel()
    private let hintLabel = UILabel()
    private let readerButton = UIButton(type: .system)
    private let safariButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    private let trackThreadButton = UIButton(type: .system)
    private let collapseAllButton = UIButton(type: .system)
    private let expandAllButton = UIButton(type: .system)
    private var isThreadTracked = false

    private let compactBar = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let compactThumb = UIImageView()
    private let compactTitleLabel = UILabel()

    private let spinner = UIActivityIndicatorView(style: .medium)
    private let backgroundLabel = UILabel()
    private let searchController = UISearchController(searchResultsController: nil)
    private var headerWidthConstraint: NSLayoutConstraint?

    init(vm: VM, onOpenReader: ((Story) -> Void)?) {
        self.vm = vm
        self.onOpenReader = onOpenReader
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        configureNavigation()
        configureTableView()
        configureHeader()
        configureCompactBar()
        bindThreadState()
        bindAccountState()
        Task { await loadInitialState() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizeHeaderToFit()
    }

    func updateCallbacks(onOpenReader: ((Story) -> Void)?) {
        self.onOpenReader = onOpenReader
    }

    func refreshStoryMetadata() {
        guard let story = vm.story else { return }
        applyStory(story)
    }

    private func configureNavigation() {
        navigationItem.largeTitleDisplayMode = .never
        let bgColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = bgColor
        appearance.shadowColor = .clear
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search comments"
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = true
        tableView.contentInsetAdjustmentBehavior = .always
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 132
        tableView.register(UIKitCommentCell.self, forCellReuseIdentifier: UIKitCommentCell.reuseID)
        tableView.accessibilityLabel = "Comments list"
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureHeader() {
        headerRoot.backgroundColor = .clear
        headerRoot.translatesAutoresizingMaskIntoConstraints = false
        headerRoot.clipsToBounds = true
        let wc = headerRoot.widthAnchor.constraint(equalToConstant: tableView.bounds.width)
        wc.isActive = true
        headerWidthConstraint = wc

        heroClipView.translatesAutoresizingMaskIntoConstraints = false
        heroClipView.backgroundColor = UIColor(named: "CardColor") ?? .secondarySystemBackground
        heroClipView.clipsToBounds = true
        heroClipView.layer.masksToBounds = true
        heroClipView.layer.cornerRadius = 16
        heroClipView.layer.cornerCurve = .continuous
        heroClipView.layer.borderWidth = 1
        heroClipView.layer.borderColor = UIColor.label.withAlphaComponent(0.08).cgColor

        heroImageView.translatesAutoresizingMaskIntoConstraints = false
        heroImageView.contentMode = .scaleAspectFill
        heroImageView.clipsToBounds = true
        heroClipView.addSubview(heroImageView)

        domainLabel.font = .preferredFont(forTextStyle: .footnote).withTraits(.traitBold)
        domainLabel.textColor = .secondaryLabel
        domainLabel.numberOfLines = 1
        domainLabel.adjustsFontForContentSizeCategory = true

        titleLabel.font = .preferredFont(forTextStyle: .title2).withTraits(.traitBold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.adjustsFontForContentSizeCategory = true

        metaLabel.font = .preferredFont(forTextStyle: .subheadline)
        metaLabel.textColor = .secondaryLabel
        metaLabel.numberOfLines = 1
        metaLabel.adjustsFontForContentSizeCategory = true

        scoreLabel.font = .preferredFont(forTextStyle: .headline)
        scoreLabel.textColor = .label
        scoreLabel.numberOfLines = 1
        scoreLabel.adjustsFontForContentSizeCategory = true

        commentCountLabel.font = .preferredFont(forTextStyle: .title3).withTraits(.traitBold)
        commentCountLabel.textColor = .label
        commentCountLabel.adjustsFontForContentSizeCategory = true
        hintLabel.font = .preferredFont(forTextStyle: .caption1)
        hintLabel.textColor = .secondaryLabel
        hintLabel.text = "Tap thread lines to collapse"
        hintLabel.adjustsFontForContentSizeCategory = true

        configureIconButton(readerButton, systemName: "text.book.closed", action: #selector(openReader))
        configureIconButton(safariButton, systemName: "safari", action: #selector(openSafari))
        configureIconButton(shareButton, systemName: "square.and.arrow.up", action: #selector(shareStory))
        configureIconButton(trackThreadButton, systemName: "bell", action: #selector(toggleTrackThread))
        readerButton.accessibilityLabel = "Open Reader"
        readerButton.accessibilityHint = "Opens the article in reader mode."
        safariButton.accessibilityLabel = "Open Safari"
        safariButton.accessibilityHint = "Opens the source website in Safari."
        shareButton.accessibilityLabel = "Share story"
        trackThreadButton.accessibilityLabel = "Track thread"
        trackThreadButton.accessibilityHint = "Notifies you when new comments are posted."

        configurePillButton(collapseAllButton, title: "Collapse All", image: "rectangle.compress.vertical", action: #selector(collapseAll))
        configurePillButton(expandAllButton, title: "Expand All", image: "rectangle.expand.vertical", action: #selector(expandAll))
        collapseAllButton.accessibilityHint = "Collapses all comment threads."
        expandAllButton.accessibilityHint = "Expands all comment threads."

        let actionStack = UIStackView(arrangedSubviews: [UIView(), trackThreadButton, readerButton, safariButton, shareButton])
        actionStack.axis = .horizontal
        actionStack.alignment = .center
        actionStack.spacing = 10

        let scoreAndActions = UIStackView(arrangedSubviews: [scoreLabel, actionStack])
        scoreAndActions.axis = .horizontal
        scoreAndActions.alignment = .center
        scoreAndActions.spacing = 12

        let controlsStack = UIStackView(arrangedSubviews: [collapseAllButton, expandAllButton, UIView()])
        controlsStack.axis = .horizontal
        controlsStack.alignment = .center
        controlsStack.spacing = 12

        let countStack = UIStackView(arrangedSubviews: [commentCountLabel, hintLabel])
        countStack.axis = .vertical
        countStack.alignment = .leading
        countStack.spacing = 2

        let contentStack = UIStackView(arrangedSubviews: [
            heroClipView,
            domainLabel,
            titleLabel,
            metaLabel,
            scoreAndActions,
            controlsStack,
            countStack
        ])
        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        let horizontalPadding: CGFloat = 18

        headerRoot.addSubview(contentStack)
        NSLayoutConstraint.activate([
            heroImageView.topAnchor.constraint(equalTo: heroClipView.topAnchor),
            heroImageView.leadingAnchor.constraint(equalTo: heroClipView.leadingAnchor),
            heroImageView.trailingAnchor.constraint(equalTo: heroClipView.trailingAnchor),
            heroImageView.bottomAnchor.constraint(equalTo: heroClipView.bottomAnchor),

            heroClipView.heightAnchor.constraint(equalToConstant: 212),

            contentStack.topAnchor.constraint(equalTo: headerRoot.topAnchor, constant: 14),
            contentStack.leadingAnchor.constraint(equalTo: headerRoot.leadingAnchor, constant: horizontalPadding),
            contentStack.trailingAnchor.constraint(equalTo: headerRoot.trailingAnchor, constant: -horizontalPadding),
            contentStack.bottomAnchor.constraint(equalTo: headerRoot.bottomAnchor, constant: -18),
            
            // Keep hero image and title pinned to the same horizontal edges.
            heroClipView.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            heroClipView.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),

            readerButton.widthAnchor.constraint(equalToConstant: 44),
            readerButton.heightAnchor.constraint(equalToConstant: 44),
            safariButton.widthAnchor.constraint(equalToConstant: 44),
            safariButton.heightAnchor.constraint(equalToConstant: 44),
            shareButton.widthAnchor.constraint(equalToConstant: 44),
            shareButton.heightAnchor.constraint(equalToConstant: 44),
            trackThreadButton.widthAnchor.constraint(equalToConstant: 44),
            trackThreadButton.heightAnchor.constraint(equalToConstant: 44),
            collapseAllButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            expandAllButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])

        tableView.tableHeaderView = headerRoot
    }

    private func configureCompactBar() {
        compactBar.translatesAutoresizingMaskIntoConstraints = false
        compactBar.layer.cornerRadius = 14
        compactBar.layer.cornerCurve = .continuous
        compactBar.clipsToBounds = true
        compactBar.alpha = 0
        compactBar.transform = CGAffineTransform(scaleX: 0.96, y: 0.96).translatedBy(x: 0, y: -4)
        compactBar.isUserInteractionEnabled = false

        compactThumb.translatesAutoresizingMaskIntoConstraints = false
        compactThumb.contentMode = .scaleAspectFill
        compactThumb.clipsToBounds = true
        compactThumb.layer.cornerRadius = 10
        compactThumb.layer.cornerCurve = .continuous
        compactThumb.backgroundColor = UIColor(named: "CardColor") ?? .secondarySystemBackground

        compactTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        compactTitleLabel.font = .preferredFont(forTextStyle: .subheadline).withTraits(.traitBold)
        compactTitleLabel.textColor = .label
        compactTitleLabel.numberOfLines = 2
        compactTitleLabel.adjustsFontForContentSizeCategory = true

        compactBar.contentView.addSubview(compactThumb)
        compactBar.contentView.addSubview(compactTitleLabel)
        view.addSubview(compactBar)

        NSLayoutConstraint.activate([
            compactBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            compactBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            compactBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            compactThumb.leadingAnchor.constraint(equalTo: compactBar.contentView.leadingAnchor, constant: 12),
            compactThumb.topAnchor.constraint(equalTo: compactBar.contentView.topAnchor, constant: 10),
            compactThumb.bottomAnchor.constraint(lessThanOrEqualTo: compactBar.contentView.bottomAnchor, constant: -10),
            compactThumb.widthAnchor.constraint(equalToConstant: 44),
            compactThumb.heightAnchor.constraint(equalToConstant: 44),

            compactTitleLabel.leadingAnchor.constraint(equalTo: compactThumb.trailingAnchor, constant: 10),
            compactTitleLabel.trailingAnchor.constraint(equalTo: compactBar.contentView.trailingAnchor, constant: -12),
            compactTitleLabel.topAnchor.constraint(equalTo: compactBar.contentView.topAnchor, constant: 10),
            compactTitleLabel.bottomAnchor.constraint(equalTo: compactBar.contentView.bottomAnchor, constant: -10)
        ])
    }

    private func bindThreadState() {
        threadVM.$visibleRows
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rows in
                self?.rows = rows
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        threadVM.$loadState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.applyLoadState(state)
            }
            .store(in: &cancellables)
    }

    private func bindAccountState() {
        proFeatureGate.$isPro
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        hnAccount.$isLoggedIn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    private func loadInitialState() async {
        guard let story = vm.story else { return }
        applyStory(story)
        async let trackingRefresh: Void = refreshTrackingButtonState()
        async let commentsLoad: Void = threadVM.loadComments(using: vm, storyID: story.id)
        async let countsFetch = vm.getCommentAndPointCounts(forPostWithId: story.id)
        async let headerImageLoad: Void = loadHeaderImage(for: story)

        await commentsLoad
        _ = await trackingRefresh

        if let counts = await countsFetch {
            vm.story?.descendants = counts.0
            vm.story?.score = counts.1
            applyStory(vm.story ?? story)
        }
        await headerImageLoad
        resizeHeaderToFit()
    }

    private func applyStory(_ story: Story) {
        domainLabel.text = story.url?.urlDomain
        titleLabel.text = story.title
        compactTitleLabel.text = story.title
        metaLabel.text = "\(Date.getTimeInterval(with: story.time))  |  \(story.by)"
        scoreLabel.text = story.score == 1 ? "\(story.score) point" : "\(story.score) points"
        if let count = story.descendants {
            commentCountLabel.text = count == 1 ? "\(count) comment" : "\(count) comments"
        } else {
            commentCountLabel.text = "Comments"
        }
        titleLabel.accessibilityLabel = story.title
        metaLabel.accessibilityLabel = "By \(story.by), \(Date.getTimeInterval(with: story.time))"
    }

    private func applyLoadState(_ state: LoadState) {
        switch state {
        case .idle, .loading:
            spinner.startAnimating()
            tableView.backgroundView = spinner
        case .empty:
            backgroundLabel.text = "No comments yet."
            backgroundLabel.textColor = .secondaryLabel
            backgroundLabel.textAlignment = .center
            tableView.backgroundView = backgroundLabel
        case .error(let message, _):
            backgroundLabel.text = message
            backgroundLabel.textColor = .secondaryLabel
            backgroundLabel.textAlignment = .center
            backgroundLabel.numberOfLines = 0
            tableView.backgroundView = backgroundLabel
        case .loaded:
            spinner.stopAnimating()
            tableView.backgroundView = nil
        }
    }

    private var lastHeaderSize: CGSize = .zero

    private func resizeHeaderToFit() {
        guard tableView.tableHeaderView != nil else { return }
        let width = tableView.bounds.width
        guard width > 0 else { return }
        headerWidthConstraint?.constant = width
        let targetSize = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        let height = headerRoot.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        let newSize = CGSize(width: width, height: height)
        // Only reassign tableHeaderView when size actually changes (avoids layout loop)
        if abs(newSize.width - lastHeaderSize.width) > 0.5 || abs(newSize.height - lastHeaderSize.height) > 0.5 {
            lastHeaderSize = newSize
            headerRoot.frame = CGRect(origin: .zero, size: newSize)
            tableView.tableHeaderView = headerRoot
        }
    }

    private func configureIconButton(_ button: UIButton, systemName: String, action: Selector) {
        let highContrast = HighContrastTheme.shared.isEnabled
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        button.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        button.tintColor = .label
        button.backgroundColor = UIColor.tertiarySystemFill
        button.layer.cornerRadius = 12
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.label.withAlphaComponent(highContrast ? 0.24 : 0.06).cgColor
        button.clipsToBounds = true
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func configurePillButton(_ button: UIButton, title: String, image: String, action: Selector) {
        let highContrast = HighContrastTheme.shared.isEnabled
        var cfg = UIButton.Configuration.plain()
        cfg.title = title
        cfg.image = UIImage(systemName: image)
        cfg.imagePadding = 6
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        button.configuration = cfg
        button.backgroundColor = UIColor.tertiarySystemFill
        button.layer.cornerRadius = 18
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.label.withAlphaComponent(highContrast ? 0.24 : 0.06).cgColor
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func loadHeaderImage(for story: Story) async {
        guard let storyURL = story.url else {
            heroImageView.image = nil
            compactThumb.image = nil
            return
        }
        let key = String(story.id)
        let availabilityCache = UltimatePostViewModel.ImageAvailabilityCache.instance
        let urlCache = UltimatePostViewModel.ImageURLCache.instance

        if let cachedURL = urlCache.getFromCache(withKey: key) {
            await setHeaderImage(from: cachedURL)
            return
        }

        if let cachedAvailability = availabilityCache.getFromCache(withKey: key), cachedAvailability == false {
            heroImageView.image = nil
            compactThumb.image = nil
            return
        }

        let resultURL = await vm.networkManager.getImage(fromUrl: storyURL)
        if let resultURL {
            urlCache.saveToCache(resultURL, withKey: key)
            availabilityCache.saveToCache(true, withKey: key)
            await setHeaderImage(from: resultURL)
        } else {
            availabilityCache.saveToCache(false, withKey: key)
            heroImageView.image = nil
            compactThumb.image = nil
        }
    }

    private func setHeaderImage(from url: URL) async {
        headerImageTask?.cancel()
        headerImageTask = Task { [weak self] in
            guard let self else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, let image = UIImage(data: data) else { return }
                UIView.transition(with: self.heroImageView, duration: 0.22, options: .transitionCrossDissolve) {
                    self.heroImageView.image = image
                }
                self.compactThumb.image = image
            } catch {
                self.heroImageView.image = nil
                self.compactThumb.image = nil
            }
        }
    }

    private func plainText(for comment: Comment) -> String {
        guard let html = comment.text, !html.isEmpty else { return "" }
        if let cached = parsedTextCache[html] {
            return cached
        }
        if let cachedAttributed = AttributedStringCache.instance.get(forKey: html) {
            let text = String(cachedAttributed.characters)
            parsedTextCache[html] = text
            return text
        }
        let parsed = CommentHTMLParser.parse(html)
        let text = String(parsed.characters)
        AttributedStringCache.instance.set(parsed, forKey: html)
        parsedTextCache[html] = text
        return text
    }

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

    @objc private func openReader() {
        guard let story = vm.story else { return }
        onOpenReader?(story)
    }

    @objc private func openSafari() {
        guard let urlString = vm.story?.url,
              let url = URL(string: NetworkManager.instance.getSecureUrlString(url: urlString)) else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    @objc private func shareStory() {
        guard let url = vm.story?.url else { return }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(activity, animated: true)
    }

    @objc private func toggleTrackThread() {
        guard proFeatureGate.isPro else {
            proFeatureGate.triggerPaywall(from: self)
            return
        }
        guard let story = vm.story else { return }

        Task {
            await NotificationManager.shared.requestAuthorizationIfNeeded()
            if await NotificationStore.shared.isTracked(storyID: story.id) {
                await NotificationStore.shared.remove(storyID: story.id)
                isThreadTracked = false
#if canImport(ActivityKit)
                if #available(iOS 16.1, *) {
                    await LiveActivityManager.shared.stop(storyID: story.id)
                }
#endif
                showMessage("Thread untracked.")
            } else {
                let initialCount = story.descendants ?? 0
                await NotificationStore.shared.upsert(
                    TrackedStory(storyID: story.id, title: story.title, lastSeenCommentCount: initialCount)
                )
                isThreadTracked = true
#if canImport(ActivityKit)
                if #available(iOS 16.1, *) {
                    await LiveActivityManager.shared.start(story: story)
                }
#endif
                showMessage("Thread tracking enabled.")
            }
            await refreshTrackingButtonState()
        }
    }

    @objc private func collapseAll() {
        threadVM.collapseTopLevel()
    }

    @objc private func expandAll() {
        threadVM.expandTopLevel()
    }

    private func ensureProAndLogin() -> Bool {
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

    private func handleCommentUpvote(commentID: Int) {
        guard ensureProAndLogin() else { return }
        Task {
            do {
                let result = try await hnAccount.upvoteComment(id: commentID)
                switch result {
                case .voted:
                    showMessage("Upvoted.")
                case .alreadyVoted:
                    showMessage("Already upvoted.")
                case .verificationFailed:
                    showMessage("Upvote sent but verification failed.")
                }
            } catch {
                showMessage(error.localizedDescription)
            }
        }
    }

    private func presentReplyComposer(for comment: Comment) {
        guard ensureProAndLogin() else { return }
        let replyVC = ReplyViewController(commentId: comment.id, storyId: vm.story?.id)
        let navController = UINavigationController(rootViewController: replyVC)
        navController.modalPresentationStyle = .formSheet
        present(navController, animated: true)
    }

    private func openUserProfile(username: String) {
        guard proFeatureGate.isPro else {
            proFeatureGate.triggerPaywall(from: self)
            return
        }
        navigationController?.pushViewController(UserProfileViewController(username: username), animated: true)
    }

    private func showMessage(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            alert.dismiss(animated: true)
        }
    }

    private func refreshTrackingButtonState() async {
        guard let story = vm.story else { return }
        let tracked = await NotificationStore.shared.isTracked(storyID: story.id)
        isThreadTracked = tracked
        let imageName = tracked ? "bell.fill" : "bell"
        let tint: UIColor = tracked ? .systemOrange : .label
        trackThreadButton.setImage(UIImage(systemName: imageName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)), for: .normal)
        trackThreadButton.tintColor = tint
        trackThreadButton.accessibilityLabel = tracked ? "Thread tracked" : "Track thread"
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: UIKitCommentCell.reuseID, for: indexPath) as? UIKitCommentCell else {
            return UITableViewCell()
        }
        let row = rows[indexPath.row]
        let isCollapsed = threadVM.isCollapsed(row.id)
        let canWriteActions = proFeatureGate.isPro && hnAccount.isLoggedIn
        cell.configure(
            row: row,
            isCollapsed: isCollapsed,
            text: plainText(for: row.comment),
            canWriteActions: canWriteActions,
            canOpenAuthorProfile: proFeatureGate.isPro,
            onUpvote: { [weak self] in
                self?.handleCommentUpvote(commentID: row.comment.id)
            },
            onReply: { [weak self] in
                self?.presentReplyComposer(for: row.comment)
            },
            onOpenAuthorProfile: { [weak self] in
                guard let author = row.comment.author else { return }
                self?.openUserProfile(username: author)
            },
            onToggle: { [weak self] in
                self?.threadVM.toggleCollapse(row.id)
            }
        )
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard indexPath.row < rows.count else { return }
        let row = rows[indexPath.row]
        scheduleLastSeenUpdate(commentID: row.id)
        guard !animatedCommentIDs.contains(row.id) else { return }
        animatedCommentIDs.insert(row.id)
        // Only animate first batch of comments to avoid animation overhead during fast scrolling
        guard animatedCommentIDs.count <= 30 else { return }
        cell.alpha = 0
        cell.transform = CGAffineTransform(translationX: 0, y: 8)
        UIView.animate(
            withDuration: 0.26,
            delay: min(Double(indexPath.row) * 0.012, 0.12),
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            cell.alpha = 1
            cell.transform = .identity
        }
    }

    // MARK: - UISearchResultsUpdating

    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text ?? ""
        threadVM.applySearch(query: query)
    }

    // MARK: - UIScrollViewDelegate

    private var lastParallaxProgress: CGFloat = -1

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let progress = max(0, min(1, scrollView.contentOffset.y / 200))

        let shouldShowCompactBar = progress > 0.38
        if shouldShowCompactBar != compactBarVisible {
            compactBarVisible = shouldShowCompactBar
            UIView.animate(
                withDuration: 0.28,
                delay: 0,
                usingSpringWithDamping: 0.92,
                initialSpringVelocity: 0.2,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                self.compactBar.alpha = shouldShowCompactBar ? 1 : 0
                self.compactBar.transform = shouldShowCompactBar
                    ? .identity
                    : CGAffineTransform(scaleX: 0.96, y: 0.96).translatedBy(x: 0, y: -4)
            }
        }

        // Only update parallax transform when progress actually changes
        if abs(progress - lastParallaxProgress) > 0.005 {
            lastParallaxProgress = progress
            let scaleX = 1 - (0.12 * progress)
            let scaleY = 1 - (0.08 * progress)
            let translateY = -18 * progress
            heroImageView.transform = CGAffineTransform.identity
                .translatedBy(x: 0, y: translateY)
                .scaledBy(x: scaleX, y: scaleY)
            heroClipView.alpha = 1 - progress
        }
    }
}

private final class UIKitCommentCell: UITableViewCell {
    static let reuseID = "UIKitCommentCell"

    private let card = UIView()
    private let threadLine = UIView()
    private let topMetaLabel = UILabel()
    private let bodyLabel = UILabel()
    private let actionsRow = UIStackView()
    private let upvoteButton = UIButton(type: .system)
    private let replyButton = UIButton(type: .system)
    private let collapseButton = UIButton(type: .system)
    private var indentConstraint: NSLayoutConstraint?
    private var onToggle: (() -> Void)?
    private var onUpvote: (() -> Void)?
    private var onReply: (() -> Void)?
    private var onOpenAuthorProfile: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(named: "CardColor") ?? .secondarySystemBackground
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.label.withAlphaComponent(HighContrastTheme.shared.isEnabled ? 0.24 : 0.05).cgColor

        threadLine.translatesAutoresizingMaskIntoConstraints = false
        threadLine.layer.cornerRadius = 1

        topMetaLabel.translatesAutoresizingMaskIntoConstraints = false
        topMetaLabel.font = .preferredFont(forTextStyle: .subheadline).withTraits(.traitBold)
        topMetaLabel.textColor = .secondaryLabel
        topMetaLabel.numberOfLines = 1
        topMetaLabel.adjustsFontForContentSizeCategory = true
        topMetaLabel.isUserInteractionEnabled = true
        topMetaLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(authorTapped)))

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = .preferredFont(forTextStyle: .body)
        bodyLabel.textColor = .label
        bodyLabel.numberOfLines = 0
        bodyLabel.adjustsFontForContentSizeCategory = true

        collapseButton.translatesAutoresizingMaskIntoConstraints = false
        collapseButton.setImage(UIImage(systemName: "chevron.up", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)), for: .normal)
        collapseButton.tintColor = .secondaryLabel
        collapseButton.backgroundColor = UIColor.tertiarySystemFill
        collapseButton.layer.cornerRadius = 22
        collapseButton.layer.cornerCurve = .continuous
        collapseButton.clipsToBounds = true
        collapseButton.accessibilityLabel = "Collapse thread"
        collapseButton.accessibilityHint = "Toggles collapsed state for this comment branch."
        collapseButton.addTarget(self, action: #selector(toggleTapped), for: .touchUpInside)

        upvoteButton.translatesAutoresizingMaskIntoConstraints = false
        upvoteButton.setImage(UIImage(systemName: "arrow.up"), for: .normal)
        upvoteButton.tintColor = .systemOrange
        upvoteButton.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.12)
        upvoteButton.layer.cornerRadius = 22
        upvoteButton.layer.cornerCurve = .continuous
        upvoteButton.clipsToBounds = true
        upvoteButton.accessibilityLabel = "Upvote comment"
        upvoteButton.accessibilityHint = "Sends an upvote for this comment."
        upvoteButton.addTarget(self, action: #selector(upvoteTapped), for: .touchUpInside)

        replyButton.translatesAutoresizingMaskIntoConstraints = false
        replyButton.setImage(UIImage(systemName: "arrowshape.turn.up.left"), for: .normal)
        replyButton.tintColor = .systemOrange
        replyButton.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.12)
        replyButton.layer.cornerRadius = 22
        replyButton.layer.cornerCurve = .continuous
        replyButton.clipsToBounds = true
        replyButton.accessibilityLabel = "Reply to comment"
        replyButton.accessibilityHint = "Composes a reply."
        replyButton.addTarget(self, action: #selector(replyTapped), for: .touchUpInside)

        actionsRow.translatesAutoresizingMaskIntoConstraints = false
        actionsRow.axis = .horizontal
        actionsRow.spacing = 8
        actionsRow.alignment = .center
        actionsRow.addArrangedSubview(upvoteButton)
        actionsRow.addArrangedSubview(replyButton)

        let metaRow = UIStackView(arrangedSubviews: [topMetaLabel, UIView(), actionsRow, collapseButton])
        metaRow.axis = .horizontal
        metaRow.alignment = .center
        metaRow.spacing = 8
        metaRow.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(metaRow)
        card.addSubview(bodyLabel)

        contentView.addSubview(card)
        contentView.addSubview(threadLine)

        indentConstraint = card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12)
        indentConstraint?.isActive = true

        NSLayoutConstraint.activate([
            threadLine.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            threadLine.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 7),
            threadLine.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -7),
            threadLine.widthAnchor.constraint(equalToConstant: 2),

            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -7),

            metaRow.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            metaRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            metaRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),

            bodyLabel.topAnchor.constraint(equalTo: metaRow.bottomAnchor, constant: 10),
            bodyLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            bodyLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            bodyLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),

            upvoteButton.widthAnchor.constraint(equalToConstant: 44),
            upvoteButton.heightAnchor.constraint(equalToConstant: 44),
            replyButton.widthAnchor.constraint(equalToConstant: 44),
            replyButton.heightAnchor.constraint(equalToConstant: 44),
            collapseButton.widthAnchor.constraint(equalToConstant: 44),
            collapseButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        bodyLabel.text = nil
        topMetaLabel.text = nil
        onToggle = nil
        onUpvote = nil
        onReply = nil
        onOpenAuthorProfile = nil
        alpha = 1
        transform = .identity
    }

    func configure(
        row: CommentsThreadViewModel.CommentRow,
        isCollapsed: Bool,
        text: String,
        canWriteActions: Bool,
        canOpenAuthorProfile: Bool,
        onUpvote: @escaping () -> Void,
        onReply: @escaping () -> Void,
        onOpenAuthorProfile: @escaping () -> Void,
        onToggle: @escaping () -> Void
    ) {
        self.onToggle = onToggle
        self.onUpvote = onUpvote
        self.onReply = onReply
        self.onOpenAuthorProfile = onOpenAuthorProfile
        let visualDepth = min(row.depth, 6)
        indentConstraint?.constant = CGFloat(visualDepth) * 12 + 12
        threadLine.backgroundColor = Self.threadColor(depth: row.depth)
        threadLine.alpha = visualDepth > 0 ? 1 : 0
        actionsRow.isHidden = !canWriteActions
        card.layer.borderColor = UIColor.label.withAlphaComponent(HighContrastTheme.shared.isEnabled ? 0.24 : 0.05).cgColor

        let author = row.comment.author ?? "Unknown"
        let interval = Date.getTimeInterval(with: row.comment.createdAtI)
        topMetaLabel.textColor = canOpenAuthorProfile ? .systemOrange : .secondaryLabel
        topMetaLabel.isUserInteractionEnabled = canOpenAuthorProfile
        topMetaLabel.accessibilityTraits = canOpenAuthorProfile ? [.button] : [.staticText]
        topMetaLabel.accessibilityHint = canOpenAuthorProfile ? "Opens \(author)'s profile." : nil
        if isCollapsed {
            topMetaLabel.text = "\(author) • \(row.descendantCount) \(row.descendantCount == 1 ? "reply" : "replies")"
            bodyLabel.text = nil
            collapseButton.setImage(UIImage(systemName: "chevron.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)), for: .normal)
            collapseButton.accessibilityLabel = "Expand thread"
        } else {
            topMetaLabel.text = "\(author) • \(interval)"
            bodyLabel.text = text
            collapseButton.setImage(UIImage(systemName: "chevron.up", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)), for: .normal)
            collapseButton.accessibilityLabel = "Collapse thread"
        }
        accessibilityLabel = "Comment by \(author). \(isCollapsed ? "Collapsed" : "Expanded")"
    }

    @objc private func toggleTapped() {
        UIView.animate(withDuration: 0.08, animations: {
            self.collapseButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.12) {
                self.collapseButton.transform = .identity
            }
        }
        onToggle?()
    }

    @objc private func upvoteTapped() {
        onUpvote?()
    }

    @objc private func replyTapped() {
        onReply?()
    }

    @objc private func authorTapped() {
        onOpenAuthorProfile?()
    }

    private static func threadColor(depth: Int) -> UIColor {
        let colors: [UIColor] = [
            UIColor.systemBlue.withAlphaComponent(0.6),
            UIColor.systemPurple.withAlphaComponent(0.6),
            UIColor.systemGreen.withAlphaComponent(0.6),
            UIColor.systemOrange.withAlphaComponent(0.6),
            UIColor.systemPink.withAlphaComponent(0.6),
            UIColor.systemTeal.withAlphaComponent(0.6)
        ]
        return colors[depth % colors.count]
    }
}

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
