//
//  AltNetworkManager.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/3/22.
//

import Foundation
import SwiftUI
import OpenGraph

// MARK: - In-Flight Request Deduplication

/// Actor that coalesces concurrent OpenGraph image-URL fetches for the same URL.
/// When multiple callers request the same URL simultaneously, only one network
/// request is issued; all callers await the same continuation.
/// This prevents the race between prefetchImageURLs and PostView's .task loadImage.
private actor OpenGraphDeduplicator {
    /// Maps a normalized URL string to the in-flight Task fetching its OG image.
    private var inFlight: [String: Task<URL?, Never>] = [:]

    /// Returns the OG image URL for the given page URL, deduplicating concurrent requests.
    func fetchImageURL(for urlString: String, using fetcher: @escaping @Sendable (String) async -> URL?) async -> URL? {
        // If there's already an in-flight request for this URL, just await it
        if let existing = inFlight[urlString] {
            return await existing.value
        }

        // Create a new task and register it
        let task = Task<URL?, Never> {
            await fetcher(urlString)
        }
        inFlight[urlString] = task

        let result = await task.value

        // Clean up after completion so future requests (after cache) go through fresh
        inFlight[urlString] = nil

        return result
    }
}

final class NetworkManager: @unchecked Sendable {

    static let instance = NetworkManager()

    /// Dedicated URLSession for OpenGraph HTML fetching.
    /// Higher connection limits since OG fetches hit many different hosts.
    /// Shorter timeout since we'd rather skip an image than block the feed.
    private let ogSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 4
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// Dedicated URLSession for Algolia comment API fetches.
    /// Separate from shared session to allow tuned timeouts and connection limits.
    /// Algolia is a single host, so higher concurrency limit is beneficial when
    /// the user rapidly opens multiple comment threads.
    private let algoliaSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 6
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    /// Shared JSON decoder for comment responses.
    /// Allocated once instead of per-request to avoid repeated setup cost.
    private let commentDecoder = JSONDecoder()

    /// In-flight deduplicator for OG image fetches
    private let ogDeduplicator = OpenGraphDeduplicator()

    // Sub-function to help fetch a single story using its ID.
    func fetchSingleStory(withId id: Int) async -> Story? {
        guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(id).json") else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let safeStory = try? JSONDecoder().decode(Story.self, from: data)
            return safeStory
        } catch let error {
            print("There was an error fetching stories from the server: \(error)")
            return nil
        }
    }

    /// Fetches the OpenGraph image URL for a given page URL.
    /// Requests are deduplicated: if another caller is already fetching the
    /// same URL, this call awaits the existing in-flight request instead of
    /// issuing a duplicate network call.
    func getImage(fromUrl url: String) async -> URL? {
        let secureUrl = getSecureUrlString(url: url)
        return await ogDeduplicator.fetchImageURL(for: secureUrl) { [self] urlString in
            await self._fetchOGImage(urlString: urlString)
        }
    }

    /// The actual OpenGraph fetch implementation (called only once per URL
    /// even if multiple callers request it concurrently).
    private func _fetchOGImage(urlString: String) async -> URL? {
        guard let safeUrl = URL(string: urlString) else { return nil }

        do {
            let og = try await OpenGraph.fetch(url: safeUrl)
            guard let ogUrl = og[.image] else { return nil }
            if let finalUrl = URL(string: ogUrl) {
                return finalUrl
            }
        } catch {
            print("There was an error fetching the image: \(error)")
        }

        return nil
    }

    // Function to convert non-HTTPS URLs to HTTPS
    func getSecureUrlString(url: String) -> String {
        let atsSecureUrl = url.contains("https") ? url : url.replacingOccurrences(of: "http", with: "https", range: url.startIndex..<url.index(url.startIndex, offsetBy: 6))
        return atsSecureUrl
    }

    // Function to fetch comments associated with a single story.
    // Uses dedicated `algoliaSession` with tuned timeouts.
    // Retries once on transient network errors via `RetryPolicy`.
    func getComments(forId id: Int) async -> Item? {
#if DEBUG
        let debugForceBadURL = false
        let debugBadURL = URL(string: "https://example.invalid")
#endif
        let urlString = "https://hn.algolia.com/api/v1/items/\(id)"
#if DEBUG
        let resolvedURL = debugForceBadURL ? debugBadURL : URL(string: urlString)
#else
        let resolvedURL = URL(string: urlString)
#endif
        guard let url = resolvedURL else { return nil }

        do {
            let data = try await RetryPolicy.runWithTransientRetry { [algoliaSession] in
                let (data, _) = try await algoliaSession.data(from: url)
                return data
            }
            do {
                let safeData = try commentDecoder.decode(Item.self, from: data)
                return safeData
            } catch let error {
                print("Decoding error in getComments: \(error)")
            }
        } catch let error {
            print("There was an error fetching comment data from the server. The complete description of the error is as follows: \(error)")
        }

        return nil
    }

    // Functin to de-optionalize a URL
    func safelyLoadUrl(url: String) -> URL {
        let atsSecureUrlString = getSecureUrlString(url: url)
        if let safeUrl = URL(string: atsSecureUrlString) {
            return safeUrl
        } else {
            return URL(string: "")!
        }
    }
}
