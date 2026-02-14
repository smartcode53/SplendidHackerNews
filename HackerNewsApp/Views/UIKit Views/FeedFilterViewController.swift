import UIKit

@MainActor
final class FeedFilterViewController: UIViewController {
    private var filter: FeedFilter
    private let onApply: (FeedFilter?) -> Void

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    private let dateRangeControl = UISegmentedControl(items: FeedFilter.DateRange.allCases.map(\.title))
    private let domainsField = UITextField()
    private let excludeDomainsField = UITextField()
    private let keywordsField = UITextField()
    private let minScoreField = UITextField()

    init(filter: FeedFilter?, onApply: @escaping (FeedFilter?) -> Void) {
        self.filter = (filter ?? .empty).normalized()
        self.onApply = onApply
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Feed Filters"
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Apply", style: .plain, target: self, action: #selector(applyTapped))

        configureLayout()
        configureState()
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor)
        ])

        stackView.addArrangedSubview(makeCard(title: "Date Range", body: dateRangeControl))

        configureField(domainsField, placeholder: "Include domains (comma separated)")
        stackView.addArrangedSubview(makeCard(title: "Domains", body: domainsField))

        configureField(excludeDomainsField, placeholder: "Exclude domains (comma separated)")
        stackView.addArrangedSubview(makeCard(title: "Exclude Domains", body: excludeDomainsField))

        configureField(keywordsField, placeholder: "Keywords in title (comma separated)")
        stackView.addArrangedSubview(makeCard(title: "Keywords", body: keywordsField))

        configureField(minScoreField, placeholder: "Minimum points (e.g. 100)")
        minScoreField.keyboardType = .numberPad
        stackView.addArrangedSubview(makeCard(title: "Min Score", body: minScoreField))
    }

    private func configureField(_ field: UITextField, placeholder: String) {
        field.borderStyle = .roundedRect
        field.placeholder = placeholder
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
    }

    private func makeCard(title: String, body: UIView) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(named: "CardColor") ?? .secondarySystemBackground
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous

        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.text = title

        let stack = UIStackView(arrangedSubviews: [titleLabel, body])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        return card
    }

    private func configureState() {
        dateRangeControl.selectedSegmentIndex = FeedFilter.DateRange.allCases.firstIndex(of: filter.dateRange) ?? 0
        domainsField.text = filter.domains.joined(separator: ", ")
        excludeDomainsField.text = filter.excludeDomains.joined(separator: ", ")
        keywordsField.text = filter.keywords.joined(separator: ", ")
        if let minScore = filter.minScore {
            minScoreField.text = String(minScore)
        }
    }

    @objc private func clearTapped() {
        onApply(nil)
        dismiss(animated: true)
    }

    @objc private func applyTapped() {
        let selectedRange = FeedFilter.DateRange.allCases[max(0, dateRangeControl.selectedSegmentIndex)]
        let minScore = Int(minScoreField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")

        let next = FeedFilter(
            dateRange: selectedRange,
            domains: parseCSV(domainsField.text),
            excludeDomains: parseCSV(excludeDomainsField.text),
            minScore: minScore,
            keywords: parseCSV(keywordsField.text)
        ).normalized()

        onApply(next.isActive ? next : nil)
        dismiss(animated: true)
    }

    private func parseCSV(_ value: String?) -> [String] {
        guard let value else { return [] }
        return value
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
