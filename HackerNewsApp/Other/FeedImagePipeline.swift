import Foundation
import UIKit
import ImageIO

actor FeedImagePipeline {
    static let shared = FeedImagePipeline()
    nonisolated(unsafe) private static let imageCache = NSCache<NSString, UIImage>()

    private var inFlightImages: [String: Task<UIImage?, Never>] = [:]
    private var prefetchTasks: [Int: Task<Void, Never>] = [:]
    private let urlCache = UltimatePostViewModel.ImageURLCache.instance
    private let availabilityCache = UltimatePostViewModel.ImageAvailabilityCache.instance
    private let networkManager = NetworkManager.instance

    init() {
        Self.imageCache.countLimit = 180
    }

    nonisolated static func cachedImage(for storyID: Int) -> UIImage? {
        imageCache.object(forKey: String(storyID) as NSString)
    }

    func image(for story: Story) async -> UIImage? {
        let storyKey = String(story.id)
        if let cached = Self.imageCache.object(forKey: storyKey as NSString) {
            return cached
        }

        guard let imageURL = await resolveImageURL(for: story) else { return nil }
        let urlKey = imageURL.absoluteString
        if let task = inFlightImages[urlKey] {
            let image = await task.value
            if let image {
                Self.imageCache.setObject(image, forKey: storyKey as NSString)
            }
            return image
        }

        let task = Task<UIImage?, Never> {
            guard let (data, _) = try? await URLSession.shared.data(from: imageURL) else {
                return nil
            }
            return Self.decodeDownsampledImage(data: data, maxPixel: 900)
        }
        inFlightImages[urlKey] = task

        let image = await task.value
        inFlightImages[urlKey] = nil

        if let image {
            Self.imageCache.setObject(image, forKey: storyKey as NSString)
        }
        return image
    }

    func prefetch(stories: [Story], maxItems: Int = 10) {
        let boundedCount = min(maxItems, 14)
        let candidates = Array(stories.prefix(boundedCount))
        for story in candidates where prefetchTasks[story.id] == nil {
            prefetchTasks[story.id] = Task(priority: .utility) {
                _ = await self.image(for: story)
                self.clearPrefetchTask(storyID: story.id)
            }
        }
    }

    func cancelPrefetch(storyIDs: [Int]) {
        for storyID in storyIDs {
            prefetchTasks[storyID]?.cancel()
            prefetchTasks[storyID] = nil
        }
    }

    private func clearPrefetchTask(storyID: Int) {
        prefetchTasks[storyID] = nil
    }

    private func resolveImageURL(for story: Story) async -> URL? {
        guard let rawURL = story.url, !rawURL.isEmpty else {
            availabilityCache.saveToCache(false, withKey: String(story.id))
            return nil
        }

        let key = String(story.id)
        if let cachedURL = urlCache.getFromCache(withKey: key) {
            return cachedURL
        }
        if let cachedAvailability = availabilityCache.getFromCache(withKey: key), cachedAvailability == false {
            return nil
        }

        let result = await networkManager.getImage(fromUrl: rawURL)
        if let result {
            urlCache.saveToCache(result, withKey: key)
            availabilityCache.saveToCache(true, withKey: key)
            return result
        } else {
            availabilityCache.saveToCache(false, withKey: key)
            return nil
        }
    }

    private static func decodeDownsampledImage(data: Data, maxPixel: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else { return nil }
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }
}
