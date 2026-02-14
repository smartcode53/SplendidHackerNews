import UIKit
import Combine

@MainActor
final class HNTabBarController: UITabBarController {
    private let globalSettings: GlobalSettingsViewModel
    private let proFeatureGate = ProFeatureGate.shared
    private let customFeedManager = CustomFeedManager.shared
    private var cancellables: Set<AnyCancellable> = []

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
        bindProState()
    }

    private func configureTabs() {
        let previousSelectedIdentifier = selectedViewController?.tabBarItem.accessibilityIdentifier

        let feedVC = FeedViewController(globalSettings: globalSettings)
        let savedVC = SavedStoriesViewController(globalSettings: globalSettings)
        let settingsVC = SettingsUIKitViewController(globalSettings: globalSettings)
        let offlineVC = OfflineViewController()

        let feedNav = UINavigationController(rootViewController: feedVC)
        feedNav.tabBarItem = UITabBarItem(title: "Feed", image: UIImage(systemName: "newspaper"), tag: 0)
        feedNav.tabBarItem.accessibilityIdentifier = "tab.feed"

        let savedNav = UINavigationController(rootViewController: savedVC)
        savedNav.tabBarItem = UITabBarItem(title: "Saved Stories", image: UIImage(systemName: "bookmark"), tag: 1)
        savedNav.tabBarItem.accessibilityIdentifier = "tab.saved"

        let settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gear"), tag: 2)
        settingsNav.tabBarItem.accessibilityIdentifier = "tab.settings"

        let offlineNav = UINavigationController(rootViewController: offlineVC)
        offlineNav.tabBarItem = UITabBarItem(title: "Offline", image: UIImage(systemName: "arrow.down.circle"), tag: 3)
        offlineNav.tabBarItem.accessibilityIdentifier = "tab.offline"

        [feedNav, savedNav, settingsNav, offlineNav].forEach {
            $0.navigationBar.prefersLargeTitles = true
        }

        if proFeatureGate.isPro {
            var controllers: [UIViewController] = [feedNav, savedNav, settingsNav, offlineNav]
            for customFeed in customFeedManager.feeds {
                let customFeedVC = FeedViewController(
                    globalSettings: globalSettings,
                    initialStoryType: customFeed.storyType,
                    initialFilter: customFeed.filter,
                    customFeedTitle: customFeed.name
                )
                let customNav = UINavigationController(rootViewController: customFeedVC)
                customNav.navigationBar.prefersLargeTitles = true
                customNav.tabBarItem = UITabBarItem(title: customFeed.name, image: UIImage(systemName: "line.3.horizontal.decrease.circle"), tag: controllers.count)
                customNav.tabBarItem.accessibilityIdentifier = "tab.custom.\(customFeed.id.uuidString)"
                controllers.append(customNav)
            }
            viewControllers = controllers
        } else {
            viewControllers = [feedNav, savedNav, settingsNav]
        }

        if let previousSelectedIdentifier,
           let viewControllers,
           let restoredIndex = viewControllers.firstIndex(where: { $0.tabBarItem.accessibilityIdentifier == previousSelectedIdentifier }) {
            selectedIndex = restoredIndex
        }

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = ThemeManager.shared.accentColor(from: globalSettings.settings)
    }

    private func bindProState() {
        proFeatureGate.$isPro
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.configureTabs()
            }
            .store(in: &cancellables)

        customFeedManager.$feeds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.proFeatureGate.isPro else { return }
                self.configureTabs()
            }
            .store(in: &cancellables)

        globalSettings.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                guard let self else { return }
                self.tabBar.tintColor = ThemeManager.shared.accentColor(from: settings)
            }
            .store(in: &cancellables)
    }
}
