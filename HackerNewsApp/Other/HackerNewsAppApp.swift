import UIKit
import Combine
import SafariServices
import CoreSpotlight

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private let globalSettings = GlobalSettingsViewModel()
    private let proFeatureGate = ProFeatureGate.shared
    private let subscriptionManager = SubscriptionManager.shared
    private let performanceMonitor = PerformanceMonitor.shared
    private var cancellables: Set<AnyCancellable> = []
    private var launchTask: Task<Void, Never>?
    private let onboardingKey = "onboarding.completed"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        performanceMonitor.markLaunchStart()
        guard let windowScene = application.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            assertionFailure("Expected an active UIWindowScene at launch.")
            return false
        }
        let window = UIWindow(windowScene: windowScene)
        let mainRoot = makeMainRootController()
        if UserDefaults.standard.bool(forKey: onboardingKey) {
            window.rootViewController = mainRoot
        } else {
            let onboarding = OnboardingViewController { [weak self, weak window] in
                guard let self, let window else { return }
                UserDefaults.standard.set(true, forKey: self.onboardingKey)
                UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
                    window.rootViewController = self.makeMainRootController()
                }
            }
            window.rootViewController = onboarding
        }
        self.window = window
        Task {
            await subscriptionManager.startTransactionListener { [weak self] in
                guard let self else { return }
                await self.proFeatureGate.refreshEntitlement()
            }
        }
        proFeatureGate.configure(
            cachedDateProvider: { [weak self] in
                self?.globalSettings.proEntitlementCachedAt
            },
            cacheDateUpdater: { [weak self] date in
                self?.globalSettings.updateProEntitlementCacheDate(date)
            }
        )
        launchTask = Task { [weak self] in
            guard let self else { return }
            await self.proFeatureGate.refreshEntitlement()
        }
        Task {
            await NotificationManager.shared.requestAuthorizationIfNeeded()
            await CommentMonitor.shared.start()
        }
        Task {
            await SpotlightIndexer.shared.bootstrapFromDiskIfNeeded()
        }
        Task {
            await WidgetDataProvider.shared.refreshFromDisk()
            await ShareExtensionBridge.shared.importPendingURLs()
        }
        Task { @MainActor in
            ShortcutsProvider.shared.donateShowTopStories()
            ShortcutsProvider.shared.donateOpenBookmarks()
        }
        applyTheme()
        observeSettings()
        window.makeKeyAndVisible()
        performanceMonitor.markLaunchDisplayed()
        return true
    }

    private func makeMainRootController() -> UIViewController {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return HNIPadSplitViewController(globalSettings: globalSettings)
        }
        return HNTabBarController(globalSettings: globalSettings)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        globalSettings.saveSettings()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { [weak self] in
            guard let self else { return }
            await self.proFeatureGate.refreshEntitlement()
        }
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        if userActivity.activityType == ShortcutActivityType.showTopStories {
            routeToFeed()
            return true
        }

        if userActivity.activityType == ShortcutActivityType.openBookmarks {
            routeToBookmarks()
            return true
        }

        if userActivity.activityType == ShortcutActivityType.searchHN {
            let query = (userActivity.userInfo?[ShortcutActivityType.searchQueryKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            routeToSearch(query: query)
            return true
        }

        if userActivity.activityType == CSSearchableItemActionType,
           let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let url = await SpotlightIndexer.shared.resolveURL(for: identifier) {
                    self.openSpotlightURL(url)
                }
            }
            return true
        }

        if let url = userActivity.webpageURL {
            openSpotlightURL(url)
            return true
        }

        return false
    }

    private func observeSettings() {
        globalSettings.$settings
            .receive(on: DispatchQueue.main)
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
        HighContrastTheme.shared.setEnabled(globalSettings.settings.highContrastMode)
        ThemeManager.shared.apply(settings: globalSettings.settings, window: window)
    }

    @MainActor
    private func openSpotlightURL(_ url: URL) {
        guard let root = window?.rootViewController else { return }
        let safeURL = NetworkManager.instance.safelyLoadUrl(url: url.absoluteString)
        let safari = SFSafariViewController(url: safeURL)

        if let nav = root as? UINavigationController {
            nav.present(safari, animated: true)
            return
        }
        if let tab = root as? UITabBarController,
           let selected = tab.selectedViewController {
            selected.present(safari, animated: true)
            return
        }
        if let split = root as? UISplitViewController,
           let detail = split.viewController(for: .secondary) {
            detail.present(safari, animated: true)
            return
        }
        root.present(safari, animated: true)
    }

    @MainActor
    private func routeToFeed() {
        guard let root = window?.rootViewController else { return }
        if let tab = root as? HNTabBarController {
            tab.selectedIndex = 0
            return
        }
        if let split = root as? HNIPadSplitViewController {
            split.showSection(.feed)
        }
    }

    @MainActor
    private func routeToBookmarks() {
        guard let root = window?.rootViewController else { return }
        if let tab = root as? HNTabBarController {
            tab.selectedIndex = 1
            return
        }
        if let split = root as? HNIPadSplitViewController {
            split.showSection(.saved)
        }
    }

    @MainActor
    private func routeToSearch(query: String?) {
        guard let root = window?.rootViewController else { return }
        let searchVC = SearchViewController(initialQuery: query)
        let nav = UINavigationController(rootViewController: searchVC)

        if let tab = root as? HNTabBarController {
            tab.selectedIndex = 0
            (tab.selectedViewController ?? tab).present(nav, animated: true)
            return
        }
        if let split = root as? HNIPadSplitViewController {
            split.showSection(.feed)
            split.present(nav, animated: true)
            return
        }
        root.present(nav, animated: true)
    }
}
