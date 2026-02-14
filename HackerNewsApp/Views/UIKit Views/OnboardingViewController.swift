import UIKit

private struct OnboardingPageModel {
    let title: String
    let subtitle: String
    let icon: String
}

@MainActor
final class OnboardingViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    private let pages: [OnboardingPageModel] = [
        OnboardingPageModel(title: "Welcome to HackerPillar", subtitle: "A fast and beautiful Hacker News reader.", icon: "sparkles"),
        OnboardingPageModel(title: "Browse Faster", subtitle: "Smooth feeds, comments, reader mode, and smart filtering.", icon: "newspaper"),
        OnboardingPageModel(title: "Save and Track", subtitle: "Bookmarks, offline stories, and tracked threads in one place.", icon: "bookmark.circle"),
        OnboardingPageModel(title: "Try Pro", subtitle: "Unlock HN account, advanced search, custom feeds, and more.", icon: "star.circle")
    ]

    private let onComplete: () -> Void
    private let pageController: UIPageViewController
    private let pageIndicator = UIPageControl()
    private let continueButton = UIButton(type: .system)
    private let trialButton = UIButton(type: .system)
    private var currentIndex = 0

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        self.pageController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground

        addChild(pageController)
        pageController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageController.view)
        pageController.didMove(toParent: self)
        pageController.dataSource = self
        pageController.delegate = self

        pageIndicator.translatesAutoresizingMaskIntoConstraints = false
        pageIndicator.numberOfPages = pages.count
        pageIndicator.currentPage = currentIndex
        pageIndicator.currentPageIndicatorTintColor = ThemeManager.shared.accentColor(from: Settings(cardStyleString: Settings.CardStyle.normal.rawValue, themeString: Settings.Theme.automatic.rawValue))

        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.configuration = .filled()
        continueButton.configuration?.baseBackgroundColor = ThemeManager.shared.accentColor(from: Settings(cardStyleString: Settings.CardStyle.normal.rawValue, themeString: Settings.Theme.automatic.rawValue))
        continueButton.configuration?.title = "Next"
        continueButton.addAction(UIAction { [weak self] _ in
            self?.advance()
        }, for: .touchUpInside)

        trialButton.translatesAutoresizingMaskIntoConstraints = false
        trialButton.configuration = .plain()
        trialButton.configuration?.title = "Try Pro"
        trialButton.isHidden = true
        trialButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            ProFeatureGate.shared.triggerPaywall(from: self)
        }, for: .touchUpInside)

        view.addSubview(pageIndicator)
        view.addSubview(continueButton)
        view.addSubview(trialButton)

        NSLayoutConstraint.activate([
            pageController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pageController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageController.view.bottomAnchor.constraint(equalTo: pageIndicator.topAnchor, constant: -20),

            pageIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageIndicator.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -14),

            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            continueButton.heightAnchor.constraint(equalToConstant: 50),

            trialButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            trialButton.bottomAnchor.constraint(equalTo: pageIndicator.topAnchor, constant: -10),
        ])

        if let first = pageControllerForIndex(0) {
            pageController.setViewControllers([first], direction: .forward, animated: false)
        }
        refreshControls()
    }

    private func pageControllerForIndex(_ index: Int) -> UIViewController? {
        guard pages.indices.contains(index) else { return nil }
        let page = pages[index]
        return OnboardingPageContentViewController(page: page, index: index)
    }

    private func refreshControls() {
        pageIndicator.currentPage = currentIndex
        let isLast = currentIndex == pages.count - 1
        continueButton.configuration?.title = isLast ? "Get Started" : "Next"
        trialButton.isHidden = !isLast
    }

    private func advance() {
        if currentIndex >= pages.count - 1 {
            onComplete()
            return
        }
        let nextIndex = currentIndex + 1
        guard let next = pageControllerForIndex(nextIndex) else { return }
        pageController.setViewControllers([next], direction: .forward, animated: true)
        currentIndex = nextIndex
        refreshControls()
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let vc = viewController as? OnboardingPageContentViewController else { return nil }
        return pageControllerForIndex(vc.index - 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let vc = viewController as? OnboardingPageContentViewController else { return nil }
        return pageControllerForIndex(vc.index + 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed,
              let visible = pageViewController.viewControllers?.first as? OnboardingPageContentViewController else { return }
        currentIndex = visible.index
        refreshControls()
    }
}

@MainActor
private final class OnboardingPageContentViewController: UIViewController {
    let index: Int
    private let page: OnboardingPageModel

    init(page: OnboardingPageModel, index: Int) {
        self.page = page
        self.index = index
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let icon = UIImageView(image: UIImage(systemName: page.icon))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = ThemeManager.shared.accentColor(from: Settings(cardStyleString: Settings.CardStyle.normal.rawValue, themeString: Settings.Theme.automatic.rawValue))
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 72, weight: .light)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = page.title
        titleLabel.font = UIFont.boldSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .largeTitle).pointSize)
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = page.subtitle
        subtitleLabel.font = .preferredFont(forTextStyle: .body)
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, subtitleLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 18
        stack.alignment = .center

        icon.widthAnchor.constraint(equalToConstant: 96).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 96).isActive = true
        subtitleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 520).isActive = true

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }
}
