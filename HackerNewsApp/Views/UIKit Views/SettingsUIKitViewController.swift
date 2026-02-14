import UIKit
import Combine

@MainActor
final class SettingsUIKitViewController: UIViewController {
    private let globalSettings: GlobalSettingsViewModel
    private let hnAccount = HNAccount.shared
    private let proFeatureGate = ProFeatureGate.shared
    private let subscriptionManager = SubscriptionManager.shared
    private let customFeedManager = CustomFeedManager.shared
    private var cancellables: Set<AnyCancellable> = []

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let cardStyleControl = UISegmentedControl(items: Settings.CardStyle.allCases.map(\.rawValue))
    private let themeControl = UISegmentedControl(items: Settings.Theme.allCases.map(\.rawValue))
    private let accentColorControl = UISegmentedControl(items: Settings.AccentColor.allCases.map(\.rawValue))
    private let fontFamilyControl = UISegmentedControl(items: Settings.FontFamily.allCases.map(\.rawValue))
    private let openInReaderSwitch = UISwitch()
    private let openReaderLinksSwitch = UISwitch()
    private let iCloudSyncSwitch = UISwitch()
    private let highContrastSwitch = UISwitch()
#if DEBUG || targetEnvironment(simulator)
    private let debugForceProSwitch = UISwitch()
#endif
    private let fontScaleSlider = UISlider()
    private let lineSpacingSlider = UISlider()
    private let fontScaleValueLabel = UILabel()
    private let lineSpacingValueLabel = UILabel()
    private let hnAccountSubtitleLabel = UILabel()
    private let proSubscriptionSubtitleLabel = UILabel()
    private let customFeedsSubtitleLabel = UILabel()
    private let trackedThreadsSubtitleLabel = UILabel()
    private let legalSubtitleLabel = UILabel()
    private let shareImportSubtitleLabel = UILabel()
    private let performanceSubtitleLabel = UILabel()
    private let proPrimaryButton = UIButton(type: .system)
    private let proRestoreButton = UIButton(type: .system)
    private var proSubscriptionStatusMessage: String?

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
        bindAccountState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshProSubscriptionCard()
        refreshTrackedThreadsSubtitle()
        refreshLegalSubtitle()
        refreshShareImportSubtitle()
        refreshPerformanceSubtitle()
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
        stack.addArrangedSubview(makeCard(title: "Accent Color (Pro)", body: accentColorControl))
        stack.addArrangedSubview(makeCard(title: "Font Family (Pro)", body: fontFamilyControl))
        stack.addArrangedSubview(makeProSubscriptionCard())

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

        stack.addArrangedSubview(makeSwitchCard(
            title: "iCloud Sync",
            subtitle: "Sync settings, read state, and bookmarks across devices (Pro).",
            control: iCloudSyncSwitch
        ))

        stack.addArrangedSubview(makeSwitchCard(
            title: "High Contrast",
            subtitle: "Increase borders and contrast for stronger readability.",
            control: highContrastSwitch
        ))

#if DEBUG || targetEnvironment(simulator)
        stack.addArrangedSubview(makeSwitchCard(
            title: "DEBUG: Force Pro",
            subtitle: "Local-only entitlement override for simulator testing.",
            control: debugForceProSwitch
        ))
#endif

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

        stack.addArrangedSubview(makeActionCard(
            title: "HN Account",
            subtitleLabel: hnAccountSubtitleLabel,
            buttonTitle: "Manage Account",
            action: #selector(openHNAccount)
        ))

        stack.addArrangedSubview(makeActionCard(
            title: "Custom Feeds",
            subtitleLabel: customFeedsSubtitleLabel,
            buttonTitle: "Manage Feeds",
            action: #selector(openCustomFeeds)
        ))

        stack.addArrangedSubview(makeActionCard(
            title: "Tracked Threads",
            subtitleLabel: trackedThreadsSubtitleLabel,
            buttonTitle: "View Tracked",
            action: #selector(openTrackedThreads)
        ))

        stack.addArrangedSubview(makeLegalLinksCard())

        stack.addArrangedSubview(makeActionCard(
            title: "Share Import Health",
            subtitleLabel: shareImportSubtitleLabel,
            buttonTitle: "Reset Failures",
            action: #selector(resetShareImportFailures)
        ))

