import Foundation

actor OfflineStore {
    static let shared = OfflineStore()

    private let fileManager: FileManager
    private let maxStories: Int
    private let indexURL: URL
    private let imagesDirectoryURL: URL

    private struct PersistedOfflineStory: Codable {
        let storyID: Int
        let title: String
        let author: String
        let urlString: String?
        let savedAt: Date
        let readerContent: String
        let imageFileName: String?
        let commentsSnapshot: Item?
    }

    init(fileManager: FileManager = .default, maxStories: Int = 50) {
        self.fileManager = fileManager
        self.maxStories = maxStories

        let documents = fileManager.documentsDirectory
        self.indexURL = documents.appending(component: "offline_stories.json")
        self.imagesDirectoryURL = documents.appending(component: "offline_images")

        if !fileManager.fileExists(atPath: imagesDirectoryURL.path()) {
            try? fileManager.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
        }
    }

    func loadStories() -> [OfflineStory] {
        let persisted = readPersistedStories()
        return persisted
            .sorted { $0.savedAt > $1.savedAt }
            .map { item in
                let imageData: Data?
                if let imageFileName = item.imageFileName {
                    let imageURL = imagesDirectoryURL.appending(component: imageFileName)
                    imageData = try? Data(contentsOf: imageURL)
                } else {
                    imageData = nil
                }

                return OfflineStory(
                    storyID: item.storyID,
                    title: item.title,
                    author: item.author,
                    urlString: item.urlString,
                    savedAt: item.savedAt,
                    readerContent: item.readerContent,
                    imageData: imageData,
                    commentsSnapshot: item.commentsSnapshot
                )
            }
    }

    func story(storyID: Int) -> OfflineStory? {
        loadStories().first(where: { $0.storyID == storyID })
    }

    func save(_ story: OfflineStory) throws {
        var persisted = readPersistedStories()
        let existing = persisted.first(where: { $0.storyID == story.storyID })

        if let old = existing {
            if let oldImage = old.imageFileName {
                deleteImage(named: oldImage)
            }
            persisted.removeAll { $0.storyID == old.storyID }
        }

        var imageFileName: String?
        if let data = story.imageData {
            let fileName = "\(story.storyID).jpg"
            let imageURL = imagesDirectoryURL.appending(component: fileName)
            try data.write(to: imageURL, options: .atomic)
            imageFileName = fileName
        }

        let item = PersistedOfflineStory(
            storyID: story.storyID,
            title: story.title,
            author: story.author,
            urlString: story.urlString,
            savedAt: story.savedAt,
            readerContent: story.readerContent,
            imageFileName: imageFileName,
            commentsSnapshot: story.commentsSnapshot
        )

        persisted.append(item)
        persisted.sort { $0.savedAt > $1.savedAt }

        if persisted.count > maxStories {
            let overflow = persisted[maxStories...]
            for item in overflow {
                if let imageName = item.imageFileName {
                    deleteImage(named: imageName)
                }
            }
            persisted = Array(persisted.prefix(maxStories))
        }

        try writePersistedStories(persisted)
    }

    func delete(storyID: Int) throws {
        var persisted = readPersistedStories()
        guard let existing = persisted.first(where: { $0.storyID == storyID }) else { return }

        if let imageName = existing.imageFileName {
            deleteImage(named: imageName)
        }

        persisted.removeAll { $0.storyID == storyID }
        try writePersistedStories(persisted)
    }

    private func readPersistedStories() -> [PersistedOfflineStory] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        return (try? JSONDecoder().decode([PersistedOfflineStory].self, from: data)) ?? []
    }

    private func writePersistedStories(_ stories: [PersistedOfflineStory]) throws {
        let data = try JSONEncoder().encode(stories)
        try data.write(to: indexURL, options: .atomic)
    }

    private func deleteImage(named fileName: String) {
        let imageURL = imagesDirectoryURL.appending(component: fileName)
        try? fileManager.removeItem(at: imageURL)
    }
}
