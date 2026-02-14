import UIKit
import Combine

@MainActor
final class HNIPadSplitViewController: UISplitViewController {
    private let globalSettings: GlobalSettingsViewModel
    private let proFeatureGate = ProFeatureGate.shared
    private var cancellables: Set<AnyCancellable> = []

    private let sidebar = HNIPadSidebarViewController()
    private let detailNav = UINavigationController(rootViewController: UIViewController())
    private var currentSelection: HNIPadSidebarViewController.Section = .feed

    init(globalSettings: GlobalSettingsViewModel) {
        self.globalSettings = globalSettings
        super.init(style: .doubleColumn)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredDisplayMode = .oneBesideSecondary
        preferredSplitBehavior = .tile
        primaryBackgroundStyle = .sidebar

        sidebar.onSelectSection = { [weak self] section in
            self?.showDetail(for: section)
        }

        let sidebarNav = UINavigationController(rootViewController: sidebar)
        setViewController(sidebarNav, for: .primary)
        setViewController(detailNav, for: .secondary)

        applySections()
        showDetail(for: .feed)
        bindState()
    }

    private func bindState() {
        proFeatureGate.$isPro
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applySections()
            }
            .store(in: &cancellables)
    }

    private func applySections() {
        let sections: [HNIPadSidebarViewController.Section]
        if proFeatureGate.isPro {
            sections = [.feed, .offline, .saved, .settings]
        } else {
            sections = [.feed, .saved, .settings]
        }
        sidebar.updateSections(sections)
        if !sections.contains(currentSelection) {
            currentSelection = .feed
            showDetail(for: .feed)
        }
    }

    private func showDetail(for section: HNIPadSidebarViewController.Section) {
        currentSelection = section
        let controller: UIViewController
        switch section {
        case .feed:
            controller = FeedViewController(globalSettings: globalSettings)
        case .saved:
            controller = SavedStoriesViewController(globalSettings: globalSettings)
        case .settings:
            controller = SettingsUIKitViewController(globalSettings: globalSettings)
        case .offline:
            controller = OfflineViewController()
        }
        controller.navigationItem.largeTitleDisplayMode = .automatic
        let nav = UINavigationController(rootViewController: controller)
        nav.navigationBar.prefersLargeTitles = true
        setViewController(nav, for: .secondary)
    }

    func showSection(_ section: HNIPadSidebarViewController.Section) {
        guard sidebar.availableSections.contains(section) else { return }
        sidebar.select(section)
        showDetail(for: section)
    }
}

@MainActor
final class HNIPadSidebarViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    enum Section: CaseIterable, Equatable {
        case feed
        case offline
        case saved
        case settings

        var title: String {
            switch self {
            case .feed:
                return "Feed"
            case .offline:
                return "Offline"
            case .saved:
                return "Saved Stories"
            case .settings:
                return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .feed:
                return "newspaper"
            case .offline:
                return "arrow.down.circle"
            case .saved:
                return "bookmark"
            case .settings:
                return "gear"
            }
        }
    }

    var onSelectSection: ((Section) -> Void)?
    var availableSections: [Section] { sections }

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var sections: [Section] = [.feed, .saved, .settings]
    private var selectedSection: Section = .feed

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "HackerPillar"
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SidebarCell")
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func updateSections(_ sections: [Section]) {
        self.sections = sections
        if !sections.contains(selectedSection) {
            selectedSection = .feed
        }
        tableView.reloadData()
        if let index = sections.firstIndex(of: selectedSection) {
            tableView.selectRow(at: IndexPath(row: index, section: 0), animated: false, scrollPosition: .none)
        }
    }

    func select(_ section: Section) {
        guard let index = sections.firstIndex(of: section) else { return }
        selectedSection = section
        tableView.selectRow(at: IndexPath(row: index, section: 0), animated: false, scrollPosition: .none)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SidebarCell", for: indexPath)
        let section = sections[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = section.title
        content.image = UIImage(systemName: section.icon)
        cell.contentConfiguration = content
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < sections.count else { return }
        let section = sections[indexPath.row]
        selectedSection = section
        onSelectSection?(section)
    }
}
