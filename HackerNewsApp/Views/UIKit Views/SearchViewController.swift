import UIKit
import Combine
import SafariServices

@MainActor
private final class SearchViewModel: ObservableObject {
    @Published private(set) var results: [HNAlgoliaClient.SearchResult] = []
    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var filters = HNAlgoliaClient.SearchFilters()

    private let client = HNAlgoliaClient()
    private var currentQuery = ""
    private var currentPage = 0
    private var totalPages = 0
    private var isLoading = false

    func updateFilters(_ filters: HNAlgoliaClient.SearchFilters) {
        self.filters = filters
    }

    func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        currentQuery = trimmed
        currentPage = 0
        totalPages = 0
        results = []
        guard !trimmed.isEmpty else {
            loadState = .idle
            return
        }
        await fetchPage(page: 0)
    }

    func loadMoreIfNeeded(currentIndex: Int) async {
        guard !isLoading else { return }
        guard currentIndex >= results.count - 8 else { return }
        guard currentPage + 1 < totalPages else { return }
        await fetchPage(page: currentPage + 1)
    }

    private func fetchPage(page: Int) async {
        guard !currentQuery.isEmpty else { return }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        if page == 0 {
            loadState = .loading
        }

        do {
            let response = try await client.search(query: currentQuery, page: page, filters: filters)
            currentPage = response.page
            totalPages = response.totalPages
            if page == 0 {
                results = response.results
            } else {
                results.append(contentsOf: response.results)
            }
            loadState = results.isEmpty ? .empty : .loaded
        } catch {
            let message = ErrorPresenter.message(
                for: error,
                defaultMessage: "Search failed. Please try again.",
                debugTag: "HN_SEARCH"
            )
            loadState = .error(message: message, canRetry: true)
        }
    }
}

@MainActor
final class SearchViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating, UISearchBarDelegate {
    private let vm = SearchViewModel()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let messageLabel = UILabel()
    private var searchWorkItem: DispatchWorkItem?
    private var cancellables: Set<AnyCancellable> = []
    private let searchController = UISearchController(searchResultsController: nil)
    private let initialQuery: String?

    init(initialQuery: String? = nil) {
        self.initialQuery = initialQuery
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Search"
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        configureNavigation()
        configureTableView()
        bind()
        if let query = initialQuery, !query.isEmpty {
            searchController.searchBar.text = query
            Task { await vm.search(query: query) }
            ShortcutsProvider.shared.donateSearch(query: query)
        }
    }

    private func configureNavigation() {
        navigationItem.largeTitleDisplayMode = .never
        searchController.searchResultsUpdater = self
        searchController.searchBar.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search HN stories and comments"
        navigationItem.searchController = searchController
        definesPresentationContext = true

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            style: .plain,
            target: self,
            action: #selector(openFilters)
        )
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SearchResultCell")
        tableView.keyboardDismissMode = .onDrag
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func bind() {
        vm.$results
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        vm.$loadState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.applyLoadState(state)
            }
            .store(in: &cancellables)
    }

    private func applyLoadState(_ state: LoadState) {
        switch state {
        case .idle:
            spinner.stopAnimating()
            messageLabel.text = "Search HackerPillar"
            messageLabel.textAlignment = .center
            messageLabel.textColor = .secondaryLabel
            tableView.backgroundView = messageLabel
        case .loading:
            spinner.startAnimating()
            tableView.backgroundView = spinner
        case .empty:
            spinner.stopAnimating()
            messageLabel.text = "No results."
            messageLabel.textAlignment = .center
            messageLabel.textColor = .secondaryLabel
            tableView.backgroundView = messageLabel
        case .error(let message, _):
            spinner.stopAnimating()
            messageLabel.text = message
            messageLabel.numberOfLines = 0
            messageLabel.textAlignment = .center
            messageLabel.textColor = .secondaryLabel
            tableView.backgroundView = messageLabel
        case .loaded:
            spinner.stopAnimating()
            tableView.backgroundView = nil
        }
    }

    @objc private func openFilters() {
        let alert = UIAlertController(title: "Search Filters", message: "Optional filters", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Author contains"
            field.text = self.vm.filters.author
        }
        alert.addTextField { field in
            field.placeholder = "Domain contains"
            field.text = self.vm.filters.domain
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addTextField { field in
            field.placeholder = "Minimum points"
            field.keyboardType = .numberPad
            if let minPoints = self.vm.filters.minPoints {
                field.text = String(minPoints)
            }
        }

        for range in HNAlgoliaClient.SearchFilters.DateRange.allCases {
            alert.addAction(UIAlertAction(title: "Date: \(range.rawValue)", style: .default) { [weak self, weak alert] _ in
                guard let self, let alert else { return }
                let author = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let domain = alert.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let minPoints = Int(alert.textFields?[2].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                self.vm.updateFilters(HNAlgoliaClient.SearchFilters(dateRange: range, minPoints: minPoints, author: author, domain: domain))
                let query = self.searchController.searchBar.text ?? ""
                Task { await self.vm.search(query: query) }
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func updateSearchResults(for searchController: UISearchController) {
        searchWorkItem?.cancel()
        let query = searchController.searchBar.text ?? ""
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { await self.vm.search(query: query) }
            ShortcutsProvider.shared.donateSearch(query: query)
        }
        searchWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchWorkItem?.cancel()
        let query = searchBar.text ?? ""
        Task { await vm.search(query: query) }
        ShortcutsProvider.shared.donateSearch(query: query)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        vm.results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath)
        let result = vm.results[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = result.title
        content.secondaryText = result.subtitle
        content.textProperties.numberOfLines = 2
        content.secondaryTextProperties.numberOfLines = 3
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < vm.results.count else { return }
        let result = vm.results[indexPath.row]

        if let url = result.url {
            present(SFSafariViewController(url: url), animated: true)
            return
        }

        let fallbackURL: URL?
        if result.kind == .comment, let storyID = result.storyID {
            fallbackURL = URL(string: "https://news.ycombinator.com/item?id=\(storyID)")
        } else {
            fallbackURL = URL(string: "https://news.ycombinator.com/item?id=\(result.id)")
        }
        if let fallbackURL {
            present(SFSafariViewController(url: fallbackURL), animated: true)
        }
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        Task { await vm.loadMoreIfNeeded(currentIndex: indexPath.row) }
    }
}
