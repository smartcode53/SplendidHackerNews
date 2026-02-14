import UIKit

final class StoryCommentsPagerViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    private let initialStory: Story
    private let adjacentProvider: (Int) -> (previous: Story?, next: Story?)
    private let onOpenReader: (Story) -> Void
    private let pageController: UIPageViewController
    private var cachedControllers: [Int: UIViewController] = [:]
    private var controllerStoryIDs: [ObjectIdentifier: Int] = [:]

    init(
        initialStory: Story,
        adjacentProvider: @escaping (Int) -> (previous: Story?, next: Story?),
        onOpenReader: @escaping (Story) -> Void
    ) {
        self.initialStory = initialStory
        self.adjacentProvider = adjacentProvider
        self.onOpenReader = onOpenReader
        self.pageController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: nil
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Comments"
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        addChild(pageController)
        pageController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageController.view)
        NSLayoutConstraint.activate([
            pageController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        pageController.didMove(toParent: self)
        pageController.dataSource = self
        pageController.delegate = self

        let initial = controller(for: initialStory)
        pageController.setViewControllers([initial], direction: .forward, animated: false)
    }

    private func controller(for story: Story) -> UIViewController {
        if let cached = cachedControllers[story.id] {
            return cached
        }
        let commentsVM = CommentsRouteViewModel(story: story)
        let commentsVC = CommentsUIKitViewController(vm: commentsVM, onOpenReader: { [weak self] selectedStory in
            self?.onOpenReader(selectedStory)
        })
        commentsVC.title = "Comments"
        controllerStoryIDs[ObjectIdentifier(commentsVC)] = story.id
        cachedControllers[story.id] = commentsVC
        return commentsVC
    }

    private func storyID(from viewController: UIViewController) -> Int? {
        controllerStoryIDs[ObjectIdentifier(viewController)]
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let currentStoryID = storyID(from: viewController) else { return nil }
        let adjacent = adjacentProvider(currentStoryID)
        guard let previous = adjacent.previous else { return nil }
        return controller(for: previous)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let currentStoryID = storyID(from: viewController) else { return nil }
        let adjacent = adjacentProvider(currentStoryID)
        guard let next = adjacent.next else { return nil }
        return controller(for: next)
    }
}