        stack.addArrangedSubview(makeActionCard(
            title: "Performance Dashboard",
            subtitleLabel: performanceSubtitleLabel,
            buttonTitle: "Open Dashboard",
            action: #selector(openPerformanceDashboard)
        ))
    }

    private func makeCard(title: String, body: UIView) -> UIView {
        let highContrast = globalSettings.settings.highContrastMode
        let card = UIView()
        card.backgroundColor = UIColor(named: "CardColor") ?? .secondarySystemBackground
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = highContrast ? 1 : 0
        card.layer.borderColor = UIColor.label.withAlphaComponent(highContrast ? 0.22 : 0.08).cgColor

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
        let highContrast = globalSettings.settings.highContrastMode
        let card = UIView()
        card.backgroundColor = UIColor(named: "CardColor") ?? .secondarySystemBackground
        card.layer.cornerRadius = 14
        card.layer.borderWidth = highContrast ? 1 : 0
        card.layer.borderColor = UIColor.label.withAlphaComponent(highContrast ? 0.22 : 0.08).cgColor

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

    private func makeActionCard(title: String, subtitleLabel: UILabel, buttonTitle: String, action: Selector) -> UIView {
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        let button = UIButton(type: .system)
        button.configuration = .filled()
        button.configuration?.baseBackgroundColor = .systemOrange
        button.configuration?.title = buttonTitle
        button.addTarget(self, action: action, for: .touchUpInside)

        let body = UIStackView(arrangedSubviews: [subtitleLabel, button])
        body.axis = .vertical
        body.spacing = 10
        return makeCard(title: title, body: body)
    }

    private func makeLegalLinksCard() -> UIView {
        legalSubtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        legalSubtitleLabel.textColor = .secondaryLabel
        legalSubtitleLabel.numberOfLines = 0

        let termsButton = UIButton(type: .system)
        termsButton.configuration = .tinted()
        termsButton.configuration?.title = "Terms"
        termsButton.configuration?.baseForegroundColor = .systemOrange
        termsButton.addTarget(self, action: #selector(openTerms), for: .touchUpInside)
        termsButton.isEnabled = LegalLinks.termsURL != nil

        let privacyButton = UIButton(type: .system)
        privacyButton.configuration = .tinted()
        privacyButton.configuration?.title = "Privacy"
        privacyButton.configuration?.baseForegroundColor = .systemOrange
        privacyButton.addTarget(self, action: #selector(openPrivacy), for: .touchUpInside)
        privacyButton.isEnabled = LegalLinks.privacyURL != nil

        let linksRow = UIStackView(arrangedSubviews: [termsButton, privacyButton])
        linksRow.axis = .horizontal
        linksRow.spacing = 10
        linksRow.distribution = .fillEqually

        let body = UIStackView(arrangedSubviews: [legalSubtitleLabel, linksRow])
        body.axis = .vertical
        body.spacing = 10
        return makeCard(title: "Legal", body: body)
    }

    private func makeProSubscriptionCard() -> UIView {
        proSubscriptionSubtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        proSubscriptionSubtitleLabel.textColor = .secondaryLabel
        proSubscriptionSubtitleLabel.numberOfLines = 0

        proPrimaryButton.configuration = .filled()
        proPrimaryButton.configuration?.baseBackgroundColor = .systemOrange
        proPrimaryButton.addTarget(self, action: #selector(openProSubscriptionPrimaryAction), for: .touchUpInside)

        proRestoreButton.configuration = .plain()
        proRestoreButton.configuration?.title = "Restore Purchases"
        proRestoreButton.addTarget(self, action: #selector(restorePurchasesFromSettings), for: .touchUpInside)

        let buttonsRow = UIStackView(arrangedSubviews: [proPrimaryButton, proRestoreButton])
        buttonsRow.axis = .horizontal
        buttonsRow.spacing = 10
        buttonsRow.distribution = .fillEqually

        let body = UIStackView(arrangedSubviews: [proSubscriptionSubtitleLabel, buttonsRow])
        body.axis = .vertical
        body.spacing = 10
        return makeCard(title: "HackerPillar Pro", body: body)
    }

    private func configureState() {
        cardStyleControl.selectedSegmentIndex = Settings.CardStyle.allCases.firstIndex(of: globalSettings.selectedCardStyle) ?? 0
        themeControl.selectedSegmentIndex = Settings.Theme.allCases.firstIndex(of: globalSettings.selectedTheme) ?? 0
        accentColorControl.selectedSegmentIndex = Settings.AccentColor.allCases.firstIndex(of: globalSettings.selectedAccentColor) ?? 0
        fontFamilyControl.selectedSegmentIndex = Settings.FontFamily.allCases.firstIndex(of: globalSettings.selectedFontFamily) ?? 0

        openInReaderSwitch.isOn = globalSettings.settings.openInReader
        openReaderLinksSwitch.isOn = globalSettings.settings.openReaderLinksInReader
        iCloudSyncSwitch.isOn = globalSettings.settings.iCloudSyncEnabled && proFeatureGate.isPro
        highContrastSwitch.isOn = globalSettings.settings.highContrastMode
#if DEBUG || targetEnvironment(simulator)
        debugForceProSwitch.isOn = globalSettings.settings.proEntitlementCachedAt != nil
#endif

        fontScaleSlider.value = Float(globalSettings.settings.readerFontScale)
        lineSpacingSlider.value = Float(globalSettings.settings.readerLineSpacing)
        refreshTypographyLabels()
        refreshHNAccountSubtitle()
        refreshProSubscriptionCard()
        refreshCustomFeedsSubtitle()
        refreshTrackedThreadsSubtitle()
        refreshLegalSubtitle()
        refreshShareImportSubtitle()
        refreshPerformanceSubtitle()
        refreshThemeProControls()
    }

    private func wireActions() {
        cardStyleControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.globalSettings.updateSettings {
                $0.cardStyleString = Settings.CardStyle.allCases[self.cardStyleControl.selectedSegmentIndex].rawValue
            }
        }, for: .valueChanged)

        themeControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.globalSettings.updateSettings {
                $0.themeString = Settings.Theme.allCases[self.themeControl.selectedSegmentIndex].rawValue
            }
        }, for: .valueChanged)

        accentColorControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            guard self.proFeatureGate.isPro else {
                self.accentColorControl.selectedSegmentIndex = Settings.AccentColor.allCases.firstIndex(of: self.globalSettings.selectedAccentColor) ?? 0
                self.proFeatureGate.triggerPaywall(from: self)
                return
            }
            self.globalSettings.updateSettings {
                $0.accentColorRawValue = Settings.AccentColor.allCases[self.accentColorControl.selectedSegmentIndex].rawValue
            }
        }, for: .valueChanged)

        fontFamilyControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            guard self.proFeatureGate.isPro else {
                self.fontFamilyControl.selectedSegmentIndex = Settings.FontFamily.allCases.firstIndex(of: self.globalSettings.selectedFontFamily) ?? 0
                self.proFeatureGate.triggerPaywall(from: self)
                return
            }
            self.globalSettings.updateSettings {
                $0.fontFamilyRawValue = Settings.FontFamily.allCases[self.fontFamilyControl.selectedSegmentIndex].rawValue
            }
        }, for: .valueChanged)

        openInReaderSwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.globalSettings.updateSettings {
                $0.openInReader = self.openInReaderSwitch.isOn
            }
        }, for: .valueChanged)

        openReaderLinksSwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.globalSettings.updateSettings {
                $0.openReaderLinksInReader = self.openReaderLinksSwitch.isOn
            }
        }, for: .valueChanged)

        iCloudSyncSwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            if self.iCloudSyncSwitch.isOn && !self.proFeatureGate.isPro {
                self.iCloudSyncSwitch.setOn(false, animated: true)
                self.proFeatureGate.triggerPaywall(from: self)
                return
            }
            self.globalSettings.updateSettings {
                $0.iCloudSyncEnabled = self.iCloudSyncSwitch.isOn
            }
        }, for: .valueChanged)

        highContrastSwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.globalSettings.updateSettings {
                $0.highContrastMode = self.highContrastSwitch.isOn
            }
        }, for: .valueChanged)

