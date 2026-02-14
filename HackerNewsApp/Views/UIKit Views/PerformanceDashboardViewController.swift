import UIKit

final class PerformanceDashboardViewController: UITableViewController {
    private enum RetentionWindow: Int, CaseIterable {
        case last24Hours
        case last7Days
        case last30Days
        case all

        var title: String {
            switch self {
            case .last24Hours:
                return "24H"
            case .last7Days:
                return "7D"
            case .last30Days:
                return "30D"
            case .all:
                return "All"
            }
        }

        var thresholdDate: Date? {
            let now = Date()
            switch self {
            case .last24Hours:
                return now.addingTimeInterval(-24 * 60 * 60)
            case .last7Days:
                return now.addingTimeInterval(-7 * 24 * 60 * 60)
            case .last30Days:
                return now.addingTimeInterval(-30 * 24 * 60 * 60)
            case .all:
                return nil
            }
        }
    }

    private var allSamples: [PerformanceMonitor.PerformanceSample] = []
    private var samples: [PerformanceMonitor.PerformanceSample] = []
    private let retentionControl = UISegmentedControl(items: RetentionWindow.allCases.map(\.title))
    private var selectedWindow: RetentionWindow = .all

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Performance"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PerformanceCell")
        tableView.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        retentionControl.selectedSegmentIndex = RetentionWindow.allCases.firstIndex(of: .all) ?? 0
        retentionControl.addTarget(self, action: #selector(retentionChanged), for: .valueChanged)
        navigationItem.titleView = retentionControl
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Clear",
            style: .plain,
            target: self,
            action: #selector(clearTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(refreshTapped)
        )
        reload()
    }

    @objc private func refreshTapped() {
        reload()
    }

    @objc private func retentionChanged() {
        selectedWindow = RetentionWindow(rawValue: retentionControl.selectedSegmentIndex) ?? .all
        applyRetentionFilter()
    }

    @objc private func clearTapped() {
        let alert = UIAlertController(
            title: "Clear Performance Data?",
            message: "This will remove all local launch and diagnostics samples.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            PerformanceMonitor.shared.clearAll()
            self?.reload()
        })
        present(alert, animated: true)
    }

    private func reload() {
        allSamples = PerformanceMonitor.shared.snapshot()
        applyRetentionFilter()
    }

    private func applyRetentionFilter() {
        if let threshold = selectedWindow.thresholdDate {
            samples = allSamples.filter { $0.timestamp >= threshold }
        } else {
            samples = allSamples
        }
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return 1 }
        return max(samples.count, 1)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Summary" : "Samples"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PerformanceCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.textProperties.numberOfLines = 2
        content.secondaryTextProperties.numberOfLines = 3
        content.secondaryTextProperties.color = .secondaryLabel
        cell.selectionStyle = .none

        if indexPath.section == 0 {
            let launchSamples = samples.compactMap(\.launchDurationSeconds)
            if launchSamples.isEmpty {
                content.text = "No launch samples yet."
                content.secondaryText = "Open the app a few times to build baseline data for the selected window."
            } else {
                let avg = launchSamples.reduce(0, +) / Double(launchSamples.count)
                let sorted = launchSamples.sorted()
                let median = sorted[sorted.count / 2]
                let p95Index = min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.95))
                let p95 = sorted[p95Index]
                let fastCount = launchSamples.filter { $0 < 1.5 }.count
                let warmCount = launchSamples.filter { $0 >= 1.5 && $0 < 2.5 }.count
                let slowCount = launchSamples.filter { $0 >= 2.5 }.count
                content.text = String(format: "Avg %.2fs • P95 %.2fs • Median %.2fs", avg, p95, median)
                content.secondaryText = "Launch samples: \(launchSamples.count) • Total records: \(samples.count)\nFast<1.5s \(fastCount) • 1.5-2.5s \(warmCount) • Slow>2.5s \(slowCount)"
            }
            cell.contentConfiguration = content
            return cell
        }

        guard !samples.isEmpty else {
            content.text = "No samples recorded."
            content.secondaryText = "MetricKit payloads and launch timings appear here."
            cell.contentConfiguration = content
            return cell
        }

        let sample = samples[indexPath.row]
        let timestamp = DateFormatter.localizedString(from: sample.timestamp, dateStyle: .short, timeStyle: .short)
        if let launch = sample.launchDurationSeconds {
            content.text = String(format: "%.2fs launch", launch)
            content.secondaryText = "\(timestamp)\n\(sample.note)"
        } else {
            content.text = sample.note
            content.secondaryText = "\(timestamp)\nMetrics: \(sample.metricPayloadCount) • Diagnostics: \(sample.diagnosticPayloadCount)"
        }
        cell.contentConfiguration = content
        return cell
    }
}
