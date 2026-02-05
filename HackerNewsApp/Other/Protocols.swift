//
//  Protocols.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/5/22.
//

import Foundation

@MainActor
protocol SafariViewLoader: ObservableObject {
    
    var networkManager: NetworkManager { get }
    
    func returnSafelyLoadedUrl(url: String) -> URL
}

extension SafariViewLoader {
    func returnSafelyLoadedUrl(url: String) -> URL {
        return networkManager.safelyLoadUrl(url: url)
    }
}


@MainActor
protocol CommentsButtonProtocol: ObservableObject {
    
    var story: Story? { get set }
    var comments: Item? {get set}
    
    var showStoryInComments: Bool { get set }
    
    var networkManager: NetworkManager { get }
    var commentsCacheManager: CommentsCache { get }
    
    func loadComments(withId id: Int) async
    
    func getCommentAndPointCounts(forPostWithId id: Int) async -> (Int?, Int)? 
}


extension CommentsButtonProtocol {
    
    func loadComments(withId id: Int) async {
        if let cachedItem = commentsCacheManager.getFromCache(withKey: id) {
            comments = cachedItem
            print("Item loaded from cache")
            return
        }

        print("Item needed to be downloaded from the server")
        let result = await networkManager.getComments(forId: id)
        comments = result
        if let safeResult = result {
            commentsCacheManager.saveToCache(safeResult, withKey: id)
            print("Comment cache save successful with id: \(id)")
        }
    }
    
    func getCommentAndPointCounts(forPostWithId id: Int) async -> (Int?, Int)? {
        let story = await networkManager.fetchSingleStory(withId: id)
        if let story {
            return (story.descendants, story.score)
        }
        return nil
    }
}

struct ErrorPresenter {
    static func message(for error: Error?, defaultMessage: String, debugTag: String? = nil) -> String {
        let baseMessage = defaultMessage
#if DEBUG
        if let code = debugTag ?? debugCode(for: error) {
            return "\(baseMessage) [\(code)]"
        }
#endif
        return baseMessage
    }

    static func isTransientNetworkError(_ error: Error) -> Bool {
        let urlError: URLError?
        if let direct = error as? URLError {
            urlError = direct
        } else {
            let nsError = error as NSError
            if nsError.domain == URLError.errorDomain {
                urlError = URLError(_nsError: nsError)
            } else {
                urlError = nil
            }
        }

        guard let urlError else { return false }
        switch urlError.code {
        case .notConnectedToInternet,
             .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .networkConnectionLost,
             .dnsLookupFailed,
             .internationalRoamingOff,
             .callIsActive,
             .dataNotAllowed,
             .resourceUnavailable,
             .cannotLoadFromNetwork:
            return true
        default:
            return false
        }
    }

    private static func debugCode(for error: Error?) -> String? {
        guard let error else { return nil }
        if let urlError = error as? URLError {
            return "URL_\(urlError.code.rawValue)"
        }
        return nil
    }
}

enum RetryPolicy {
    static func runWithTransientRetry<T>(operation: @escaping () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch {
            if ErrorPresenter.isTransientNetworkError(error) {
                let delay = backoffDelay(forAttempt: 1)
                try? await Task.sleep(nanoseconds: delay)
                return try await operation()
            }
            throw error
        }
    }

    static func backoffDelay(forAttempt attempt: Int) -> UInt64 {
        switch attempt {
        case 1:
            return 400_000_000
        case 2:
            return 1_000_000_000
        default:
            return 1_000_000_000
        }
    }
}
