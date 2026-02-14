import UIKit
import SafariServices

final class TrackedThreadsViewController: UITableViewController {
    private var stories: [TrackedStory] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Tracked Threads"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TrackedThreadCell")
        tableView.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(refreshTapped)
        )
        Task { await reloadData() }
    }

    @objc private func refreshTapped() {
        Task {
            await CommentMonitor.shared.checkNow()
            await reloadData()
        }
    }

    private func reloadData() async {
        stories = await NotificationStore.shared.allTrackedStories()
            .sorted { $0.lastCheckedAt > $1.lastCheckedAt }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        stories.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TrackedThreadCell", for: indexPath)
        let story = stories[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = story.title
        let checked = RelativeDateTimeFormatter().localizedString(for: story.lastCheckedAt, relativeTo: Date())
        content.secondaryText = "Last seen: \(story.lastSeenCommentCount) comments • checked \(checked)"
        content.secondaryTextProperties.color = .secondaryLabel
        content.secondaryTextProperties.numberOfLines = 2
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        guard indexPath.row < stories.count else { return }
        let storyID = stories[indexPath.row].id
        Task {
            await NotificationStore.shared.remove(storyID: storyID)
            await reloadData()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < stories.count else { return }
        let storyID = stories[indexPath.row].id
        guard let url = URL(string: "https://news.ycombinator.com/item?id=\(storyID)") else { return }
        present(SFSafariViewController(url: url), animated: true)
    }
}
