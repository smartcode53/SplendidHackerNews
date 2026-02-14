import UIKit
import Combine

final class CustomFeedManagerViewController: UITableViewController {
    private let manager = CustomFeedManager.shared
    private var cancellables: Set<AnyCancellable> = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Custom Feeds"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CustomFeedCell")
        tableView.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        tableView.separatorStyle = .singleLine
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
        navigationItem.leftBarButtonItem = editButtonItem
        bind()
    }

    private func bind() {
        manager.$feeds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        manager.feeds.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CustomFeedCell", for: indexPath)
        let feed = manager.feeds[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = feed.name
        content.secondaryText = "\(feed.storyType.rawValue) • \(filterSummary(feed.filter))"
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < manager.feeds.count else { return }
        presentTypePicker(existing: manager.feeds[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        true
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        manager.move(from: IndexSet(integer: sourceIndexPath.row), to: destinationIndexPath.row)
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        guard indexPath.row < manager.feeds.count else { return }
        manager.remove(id: manager.feeds[indexPath.row].id)
    }

    @objc private func addTapped() {
        presentTypePicker(existing: nil)
    }

    private func presentTypePicker(existing: CustomFeed?) {
        let picker = UIAlertController(title: "Feed Type", message: nil, preferredStyle: .actionSheet)
        let allTypes = StoryType.allCases
        for type in allTypes {
            picker.addAction(UIAlertAction(title: type.rawValue, style: .default) { [weak self] _ in
                self?.presentFilterEditor(type: type, existing: existing)
            })
        }
        picker.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = picker.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(picker, animated: true)
    }

    private func presentFilterEditor(type: StoryType, existing: CustomFeed?) {
        let filterVC = FeedFilterViewController(filter: existing?.filter) { [weak self] filter in
            self?.presentNamePrompt(type: type, filter: filter, existing: existing)
        }
        let nav = UINavigationController(rootViewController: filterVC)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    private func presentNamePrompt(type: StoryType, filter: FeedFilter?, existing: CustomFeed?) {
        let alert = UIAlertController(title: "Feed Name", message: "Choose a tab name for this feed.", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Feed Name"
            field.text = existing?.name ?? type.rawValue
            field.autocapitalizationType = .words
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let self, let alert else { return }
            let rawName = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let name = rawName.isEmpty ? type.rawValue : rawName
            let id = existing?.id ?? UUID()
            self.manager.upsert(CustomFeed(id: id, name: name, storyType: type, filter: filter))
        })
        present(alert, animated: true)
    }

    private func filterSummary(_ filter: FeedFilter?) -> String {
        guard let filter, filter.isActive else { return "No filter" }
        var components: [String] = []
        if filter.dateRange != .any { components.append(filter.dateRange.title) }
        if let minScore = filter.minScore, minScore > 0 { components.append("Min \(minScore)") }
        if !filter.domains.isEmpty { components.append("\(filter.domains.count) domain") }
        if !filter.keywords.isEmpty { components.append("\(filter.keywords.count) keyword") }
        if components.isEmpty { return "Active filter" }
        return components.joined(separator: " · ")
    }
}
