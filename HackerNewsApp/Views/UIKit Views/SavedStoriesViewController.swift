import UIKit
import SafariServices

final class SavedStoriesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
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
        configureICloudSync()
        mergePendingBookmarksIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        persist()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureICloudSync()
    }

    private func configureICloudSync() {
        let enabled = globalSettings.settings.iCloudSyncEnabled && ProFeatureGate.shared.isPro
        vm.configureICloudSync(enabled: enabled)
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
