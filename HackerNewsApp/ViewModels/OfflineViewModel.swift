import Foundation
import UIKit

@MainActor
final class OfflineViewModel: ObservableObject {
    enum DownloadState: Equatable {
        case idle
        case downloading
        case saved
        case failed(String)
    }

    @Published private(set) var offlineStories: [OfflineStory] = []
    @Published private(set) var downloadStates: [Int: DownloadState] = [:]

    private let store: OfflineStore
    private let networkManager: NetworkManager
    private let extractor: ReaderExtractor

    init(
        store: OfflineStore = .shared,
        networkManager: NetworkManager = .instance,
        extractor: ReaderExtractor = ReaderExtractor()
    ) {
        self.store = store
        self.networkManager = networkManager
        self.extractor = extractor

        Task { await reload() }
    }

    func reload() async {
        let stories = await store.loadStories()
        offlineStories = stories

        let ids = Set(stories.map(\.storyID))
        for id in ids where downloadStates[id] == nil {
            downloadStates[id] = .saved
        }
    }

    func isSaved(storyID: Int) -> Bool {
        offlineStories.contains(where: { $0.storyID == storyID })
    }

    func isDownloading(storyID: Int) -> Bool {
        downloadStates[storyID] == .downloading
    }

    func state(for storyID: Int) -> DownloadState {
        downloadStates[storyID] ?? .idle
    }

    func download(story: Story) {
        if isSaved(storyID: story.id) {
            downloadStates[story.id] = .saved
            return
        }
        guard !isDownloading(storyID: story.id) else { return }

        downloadStates[story.id] = .downloading

        Task {
            do {
                guard let urlString = story.url else {
                    throw OfflineError.missingURL
                }

                let secure = networkManager.getSecureUrlString(url: urlString)
                guard let safeURL = URL(string: secure) else {
                    throw OfflineError.invalidURL
                }

                let extracted = try await extractor.extract(from: safeURL)
                let content = extracted.blocks
                    .map(\.text)
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n\n")

                let image = await FeedImagePipeline.shared.image(for: story)
                let imageData = image?.jpegData(compressionQuality: 0.82)
                let commentsSnapshot = await networkManager.getComments(forId: story.id)

                let offlineStory = OfflineStory(
                    storyID: story.id,
                    title: story.title,
                    author: story.by,
                    urlString: story.url,
                    savedAt: Date(),
                    readerContent: content,
                    imageData: imageData,
                    commentsSnapshot: commentsSnapshot
                )

                try await store.save(offlineStory)
                await reload()
                downloadStates[story.id] = .saved
            } catch {
                downloadStates[story.id] = .failed(error.localizedDescription)
            }
        }
    }

    func delete(storyID: Int) async {
        do {
            try await store.delete(storyID: storyID)
            await reload()
            downloadStates[storyID] = .idle
        } catch {
            downloadStates[storyID] = .failed(error.localizedDescription)
        }
    }
}

enum OfflineError: LocalizedError {
    case missingURL
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .missingURL:
            return "This story does not have a URL to save offline."
        case .invalidURL:
            return "The story URL is invalid."
        }
    }
}
