import UIKit

final class FeedStoryCell: UITableViewCell {
    static let reuseID = "FeedStoryCell"

    var onOpenSource: (() -> Void)?
    var onOpenComments: (() -> Void)?
    var onShare: (() -> Void)?
    var onBookmark: (() -> Void)?
    var onUpvote: (() -> Void)?
    var onSaveOffline: (() -> Void)?
    var onOpenAuthorProfile: (() -> Void)?
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
    private let upvoteButton = UIButton(type: .system)
    private let offlineButton = UIButton(type: .system)
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
    private var titleTopConstraint: NSLayoutConstraint?
    private var metaTopConstraint: NSLayoutConstraint?
    private var dividerTopConstraint: NSLayoutConstraint?
    private var dividerHeightConstraint: NSLayoutConstraint?
    private var actionsTopConstraint: NSLayoutConstraint?
    private var actionsBottomConstraint: NSLayoutConstraint?

    private static let normalImageHeight: CGFloat = 200
    private static let compactImageHeight: CGFloat = 120
    private var currentImageHeight: CGFloat = normalImageHeight

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
        shimmerLayer.stopAnimating()
        setImageVisible(false, animated: false)
    }

    func cancelImageLoad() {
        imageTask?.cancel()
        imageTask = nil
        shimmerLayer.stopAnimating()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shimmerLayer.frame = shimmerView.bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateDisplayScaleMetrics()
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
        // Rasterize to avoid re-rendering shadow every frame during scroll
        card.layer.shouldRasterize = true
        card.layer.rasterizationScale = traitCollection.displayScale
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
        titleRow.isAccessibilityElement = true
        titleRow.accessibilityTraits = [.button]
        titleRow.accessibilityHint = "Opens the article in Safari."

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
        metaLabel.isUserInteractionEnabled = true
        metaLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(metaTapped)))
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
        upvoteButton.addAction(UIAction { [weak self] _ in self?.onUpvote?() }, for: .touchUpInside)
        offlineButton.addAction(UIAction { [weak self] _ in self?.onSaveOffline?() }, for: .touchUpInside)
        shareButton.addAction(UIAction { [weak self] _ in self?.onShare?() }, for: .touchUpInside)
        bookmarkButton.addAction(UIAction { [weak self] _ in self?.onBookmark?() }, for: .touchUpInside)
        commentsButton.accessibilityHint = "Opens the comments thread."
        upvoteButton.accessibilityLabel = "Upvote story"
        upvoteButton.accessibilityHint = "Sends an upvote with your Hacker News account."
        offlineButton.accessibilityLabel = "Save offline"
        offlineButton.accessibilityHint = "Downloads this story for offline reading."
        shareButton.accessibilityLabel = "Share story"
        bookmarkButton.accessibilityLabel = "Save bookmark"
        bookmarkButton.accessibilityHint = "Saves this story to your bookmarks."

        actionsBar.axis = .horizontal
        actionsBar.alignment = .center
        actionsBar.spacing = 4
        actionsBar.translatesAutoresizingMaskIntoConstraints = false
    }

    private func makeActionButton(systemName: String, title: String? = nil, compact: Bool = false) -> UIButton.Configuration {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.baseForegroundColor = .secondaryLabel
        config.baseBackgroundColor = .quaternarySystemFill
        let compactInset: CGFloat = compact ? 6 : 7
        let horizontalInset: CGFloat = compact ? 10 : 12
        config.contentInsets = NSDirectionalEdgeInsets(top: compactInset, leading: horizontalInset, bottom: compactInset, trailing: horizontalInset)
        let symbolSize: CGFloat = compact ? 12 : 13
        config.image = UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium))
        if let title {
            config.imagePadding = 5
            var titleAttr = AttributeContainer()
            let titleSize: CGFloat = compact ? 12 : 13
            titleAttr.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .systemFont(ofSize: titleSize, weight: .semibold))
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
        actionsBar.addArrangedSubview(upvoteButton)
        actionsBar.addArrangedSubview(offlineButton)
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
        titleTopConstraint = titleRow.topAnchor.constraint(equalTo: domainPill.bottomAnchor, constant: 8)
        metaTopConstraint = metaLabel.topAnchor.constraint(equalTo: titleRow.bottomAnchor, constant: 6)
        dividerTopConstraint = divider.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 12)
        dividerHeightConstraint = divider.heightAnchor.constraint(equalToConstant: 1.0 / max(traitCollection.displayScale, 1))
        actionsTopConstraint = actionsBar.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 8)
        actionsBottomConstraint = actionsBar.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10)

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
            titleTopConstraint!,
            titleRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            titleRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            titleRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            titleLabel.topAnchor.constraint(equalTo: titleRow.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: titleRow.leadingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: titleRow.bottomAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: safariIndicator.leadingAnchor, constant: -6),

            safariIndicator.centerYAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor, constant: -2),
            safariIndicator.trailingAnchor.constraint(equalTo: titleRow.trailingAnchor),
            safariIndicator.widthAnchor.constraint(equalToConstant: 14),
            safariIndicator.heightAnchor.constraint(equalToConstant: 14),

            // Meta
            metaTopConstraint!,
            metaLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            metaLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            // Divider
            dividerTopConstraint!,
            divider.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            divider.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            dividerHeightConstraint!,

            // Actions bar
            actionsTopConstraint!,
            actionsBar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            actionsBar.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            actionsBottomConstraint!,

            // Points badge internal
            pointsIcon.leadingAnchor.constraint(equalTo: pointsBadge.leadingAnchor),
            pointsIcon.centerYAnchor.constraint(equalTo: pointsBadge.centerYAnchor),
            pointsIcon.widthAnchor.constraint(equalToConstant: 14),
            pointsIcon.heightAnchor.constraint(equalToConstant: 14),
            pointsLabel.leadingAnchor.constraint(equalTo: pointsIcon.trailingAnchor, constant: 2),
            pointsLabel.trailingAnchor.constraint(equalTo: pointsBadge.trailingAnchor),
            pointsLabel.centerYAnchor.constraint(equalTo: pointsBadge.centerYAnchor),
            pointsBadge.heightAnchor.constraint(equalToConstant: 28),

            commentsButton.heightAnchor.constraint(equalToConstant: 44),
            upvoteButton.heightAnchor.constraint(equalToConstant: 44),
            offlineButton.heightAnchor.constraint(equalToConstant: 44),
            shareButton.heightAnchor.constraint(equalToConstant: 44),
            bookmarkButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private var displayScale: CGFloat {
        max(window?.screen.scale ?? traitCollection.displayScale, 1)
    }

    private func updateDisplayScaleMetrics() {
        let scale = displayScale
        card.layer.rasterizationScale = scale
        dividerHeightConstraint?.constant = 1.0 / scale
    }

    private func applyCardStyle(_ style: Settings.CardStyle) {
        let isCompact = style == .compact

        currentImageHeight = isCompact ? Self.compactImageHeight : Self.normalImageHeight
        titleLabel.numberOfLines = isCompact ? 2 : 3

        domainLabel.font = UIFontMetrics(forTextStyle: .caption2)
            .scaledFont(for: .systemFont(ofSize: isCompact ? 10 : 11, weight: .bold))
        titleLabel.font = UIFontMetrics(forTextStyle: .headline)
            .scaledFont(for: .systemFont(ofSize: isCompact ? 15 : 17, weight: .semibold))
        metaLabel.font = UIFontMetrics(forTextStyle: .caption1)
            .scaledFont(for: .systemFont(ofSize: isCompact ? 11 : 12, weight: .regular))
        pointsLabel.font = UIFontMetrics(forTextStyle: .caption1)
            .scaledFont(for: .systemFont(ofSize: isCompact ? 11 : 12, weight: .bold))

        imageContainerTopConstraint?.constant = isCompact ? 10 : 12
        domainTopToImageConstraint?.constant = isCompact ? 8 : 12
        domainTopToCardConstraint?.constant = isCompact ? 12 : 14
        titleTopConstraint?.constant = isCompact ? 6 : 8
        metaTopConstraint?.constant = isCompact ? 4 : 6
        dividerTopConstraint?.constant = isCompact ? 8 : 12
        actionsTopConstraint?.constant = isCompact ? 6 : 8
        actionsBottomConstraint?.constant = isCompact ? -8 : -10

        actionsBar.spacing = isCompact ? 3 : 4
    }

    // MARK: - Configure

    func configure(
        story: Story,
        isRead: Bool,
        isSaved: Bool,
        style: Settings.CardStyle,
        canWriteActions: Bool,
        canOpenAuthorProfile: Bool,
        canSaveOffline: Bool,
        isOfflineSaved: Bool,
        isOfflineDownloading: Bool
    ) {
        currentStoryID = story.id
        let isCompact = style == .compact
        applyCardStyle(style)

        // Domain
        let domain = story.url.flatMap(URL.init(string:))?.host?.replacingOccurrences(of: "www.", with: "") ?? "news.ycombinator.com"
        domainLabel.text = domain

        // Title
        titleLabel.text = story.title
        titleLabel.textColor = isRead ? .secondaryLabel : .label
        titleRow.accessibilityLabel = story.title

        // Safari indicator visibility
        safariIndicator.isHidden = story.url == nil || story.url?.isEmpty == true

        // Meta
        metaLabel.text = "\(story.by) · \(Date.getTimeInterval(with: story.time))"
        metaLabel.textColor = canOpenAuthorProfile ? .systemOrange : .tertiaryLabel
        metaLabel.isUserInteractionEnabled = canOpenAuthorProfile
        metaLabel.accessibilityTraits = canOpenAuthorProfile ? [.button] : [.staticText]
        metaLabel.accessibilityHint = canOpenAuthorProfile ? "Opens \(story.by)'s profile." : nil

        // Points
        pointsLabel.text = "\(story.score)"

        // Comments button
        let comments = story.descendants ?? 0
        commentsButton.configuration = makeActionButton(systemName: "bubble.right", title: "\(comments)", compact: isCompact)
        commentsButton.accessibilityLabel = "\(comments) comments"

        // Upvote button (Pro + logged in)
        upvoteButton.configuration = makeActionButton(systemName: "arrow.up", compact: isCompact)
        upvoteButton.isHidden = !canWriteActions

        // Offline button (Pro)
        var offlineConfig = makeActionButton(systemName: "arrow.down.circle", compact: isCompact)
        offlineConfig.baseForegroundColor = .systemOrange
        if isOfflineDownloading {
            offlineConfig.showsActivityIndicator = true
            offlineConfig.image = nil
            offlineButton.accessibilityLabel = "Saving offline"
        } else if isOfflineSaved {
            offlineConfig.image = UIImage(systemName: "checkmark.circle.fill")
            offlineConfig.baseBackgroundColor = UIColor.systemOrange.withAlphaComponent(0.12)
            offlineButton.accessibilityLabel = "Saved offline"
        } else {
            offlineButton.accessibilityLabel = "Save offline"
        }
        offlineButton.configuration = offlineConfig
        offlineButton.isHidden = !canSaveOffline
        offlineButton.isEnabled = !isOfflineSaved && !isOfflineDownloading

        // Share button
        shareButton.configuration = makeActionButton(systemName: "square.and.arrow.up", compact: isCompact)

        // Bookmark button
        var bmConfig = makeActionButton(systemName: isSaved ? "bookmark.fill" : "bookmark", compact: isCompact)
        if isSaved {
            bmConfig.baseForegroundColor = .systemOrange
            bmConfig.baseBackgroundColor = UIColor.systemOrange.withAlphaComponent(0.12)
            bookmarkButton.accessibilityLabel = "Bookmarked"
        } else {
            bookmarkButton.accessibilityLabel = "Save bookmark"
        }
        bookmarkButton.configuration = bmConfig
        bookmarkButton.isEnabled = !isSaved

        // Read state
        let highContrast = HighContrastTheme.shared.isEnabled
        card.alpha = isRead ? (highContrast ? 0.9 : 0.75) : 1.0
        card.layer.borderWidth = highContrast ? 1 : 0
        card.layer.borderColor = UIColor.label.withAlphaComponent(highContrast ? 0.24 : 0.08).cgColor
        divider.backgroundColor = highContrast ? UIColor.label.withAlphaComponent(0.28) : .separator

        loadThumbnail(for: story)
    }

    @objc private func titleTapped() {
        onOpenSource?()
    }

    @objc private func metaTapped() {
        onOpenAuthorProfile?()
    }

    // MARK: - Image Loading

    private func setImageVisible(_ visible: Bool, animated: Bool) {
        let showImage = visible
        let height: CGFloat = showImage ? currentImageHeight : 0

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
    }

    private static let availabilityCache = UltimatePostViewModel.ImageAvailabilityCache.instance

    private func loadThumbnail(for story: Story) {
        imageTask?.cancel()
        imageTask = nil

        guard story.url?.isEmpty == false else {
            heroImage.image = nil
            heroImage.alpha = 0
            setImageVisible(false, animated: false)
            return
        }

        // 1. Check in-memory UIImage cache (instant)
        if let cached = FeedImagePipeline.cachedImage(for: story.id) {
            heroImage.image = cached
            heroImage.alpha = 1
            shimmerView.isHidden = true
            placeholderIcon.isHidden = true
            shimmerLayer.stopAnimating()
            setImageVisible(true, animated: false)
            return
        }

        // 2. Check availability cache synchronously — if we already know there's
        //    no image, collapse immediately to avoid height changes during scroll.
        if let knownAvailable = Self.availabilityCache.getFromCache(withKey: String(story.id)),
           knownAvailable == false {
            heroImage.image = nil
            heroImage.alpha = 0
            setImageVisible(false, animated: false)
            return
        }

        // 3. Show shimmer placeholder only if we think an image might exist
        heroImage.image = nil
        heroImage.alpha = 0
        setImageVisible(true, animated: false)

        imageTask = Task { [weak self] in
            guard let self, let pipeline = self.imagePipeline else { return }

            let image = await pipeline.image(for: story)
            guard !Task.isCancelled else { return }
            guard self.currentStoryID == story.id else { return }
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
                // Notify tableView that this cell's height changed so it can
                // adjust contentSize without a full reload (prevents scroll jumps)
                if let tableView = self.superview as? UITableView {
                    UIView.performWithoutAnimation {
                        tableView.beginUpdates()
                        tableView.endUpdates()
                    }
                }
            }
        }
    }
}
