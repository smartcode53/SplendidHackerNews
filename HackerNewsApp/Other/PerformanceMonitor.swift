import Foundation
import MetricKit

final class PerformanceMonitor: NSObject, MXMetricManagerSubscriber {
    static let shared = PerformanceMonitor()

    struct PerformanceSample: Codable {
        let timestamp: Date
        let launchDurationSeconds: Double?
        let metricPayloadCount: Int
        let diagnosticPayloadCount: Int
        let note: String
    }

    private let fileURL = FileManager.default.documentsDirectory.appending(component: "performance_samples.json")
    private var samples: [PerformanceSample] = []
    private var launchStart: CFAbsoluteTime?
    private let lock = NSLock()

    private override init() {
        super.init()
        loadFromDisk()
        MXMetricManager.shared.add(self)
    }

    deinit {
        MXMetricManager.shared.remove(self)
    }

    func markLaunchStart() {
        lock.lock()
        launchStart = CFAbsoluteTimeGetCurrent()
        lock.unlock()
    }

    func markLaunchDisplayed() {
        lock.lock()
        let start = launchStart
        launchStart = nil
        lock.unlock()

        guard let start else { return }
        let elapsed = max(0, CFAbsoluteTimeGetCurrent() - start)
        append(
            PerformanceSample(
                timestamp: Date(),
                launchDurationSeconds: elapsed,
                metricPayloadCount: 0,
                diagnosticPayloadCount: 0,
                note: "Launch completed"
            )
        )
    }

    func snapshot() -> [PerformanceSample] {
        lock.lock()
        let copy = samples
        lock.unlock()
        return copy
    }

    func clearAll() {
        lock.lock()
        samples.removeAll()
        lock.unlock()
        try? FileManager.default.removeItem(at: fileURL)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        append(
            PerformanceSample(
                timestamp: Date(),
                launchDurationSeconds: nil,
                metricPayloadCount: payloads.count,
                diagnosticPayloadCount: 0,
                note: "MetricKit metrics payload"
            )
        )
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        append(
            PerformanceSample(
                timestamp: Date(),
                launchDurationSeconds: nil,
                metricPayloadCount: 0,
                diagnosticPayloadCount: payloads.count,
                note: "MetricKit diagnostics payload"
            )
        )
    }

    private func append(_ sample: PerformanceSample) {
        lock.lock()
        samples.insert(sample, at: 0)
        if samples.count > 200 {
            samples = Array(samples.prefix(200))
        }
        let snapshot = samples
        lock.unlock()
        saveToDisk(snapshot)
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([PerformanceSample].self, from: data) else {
            return
        }
        samples = decoded
    }

    private func saveToDisk(_ snapshot: [PerformanceSample]) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
