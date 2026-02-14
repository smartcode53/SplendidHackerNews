import UIKit
import SafariServices

final class HistoryUIKitViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let vm = HistoryViewModel()
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
        title = "History"
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .trash,
            target: self,
            action: #selector(clearHistory)
        )

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "history")

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        Task {
            await vm.load()
            tableView.reloadData()
        }
    }

    @objc private func clearHistory() {
        Task {
            await vm.clear()
            tableView.reloadData()
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(vm.entries.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "history", for: indexPath)
        var content = UIListContentConfiguration.subtitleCell()
        if vm.entries.isEmpty {
            content.text = "No history yet"
            content.secondaryText = "Opened stories will appear here."
            cell.selectionStyle = .none
            cell.accessoryType = .none
            cell.contentConfiguration = content
            return cell
        }

        let entry = vm.entries[indexPath.row]
        content.text = entry.title
        content.secondaryText = "\(entry.feed) · \(Date.unixToRegular(entry.openedAt))"
        content.textProperties.numberOfLines = 2
        cell.accessoryType = .disclosureIndicator
        cell.contentConfiguration = content
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < vm.entries.count else { return }
        let entry = vm.entries[indexPath.row]
        let story = Story(
            by: "history",
            descendants: nil,
            id: entry.storyID,
            score: 0,
            time: entry.openedAt,
            title: entry.title,
            type: "story",
            url: entry.url
        )
        if globalSettings.settings.openInReader {
            navigationController?.pushViewController(ReaderViewController(story: story, globalSettings: globalSettings), animated: true)
        } else if let url = entry.url {
            present(SFSafariViewController(url: NetworkManager.instance.safelyLoadUrl(url: url)), animated: true)
        }
    }
}
