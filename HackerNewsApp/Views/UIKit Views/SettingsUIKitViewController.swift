import UIKit
import Combine

@MainActor
final class SettingsUIKitViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private enum Section: Int, CaseIterable {
        case appearance
        case reading
        case subscription
        case features
        case legal
        case diagnostics
#if DEBUG
        case debug
#endif

        var title: String {
            switch self {
            case .appearance: return "Appearance"
            case .reading: return "Reading"
            case .subscription: return "HackerPillar Pro"
            case .features: return "Features"
            case .legal: return "Legal"
            case .diagnostics: return "Diagnostics"
#if DEBUG
            case .debug: return "Debug"
#endif
            }
        }
    }

    private enum Row {
        case theme
        case accentColor
        case fontFamily
        case highContrast
        case openInReader
        case openReaderLinks
        case fontScale
        case lineSpacing
        case iCloudSync
        case proPrimary
        case proRestore
        case hnAccount
        case customFeeds
        case trackedThreads
        case performance
        case terms
        case privacy
        case shareImportReset
#if DEBUG
        case debugForcePro
#endif
    }

    private let globalSettings: GlobalSettingsViewModel
    private let hnAccount = HNAccount.shared
    private let proFeatureGate = ProFeatureGate.shared
    private let subscriptionManager = SubscriptionManager.shared
    private let customFeedManager = CustomFeedManager.shared
    private var cancellables: Set<AnyCancellable> = []

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private let openInReaderSwitch = UISwitch()
    private let openReaderLinksSwitch = UISwitch()
    private let iCloudSyncSwitch = UISwitch()
    private let highContrastSwitch = UISwitch()
#if DEBUG
    private let debugForceProSwitch = UISwitch()
