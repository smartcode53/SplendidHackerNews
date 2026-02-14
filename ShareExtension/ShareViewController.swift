import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let suiteName = "group.com.hackerpillar.shared"
    private let pendingURLsKey = "share.pending.urls"

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleShare()
    }

    private func handleShare() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem], !items.isEmpty else {
            ShareImportTelemetry.recordFailure(stage: "extension", message: "No shared content.")
            cancel(with: "No shared content")
            return
        }

        Task {
            if let sharedURL = await extractFirstURL(from: items) {
                store(url: sharedURL)
                extensionContext?.completeRequest(returningItems: nil)
            } else {
                ShareImportTelemetry.recordFailure(stage: "extension", message: "No URL found in shared payload.")
                cancel(with: "No URL found")
            }
        }
    }

    private func extractFirstURL(from items: [NSExtensionItem]) async -> URL? {
        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = await loadURL(from: provider, typeIdentifier: UTType.url.identifier) {
                    return url
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let url = await loadURL(from: provider, typeIdentifier: UTType.plainText.identifier) {
                    return url
                }
            }
        }
        return nil
    }

    private func loadURL(from provider: NSItemProvider, typeIdentifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                    return
                }

                if let text = item as? String,
                   let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    continuation.resume(returning: url)
                    return
                }

                continuation.resume(returning: nil)
            }
        }
    }

    private func store(url: URL) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            ShareImportTelemetry.recordFailure(stage: "extension", message: "Missing app-group defaults.")
            return
        }
        var existing = defaults.stringArray(forKey: pendingURLsKey) ?? []
        if existing.contains(url.absoluteString) == false {
            existing.append(url.absoluteString)
            defaults.set(existing, forKey: pendingURLsKey)
        }
    }

    private func cancel(with message: String) {
        let error = NSError(domain: "HackerPillar.ShareExtension", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        extensionContext?.cancelRequest(withError: error)
    }
}