#if DEBUG || targetEnvironment(simulator)
        debugForceProSwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            if self.debugForceProSwitch.isOn {
                self.globalSettings.updateSettings { $0.proEntitlementCachedAt = Date() }
            } else {
                self.globalSettings.updateSettings { $0.proEntitlementCachedAt = nil }
            }
            Task { await self.proFeatureGate.refreshEntitlement() }
        }, for: .valueChanged)
#endif

        fontScaleSlider.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.globalSettings.updateSettings {
                $0.readerFontScale = Double(self.fontScaleSlider.value)
            }
            self.refreshTypographyLabels()
        }, for: .valueChanged)

        lineSpacingSlider.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.globalSettings.updateSettings {
                $0.readerLineSpacing = Double(self.lineSpacingSlider.value)
            }
            self.refreshTypographyLabels()
        }, for: .valueChanged)
    }

    private func bindAccountState() {
        proFeatureGate.$isPro
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshHNAccountSubtitle()
                self?.refreshProSubscriptionCard()
                self?.refreshICloudSyncControl()
                self?.refreshCustomFeedsSubtitle()
                self?.refreshTrackedThreadsSubtitle()
                self?.refreshLegalSubtitle()
                self?.refreshShareImportSubtitle()
                self?.refreshPerformanceSubtitle()
                self?.refreshThemeProControls()
            }
            .store(in: &cancellables)

        hnAccount.$isLoggedIn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshHNAccountSubtitle()
            }
            .store(in: &cancellables)

        hnAccount.$username
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshHNAccountSubtitle()
            }
            .store(in: &cancellables)

        customFeedManager.$feeds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshCustomFeedsSubtitle()
            }
            .store(in: &cancellables)
    }

    private func refreshTypographyLabels() {
        fontScaleValueLabel.text = String(format: "Scale %.2f", globalSettings.settings.readerFontScale)
        lineSpacingValueLabel.text = String(format: "Spacing %.1f", globalSettings.settings.readerLineSpacing)
    }

    private func refreshHNAccountSubtitle() {
        if !proFeatureGate.isPro {
            hnAccountSubtitleLabel.text = "Pro required. Upgrade to unlock login, voting, and replies."
            return
        }
        if hnAccount.isLoggedIn {
            hnAccountSubtitleLabel.text = "Logged in as \(hnAccount.username ?? "Unknown")."
        } else {
            hnAccountSubtitleLabel.text = "Not logged in."
        }
    }

    private func refreshProSubscriptionCard() {
        if proFeatureGate.isPro {
            proPrimaryButton.configuration?.title = "Manage Subscription"
            proSubscriptionSubtitleLabel.text = proSubscriptionStatusMessage ?? "Pro is active on this device."
        } else {
            proPrimaryButton.configuration?.title = "Upgrade to Pro"
            proSubscriptionSubtitleLabel.text = proSubscriptionStatusMessage ?? "Unlock HN account, offline reading, advanced search, custom feeds, and more."
        }
        proRestoreButton.isEnabled = true
    }

    private func refreshICloudSyncControl() {
        if !proFeatureGate.isPro {
            iCloudSyncSwitch.setOn(false, animated: true)
            iCloudSyncSwitch.isEnabled = true
            return
        }
        iCloudSyncSwitch.setOn(globalSettings.settings.iCloudSyncEnabled, animated: false)
    }

    private func refreshCustomFeedsSubtitle() {
        if !proFeatureGate.isPro {
            customFeedsSubtitleLabel.text = "Pro required. Create pinned feed tabs with saved filters."
            return
        }
        let count = CustomFeedManager.shared.feeds.count
        customFeedsSubtitleLabel.text = count == 0 ? "No custom feeds yet." : "\(count) custom feed\(count == 1 ? "" : "s") configured."
    }

    private func refreshTrackedThreadsSubtitle() {
        guard proFeatureGate.isPro else {
            trackedThreadsSubtitleLabel.text = "Pro required. Track threads and get notified on new comments."
            return
        }
        Task { @MainActor in
            let count = await NotificationStore.shared.allTrackedStories().count
            trackedThreadsSubtitleLabel.text = count == 0 ? "No tracked stories." : "\(count) tracked thread\(count == 1 ? "" : "s")."
        }
    }

    private func refreshPerformanceSubtitle() {
        guard proFeatureGate.isPro else {
            performanceSubtitleLabel.text = "Pro required. View local launch and diagnostics samples."
            return
        }
        let samples = PerformanceMonitor.shared.snapshot()
        performanceSubtitleLabel.text = samples.isEmpty ? "No performance samples yet." : "\(samples.count) samples collected on device."
    }

    private func refreshLegalSubtitle() {
        if LegalLinks.isConfigured {
            legalSubtitleLabel.text = "Terms and Privacy links are configured."
        } else {
            legalSubtitleLabel.text = "Set `LegalTermsURL` and `LegalPrivacyURL` in Info.plist before release."
        }
    }

    private func refreshShareImportSubtitle() {
        let snapshot = ShareImportTelemetry.snapshot()
        if snapshot.failureCount == 0 {
            if let successAt = snapshot.lastSuccessAt {
                let time = DateFormatter.localizedString(from: successAt, dateStyle: .short, timeStyle: .short)
                shareImportSubtitleLabel.text = "No failures. Last import at \(time) (\(snapshot.lastImportedCount) items). Pending queue: \(snapshot.pendingCount)."
            } else {
                shareImportSubtitleLabel.text = "No failures recorded. Pending queue: \(snapshot.pendingCount)."
            }
            return
        }

        let lastTime = snapshot.lastFailureAt.map {
            DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short)
        } ?? "unknown time"
        let message = snapshot.lastFailureMessage ?? "Unknown failure"
        shareImportSubtitleLabel.text = "\(snapshot.failureCount) failure\(snapshot.failureCount == 1 ? "" : "s"). Last: \(lastTime) • \(message)"
    }

    private func refreshThemeProControls() {
        let isPro = proFeatureGate.isPro
        accentColorControl.isEnabled = isPro
        fontFamilyControl.isEnabled = isPro
        if !isPro {
            accentColorControl.selectedSegmentIndex = Settings.AccentColor.allCases.firstIndex(of: globalSettings.selectedAccentColor) ?? 0
            fontFamilyControl.selectedSegmentIndex = Settings.FontFamily.allCases.firstIndex(of: globalSettings.selectedFontFamily) ?? 0
        }
    }

    @objc private func openHNAccount() {
        navigationController?.pushViewController(HNAccountViewController(), animated: true)
    }

    @objc private func openProSubscriptionPrimaryAction() {
        proSubscriptionStatusMessage = nil
        if proFeatureGate.isPro {
            guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
            UIApplication.shared.open(url)
            return
        }
        proFeatureGate.triggerPaywall(from: self)
    }

    @objc private func restorePurchasesFromSettings() {
        proRestoreButton.isEnabled = false
        proSubscriptionStatusMessage = "Restoring purchases..."
        refreshProSubscriptionCard()

        Task { [weak self] in
            guard let self else { return }
            defer {
                self.proRestoreButton.isEnabled = true
                self.refreshProSubscriptionCard()
            }
            do {
                let restored = try await self.subscriptionManager.restorePurchases()
                await self.proFeatureGate.refreshEntitlement()
                if restored {
                    self.proSubscriptionStatusMessage = "Purchases restored successfully."
                } else {
                    self.proSubscriptionStatusMessage = "No active Pro subscription found."
                }
            } catch {
                self.proSubscriptionStatusMessage = "Could not restore purchases. Please try again."
            }
        }
    }

    @objc private func openCustomFeeds() {
        guard proFeatureGate.isPro else {
            proFeatureGate.triggerPaywall(from: self)
            return
        }
        navigationController?.pushViewController(CustomFeedManagerViewController(), animated: true)
    }

    @objc private func openTrackedThreads() {
        guard proFeatureGate.isPro else {
            proFeatureGate.triggerPaywall(from: self)
            return
        }
        navigationController?.pushViewController(TrackedThreadsViewController(), animated: true)
    }

    @objc private func openPerformanceDashboard() {
        guard proFeatureGate.isPro else {
            proFeatureGate.triggerPaywall(from: self)
            return
        }
        navigationController?.pushViewController(PerformanceDashboardViewController(), animated: true)
    }

    @objc private func resetShareImportFailures() {
        ShareImportTelemetry.clearFailures()
        refreshShareImportSubtitle()
    }

    @objc private func openTerms() {
        guard let url = LegalLinks.termsURL else { return }
        UIApplication.shared.open(url)
    }

    @objc private func openPrivacy() {
        guard let url = LegalLinks.privacyURL else { return }
        UIApplication.shared.open(url)
    }
}