#endif

    private var proSubscriptionStatusMessage: String?
    private var shareImportStatusMessage: String {
        let snapshot = ShareImportTelemetry.snapshot()
        if snapshot.failureCount == 0 {
            if let successAt = snapshot.lastSuccessAt {
                let time = DateFormatter.localizedString(from: successAt, dateStyle: .short, timeStyle: .short)
                return "No failures. Last import: \(time) (\(snapshot.lastImportedCount) items). Pending: \(snapshot.pendingCount)."
            }
            return "No failures recorded. Pending queue: \(snapshot.pendingCount)."
        }

        let lastTime = snapshot.lastFailureAt.map {
            DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short)
        } ?? "unknown time"
        let message = snapshot.lastFailureMessage ?? "Unknown failure"
        return "\(snapshot.failureCount) failure\(snapshot.failureCount == 1 ? "" : "s"). Last: \(lastTime) • \(message)"
    }

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
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .systemGroupedBackground
        configureTableView()
        configureState()
        wireActions()
        bindState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        globalSettings.saveSettings()
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func rows(for section: Section) -> [Row] {
        switch section {
        case .appearance:
            return [.theme, .accentColor, .fontFamily, .highContrast]
        case .reading:
            return [.openInReader, .openReaderLinks, .fontScale, .lineSpacing]
        case .subscription:
            return [.proPrimary, .proRestore, .iCloudSync]
        case .features:
            return [.hnAccount, .customFeeds, .trackedThreads, .performance]
        case .legal:
            return [.terms, .privacy]
        case .diagnostics:
            return [.shareImportReset]
#if DEBUG
        case .debug:
            return [.debugForcePro]
#endif
        }
    }

    private func configureState() {
        [openInReaderSwitch, openReaderLinksSwitch, iCloudSyncSwitch, highContrastSwitch].forEach {
            $0.onTintColor = .systemGreen
        }
        openInReaderSwitch.isOn = globalSettings.settings.openInReader
        openReaderLinksSwitch.isOn = globalSettings.settings.openReaderLinksInReader
        iCloudSyncSwitch.isOn = globalSettings.settings.iCloudSyncEnabled && proFeatureGate.isPro
        highContrastSwitch.isOn = globalSettings.settings.highContrastMode
#if DEBUG
        debugForceProSwitch.isOn = globalSettings.settings.proEntitlementCachedAt != nil
        debugForceProSwitch.onTintColor = .systemGreen
#endif
    }

    private func wireActions() {
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

#if DEBUG
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
    }

    private func bindState() {
        proFeatureGate.$isPro
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        hnAccount.$isLoggedIn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadRow(.hnAccount)
            }
            .store(in: &cancellables)

        hnAccount.$username
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadRow(.hnAccount)
            }
            .store(in: &cancellables)

        customFeedManager.$feeds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadRow(.customFeeds)
            }
            .store(in: &cancellables)
    }

    private func reloadRow(_ row: Row) {
        for section in Section.allCases {
            let rows = rows(for: section)
            if let rowIndex = rows.firstIndex(where: { $0 == row }) {
                tableView.reloadRows(at: [IndexPath(row: rowIndex, section: section.rawValue)], with: .none)
                return
            }
        }
    }

    private func subtitleForProPrimary() -> String {
        if let status = proSubscriptionStatusMessage {
            return status
        }
        return proFeatureGate.isPro
            ? "Pro is active on this device."
            : "Unlock HN account, offline reading, advanced search, custom feeds, and more."
    }

    private func subtitleForHNAccount() -> String {
        if !proFeatureGate.isPro {
            return "Pro required. Upgrade to unlock login, voting, and replies."
        }
        if hnAccount.isLoggedIn {
            return "Logged in as \(hnAccount.username ?? "Unknown")."
        }
        return "Not logged in."
    }

    private func subtitleForCustomFeeds() -> String {
        if !proFeatureGate.isPro {
            return "Pro required. Create pinned feed tabs with saved filters."
        }
        let count = customFeedManager.feeds.count
        return count == 0 ? "No custom feeds yet." : "\(count) custom feed\(count == 1 ? "" : "s") configured."
    }

    private func subtitleForTrackedThreads() -> String {
        if !proFeatureGate.isPro {
            return "Pro required. Track threads and get notified on new comments."
        }
        return "View and manage tracked threads."
    }

    private func subtitleForPerformance() -> String {
        if !proFeatureGate.isPro {
            return "Pro required. View local launch and diagnostics samples."
        }
        let samples = PerformanceMonitor.shared.snapshot()
        return samples.isEmpty ? "No performance samples yet." : "\(samples.count) samples collected on device."
    }

    private func valueText(for row: Row) -> String {
        switch row {
        case .theme:
            return globalSettings.selectedTheme.rawValue
        case .accentColor:
            return proFeatureGate.isPro ? globalSettings.selectedAccentColor.rawValue : "Pro"
        case .fontFamily:
            return proFeatureGate.isPro ? globalSettings.selectedFontFamily.rawValue : "Pro"
        case .fontScale:
            return String(format: "%.2fx", globalSettings.settings.readerFontScale)
        case .lineSpacing:
            return String(format: "%.1f", globalSettings.settings.readerLineSpacing)
        default:
            return ""
        }
    }

    private func makeSubtitleCell(reuseID: String, title: String, subtitle: String, accessoryType: UITableViewCell.AccessoryType = .none, tintColor: UIColor? = nil) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseID) ?? UITableViewCell(style: .subtitle, reuseIdentifier: reuseID)
        var content = cell.defaultContentConfiguration()
        content.text = title
        content.secondaryText = subtitle
        content.secondaryTextProperties.numberOfLines = 0
        cell.contentConfiguration = content
        cell.accessoryType = accessoryType
        cell.textLabel?.textColor = tintColor
        if let tintColor {
            content.textProperties.color = tintColor
            cell.contentConfiguration = content
        }
        return cell
    }

    private func makeControlCell(reuseID: String, title: String, subtitle: String? = nil, control: UIView) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseID) ?? UITableViewCell(style: .default, reuseIdentifier: reuseID)
        var content = cell.defaultContentConfiguration()
        content.text = title
        content.secondaryText = subtitle
        content.secondaryTextProperties.numberOfLines = 0
        cell.contentConfiguration = content

        if control.superview != nil {
            control.removeFromSuperview()
        }
        cell.accessoryView = control
        cell.selectionStyle = .none
        return cell
    }

    private func makeValueCell(
        reuseID: String,
        title: String,
        value: String,
        accessoryType: UITableViewCell.AccessoryType = .disclosureIndicator,
        enabled: Bool = true
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseID) ?? UITableViewCell(style: .value1, reuseIdentifier: reuseID)
        var content = cell.defaultContentConfiguration()
        content.text = title
        content.secondaryText = value
        cell.contentConfiguration = content
        cell.accessoryType = accessoryType
        cell.selectionStyle = enabled ? .default : .none
        cell.isUserInteractionEnabled = enabled
        cell.textLabel?.isEnabled = enabled
        cell.detailTextLabel?.isEnabled = enabled
        return cell
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        return rows(for: section).count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }

        switch section {
        case .subscription:
            return subtitleForProPrimary()
        case .reading:
            return "Reader typography controls are applied in Reader Mode."
        case .legal:
            return LegalLinks.isConfigured
                ? "Terms and Privacy links are configured."
                : "Terms and Privacy links are currently unavailable."
        case .diagnostics:
            return shareImportStatusMessage
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        let row = rows(for: section)[indexPath.row]

        switch row {
        case .theme:
            return makeValueCell(reuseID: "theme", title: "Theme", value: valueText(for: .theme))
        case .accentColor:
            return makeValueCell(reuseID: "accentColor", title: "Accent Color", value: valueText(for: .accentColor))
        case .fontFamily:
            return makeValueCell(reuseID: "fontFamily", title: "Font Family", value: valueText(for: .fontFamily))
        case .highContrast:
            return makeControlCell(reuseID: "highContrast", title: "High Contrast", control: highContrastSwitch)
        case .openInReader:
            return makeControlCell(reuseID: "openInReader", title: "Open Stories in Reader", control: openInReaderSwitch)
        case .openReaderLinks:
            return makeControlCell(reuseID: "openReaderLinks", title: "Open Reader Links in Reader", control: openReaderLinksSwitch)
        case .fontScale:
            return makeValueCell(reuseID: "fontScale", title: "Reader Font Scale", value: valueText(for: .fontScale))
        case .lineSpacing:
            return makeValueCell(reuseID: "lineSpacing", title: "Reader Line Spacing", value: valueText(for: .lineSpacing))
        case .iCloudSync:
            return makeControlCell(reuseID: "icloud", title: "iCloud Sync", control: iCloudSyncSwitch)
        case .proPrimary:
            let title = proFeatureGate.isPro ? "Manage Subscription" : "Upgrade to Pro"
            let subtitle = proFeatureGate.isPro ? "Open Apple subscription management." : "Open the Pro paywall."
            let cell = makeSubtitleCell(reuseID: "proPrimary", title: title, subtitle: subtitle, accessoryType: .disclosureIndicator, tintColor: .systemOrange)
            return cell
        case .proRestore:
            return makeSubtitleCell(reuseID: "proRestore", title: "Restore Purchases", subtitle: "Restore an existing subscription on this Apple ID.", accessoryType: .none, tintColor: .systemOrange)
        case .hnAccount:
            return makeSubtitleCell(reuseID: "hnAccount", title: "HN Account", subtitle: subtitleForHNAccount(), accessoryType: .disclosureIndicator)
        case .customFeeds:
            return makeSubtitleCell(reuseID: "customFeeds", title: "Custom Feeds", subtitle: subtitleForCustomFeeds(), accessoryType: .disclosureIndicator)
        case .trackedThreads:
            return makeSubtitleCell(reuseID: "trackedThreads", title: "Tracked Threads", subtitle: subtitleForTrackedThreads(), accessoryType: .disclosureIndicator)
        case .performance:
            return makeSubtitleCell(reuseID: "performance", title: "Performance Dashboard", subtitle: subtitleForPerformance(), accessoryType: .disclosureIndicator)
        case .terms:
            let enabled = LegalLinks.termsURL != nil
            let cell = makeSubtitleCell(reuseID: "terms", title: "Terms", subtitle: enabled ? "View terms of use." : "Unavailable", accessoryType: enabled ? .disclosureIndicator : .none, tintColor: enabled ? .systemOrange : .secondaryLabel)
            cell.selectionStyle = enabled ? .default : .none
            return cell
        case .privacy:
            let enabled = LegalLinks.privacyURL != nil
            let cell = makeSubtitleCell(reuseID: "privacy", title: "Privacy", subtitle: enabled ? "View privacy policy." : "Unavailable", accessoryType: enabled ? .disclosureIndicator : .none, tintColor: enabled ? .systemOrange : .secondaryLabel)
            cell.selectionStyle = enabled ? .default : .none
            return cell
        case .shareImportReset:
            return makeSubtitleCell(reuseID: "shareImport", title: "Reset Share Import Failures", subtitle: "Clear share import failure telemetry.", accessoryType: .none, tintColor: .systemOrange)
#if DEBUG
        case .debugForcePro:
            return makeControlCell(reuseID: "debugPro", title: "Force Pro", subtitle: "Local-only entitlement override for simulator testing.", control: debugForceProSwitch)
#endif
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard let section = Section(rawValue: indexPath.section) else { return }
        let row = rows(for: section)[indexPath.row]

        switch row {
        case .theme:
            presentThemeOptions()
        case .accentColor:
            presentAccentColorOptions()
        case .fontFamily:
            presentFontFamilyOptions()
        case .fontScale:
            presentFontScaleOptions()
        case .lineSpacing:
            presentLineSpacingOptions()
        case .proPrimary:
            openProSubscriptionPrimaryAction()
        case .proRestore:
            restorePurchasesFromSettings()
        case .hnAccount:
            navigationController?.pushViewController(HNAccountViewController(), animated: true)
        case .customFeeds:
            guard proFeatureGate.isPro else {
                proFeatureGate.triggerPaywall(from: self)
                return
            }
            navigationController?.pushViewController(CustomFeedManagerViewController(), animated: true)
        case .trackedThreads:
            guard proFeatureGate.isPro else {
                proFeatureGate.triggerPaywall(from: self)
                return
            }
            navigationController?.pushViewController(TrackedThreadsViewController(), animated: true)
        case .performance:
            guard proFeatureGate.isPro else {
                proFeatureGate.triggerPaywall(from: self)
                return
            }
            navigationController?.pushViewController(PerformanceDashboardViewController(), animated: true)
        case .terms:
            guard let url = LegalLinks.termsURL else { return }
            UIApplication.shared.open(url)
        case .privacy:
            guard let url = LegalLinks.privacyURL else { return }
            UIApplication.shared.open(url)
        case .shareImportReset:
            ShareImportTelemetry.clearFailures()
            tableView.reloadSections(IndexSet(integer: Section.diagnostics.rawValue), with: .none)
        default:
            break
        }
    }

    private func presentOptionSheet(
        title: String,
        options: [String],
        selectedIndex: Int,
        onSelect: @escaping (Int) -> Void
    ) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for (index, option) in options.enumerated() {
            let displayTitle = index == selectedIndex ? "\(option) ✓" : option
            alert.addAction(UIAlertAction(title: displayTitle, style: .default) { _ in
                onSelect(index)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(alert, animated: true)
    }

    private func presentThemeOptions() {
        let all = Settings.Theme.allCases
        let selectedIndex = all.firstIndex(of: globalSettings.selectedTheme) ?? 0
        presentOptionSheet(
            title: "Theme",
            options: all.map(\.rawValue),
            selectedIndex: selectedIndex
        ) { [weak self] index in
            guard let self else { return }
            self.globalSettings.updateSettings {
                $0.themeString = all[index].rawValue
            }
            self.reloadRow(.theme)
        }
    }

    private func presentAccentColorOptions() {
        guard proFeatureGate.isPro else {
            proFeatureGate.triggerPaywall(from: self)
            return
        }
        let all = Settings.AccentColor.allCases
        let selectedIndex = all.firstIndex(of: globalSettings.selectedAccentColor) ?? 0
        presentOptionSheet(
            title: "Accent Color",
            options: all.map(\.rawValue),
            selectedIndex: selectedIndex
        ) { [weak self] index in
            guard let self else { return }
            self.globalSettings.updateSettings {
                $0.accentColorRawValue = all[index].rawValue
            }
            self.reloadRow(.accentColor)
        }
    }

    private func presentFontFamilyOptions() {
        guard proFeatureGate.isPro else {
            proFeatureGate.triggerPaywall(from: self)
            return
        }
        let all = Settings.FontFamily.allCases
        let selectedIndex = all.firstIndex(of: globalSettings.selectedFontFamily) ?? 0
        presentOptionSheet(
            title: "Font Family",
            options: all.map(\.rawValue),
            selectedIndex: selectedIndex
        ) { [weak self] index in
            guard let self else { return }
            self.globalSettings.updateSettings {
                $0.fontFamilyRawValue = all[index].rawValue
            }
            self.reloadRow(.fontFamily)
        }
    }

    private func presentFontScaleOptions() {
        let values = stride(from: 0.9, through: 1.4, by: 0.1).map { Double(round($0 * 100) / 100) }
        let options = values.map { String(format: "%.2fx", $0) }
        let selectedIndex = values.firstIndex(where: { abs($0 - globalSettings.settings.readerFontScale) < 0.001 }) ?? 1
        presentOptionSheet(
            title: "Reader Font Scale",
            options: options,
            selectedIndex: selectedIndex
        ) { [weak self] index in
            guard let self else { return }
            self.globalSettings.updateSettings {
                $0.readerFontScale = values[index]
            }
            self.reloadRow(.fontScale)
        }
    }

    private func presentLineSpacingOptions() {
        let values = stride(from: 0.0, through: 6.0, by: 0.5).map { Double(round($0 * 10) / 10) }
        let options = values.map { String(format: "%.1f", $0) }
        let selectedIndex = values.firstIndex(where: { abs($0 - globalSettings.settings.readerLineSpacing) < 0.001 }) ?? 4
        presentOptionSheet(
            title: "Reader Line Spacing",
            options: options,
            selectedIndex: selectedIndex
        ) { [weak self] index in
            guard let self else { return }
            self.globalSettings.updateSettings {
                $0.readerLineSpacing = values[index]
            }
            self.reloadRow(.lineSpacing)
        }
    }

    private func openProSubscriptionPrimaryAction() {
        proSubscriptionStatusMessage = nil
        if proFeatureGate.isPro {
            guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
            UIApplication.shared.open(url)
            return
        }
        proFeatureGate.triggerPaywall(from: self)
    }

    private func restorePurchasesFromSettings() {
        proSubscriptionStatusMessage = "Restoring purchases..."
        tableView.reloadSections(IndexSet(integer: Section.subscription.rawValue), with: .none)

        Task { [weak self] in
            guard let self else { return }
            do {
                let restored = try await self.subscriptionManager.restorePurchases()
                await self.proFeatureGate.refreshEntitlement()
                self.proSubscriptionStatusMessage = restored ? "Purchases restored successfully." : "No active Pro subscription found."
            } catch {
                self.proSubscriptionStatusMessage = "Could not restore purchases. Please try again."
            }
            self.tableView.reloadSections(IndexSet(integer: Section.subscription.rawValue), with: .none)
        }
    }
}
