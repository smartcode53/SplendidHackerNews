import UIKit
import Combine

@MainActor
final class OfflineViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let vm: OfflineViewModel
    private var cancellables: Set<AnyCancellable> = []

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyLabel = UILabel()

    convenience init() {
        self.init(vm: OfflineViewModel())
    }

    init(vm: OfflineViewModel) {
        self.vm = vm
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Offline"
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        configureTableView()
        configureEmptyState()
        bind()

        Task { await vm.reload() }
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "offline")

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureEmptyState() {
        emptyLabel.text = "No offline stories yet."
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.numberOfLines = 0
    }

    private func bind() {
        vm.$offlineStories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.tableView.reloadData()
                self.tableView.backgroundView = self.vm.offlineStories.isEmpty ? self.emptyLabel : nil
            }
            .store(in: &cancellables)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(vm.offlineStories.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "offline", for: indexPath)
        var content = UIListContentConfiguration.subtitleCell()

        if vm.offlineStories.isEmpty {
            content.text = "No offline stories yet"
            content.secondaryText = "Use Save Offline on any feed story."
            cell.selectionStyle = .none
            cell.accessoryType = .none
            cell.contentConfiguration = content
            return cell
        }

        let story = vm.offlineStories[indexPath.row]
        content.text = story.title
        content.secondaryText = "\(story.author) · saved \(story.savedAt.formatted(date: .abbreviated, time: .shortened))"
        content.textProperties.numberOfLines = 2
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < vm.offlineStories.count else { return }
        let story = vm.offlineStories[indexPath.row]
        navigationController?.pushViewController(OfflineReaderViewController(story: story), animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row < vm.offlineStories.count else { return nil }
        let storyID = vm.offlineStories[indexPath.row].storyID
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            Task {
                await self?.vm.delete(storyID: storyID)
                completion(true)
            }
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
}

@MainActor
private final class OfflineReaderViewController: UIViewController {
    private let story: OfflineStory

    private let imageView = UIImageView()
    private let textView = UITextView()

    init(story: OfflineStory) {
        self.story = story
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Offline Reader"
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        configureViews()
        render()
    }

    private func configureViews() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.layer.cornerCurve = .continuous

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .clear
        textView.font = .preferredFont(forTextStyle: .body)
        textView.isEditable = false
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 20, right: 12)

        view.addSubview(imageView)
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            imageView.heightAnchor.constraint(equalToConstant: 180),

            textView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 10),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func render() {
        if let imageData = story.imageData, let image = UIImage(data: imageData) {
            imageView.image = image
            imageView.isHidden = false
        } else {
            imageView.isHidden = true
        }

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.label
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label
        ]

        let text = NSMutableAttributedString(string: story.title + "\n\n", attributes: titleAttributes)
        text.append(NSAttributedString(string: story.readerContent, attributes: bodyAttributes))
        textView.attributedText = text
    }
}
