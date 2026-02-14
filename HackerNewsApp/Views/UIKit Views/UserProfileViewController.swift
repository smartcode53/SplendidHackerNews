import UIKit
import Combine
import SafariServices

@MainActor
final class UserProfileViewModel: ObservableObject {
    @Published private(set) var user: HNUser?
    @Published private(set) var storySubmissions: [HNUserSubmission] = []
    @Published private(set) var commentSubmissions: [HNUserSubmission] = []
    @Published private(set) var loadState: LoadState = .idle

    private let username: String
    private let apiClient = HNAPIClient()

    init(username: String) {
        self.username = username
    }

    func load() async {
        loadState = .loading
        do {
            let profile = try await apiClient.fetchUser(id: username)
            user = profile
            let ids = Array(profile.submitted.prefix(100))
            let submissions = try await fetchSubmissions(ids: ids)

            storySubmissions = submissions
                .filter { ($0.type ?? "story") != "comment" }
                .sorted { ($0.time ?? 0) > ($1.time ?? 0) }
            commentSubmissions = submissions
                .filter { ($0.type ?? "") == "comment" }
                .sorted { ($0.time ?? 0) > ($1.time ?? 0) }
            loadState = .loaded
        } catch {
            let message = ErrorPresenter.message(
                for: error,
                defaultMessage: "Failed to load user profile.",
                debugTag: "HN_USER_PROFILE"
            )
            loadState = .error(message: message, canRetry: true)
        }
    }

    private func fetchSubmissions(ids: [Int], maxConcurrent: Int = 12) async throws -> [HNUserSubmission] {
        guard !ids.isEmpty else { return [] }
        return try await withThrowingTaskGroup(of: HNUserSubmission?.self) { group in
            var results: [HNUserSubmission] = []
            results.reserveCapacity(ids.count)
            var iterator = ids.makeIterator()

            for _ in 0..<min(maxConcurrent, ids.count) {
                guard let id = iterator.next() else { break }
                group.addTask { try await self.apiClient.fetchUserSubmission(id: id) }
            }

            for try await submission in group {
                if let submission {
                    results.append(submission)
                }
                if let id = iterator.next() {
                    group.addTask { try await self.apiClient.fetchUserSubmission(id: id) }
                }
            }
            return results
        }
    }

    func aboutText() -> String {
        guard let raw = user?.about, !raw.isEmpty else { return "No about text." }
        return Self.stripHTML(raw)
    }

    func createdDateText() -> String {
        guard let created = user?.created else { return "Unknown" }
        return Date.unixToRegular(created)
    }

    static func stripHTML(_ value: String) -> String {
        guard let data = value.data(using: .utf8) else { return value }
        if let attributed = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
        ) {
            return attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}

@MainActor
final class UserProfileViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let vm: UserProfileViewModel
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var cancellables: Set<AnyCancellable> = []

    init(username: String) {
        self.vm = UserProfileViewModel(username: username)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = vm.user?.id ?? "Profile"
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        configureTableView()
        bind()
        Task { await vm.load() }
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ProfileCell")
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func bind() {
        vm.$user
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.title = user?.id ?? "Profile"
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        vm.$storySubmissions
            .combineLatest(vm.$commentSubmissions, vm.$loadState)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        3
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 3
        case 1:
            return min(20, vm.storySubmissions.count)
        case 2:
            return min(20, vm.commentSubmissions.count)
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Profile"
        case 1:
            return "Stories"
        case 2:
            return "Comments"
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.secondaryTextProperties.color = .secondaryLabel
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.numberOfLines = 0
        cell.accessoryType = .none

        switch indexPath.section {
        case 0:
            cell.selectionStyle = .none
            if indexPath.row == 0 {
                content.text = vm.user?.id ?? "Unknown"
                content.secondaryText = "Karma: \(vm.user?.karma ?? 0)"
            } else if indexPath.row == 1 {
                content.text = "Created"
                content.secondaryText = vm.createdDateText()
            } else {
                content.text = "About"
                content.secondaryText = vm.aboutText()
            }
        case 1:
            cell.selectionStyle = .default
            let item = vm.storySubmissions[indexPath.row]
            content.text = item.title ?? "Story \(item.id)"
            let points = item.score ?? 0
            let time = item.time.map(Date.getTimeInterval(with:)) ?? "Unknown"
            content.secondaryText = "\(points) points • \(time)"
            if item.url != nil {
                cell.accessoryType = .disclosureIndicator
            }
        case 2:
            cell.selectionStyle = .none
            let item = vm.commentSubmissions[indexPath.row]
            let rawText = item.text.map(UserProfileViewModel.stripHTML) ?? ""
            content.text = rawText.isEmpty ? "Comment \(item.id)" : rawText
            content.secondaryText = item.time.map(Date.getTimeInterval(with:)) ?? "Unknown"
        default:
            break
        }

        cell.contentConfiguration = content
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1 else { return }
        let item = vm.storySubmissions[indexPath.row]
        guard let rawURL = item.url else { return }
        let url = NetworkManager.instance.safelyLoadUrl(url: rawURL)
        present(SFSafariViewController(url: url), animated: true)
    }
}
