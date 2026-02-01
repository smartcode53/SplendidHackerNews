import Foundation

@MainActor
final class HNAccount: ObservableObject {
    @Published private(set) var isLoggedIn = false
    @Published private(set) var username: String?
    @Published private(set) var lastVerifiedAt: Date?
    @Published private(set) var lastVerifyStatus: String?
    @Published var lastError: String?

    let cookieStorage: HTTPCookieStorage
    let session: URLSession
    private let writeClient: HNWriteClient

    private let cookiesKey = "hn.cookies"
    private let usernameKey = "hn.username"
    private let lastVerifiedKey = "hn.lastVerified"

    init() {
        let storage = HTTPCookieStorage()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = storage
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        self.cookieStorage = storage
        self.session = URLSession(configuration: configuration)
        self.writeClient = HNWriteClient(session: session)

        loadSessionFromKeychain()
    }

    struct HNFetchResponse {
        let html: String
        let statusCode: Int
        let url: URL
    }

    func fetchHTML(path: String, queryItems: [URLQueryItem] = []) async throws -> HNFetchResponse {
        let (data, response) = try await writeClient.get(path: path, queryItems: queryItems)
        let html = String(decoding: data, as: UTF8.self)
        return HNFetchResponse(html: html, statusCode: response.statusCode, url: response.url ?? writeClient.baseURL)
    }

    func handleLoginCookies(_ cookies: [HTTPCookie]) {
        let filtered = cookies.filter { isAllowedCookie($0) }
        HNDebugLog.log("Handling \(filtered.count) cookies from login")
        persistCookies(filtered)
        Task { _ = await verifySession() }
    }

    func verifySession() async -> HNVerifySessionResult {
        lastError = nil
        do {
            let result = try await verifySessionInternal()
            applyVerifyResult(result)
            return result
        } catch {
            let result = HNVerifySessionResult(isLoggedIn: false, username: nil, reason: .requestFailed(error.localizedDescription))
            applyVerifyResult(result)
            self.lastError = error.localizedDescription
            HNDebugLog.error("Verify session failed: \(error)")
            return result
        }
    }

    func signOut() {
        lastError = nil
        isLoggedIn = false
        username = nil
        lastVerifiedAt = nil
        lastVerifyStatus = nil
        cookieStorage.cookies?.forEach { cookieStorage.deleteCookie($0) }
        do {
            try HNKeychainStore.delete(account: cookiesKey)
            try HNKeychainStore.delete(account: usernameKey)
            try HNKeychainStore.delete(account: lastVerifiedKey)
        } catch {
            HNDebugLog.error("Failed to clear keychain: \(error)")
        }
    }

    func upvoteStory(id: Int) async throws -> HNVoteVerificationResult {
        try await upvote(itemId: id, kind: "story")
    }

    func upvoteComment(id: Int) async throws -> HNVoteVerificationResult {
        try await upvote(itemId: id, kind: "comment")
    }

    func reply(to commentId: Int, storyId: Int?, text: String, nonce: String?) async throws -> HNReplyVerificationResult {
        guard isLoggedIn else { throw HNWriteError.notLoggedIn }
        let (data, response) = try await writeClient.get(path: "reply", queryItems: [URLQueryItem(name: "id", value: String(commentId))])
        guard response.statusCode == 200 else {
            throw HNWriteError.serverError(status: response.statusCode)
        }
        let html = String(decoding: data, as: UTF8.self)
        let form = try HNHTMLParser.replyForm(in: html, pageURL: "https://news.ycombinator.com/reply?id=\(commentId)")
        let actionPath = form.action.hasPrefix("/") ? String(form.action.dropFirst()) : form.action
        var fields = form.fields
        fields["text"] = text

        let (postData, postResponse) = try await writeClient.post(path: actionPath, body: fields)
        guard postResponse.statusCode == 200 else {
            throw HNWriteError.serverError(status: postResponse.statusCode)
        }
        let postHtml = String(decoding: postData, as: UTF8.self)
        if postHtml.contains("error") {
            throw HNWriteError.writeFailed(reason: "Reply returned error")
        }

        guard let storyId else {
            return .verificationFailed
        }
        return try await verifyReply(storyId: storyId, nonce: nonce)
    }

    private func upvote(itemId: Int, kind: String) async throws -> HNVoteVerificationResult {
        guard isLoggedIn else { throw HNWriteError.notLoggedIn }
        let (data, response) = try await writeClient.get(path: "item", queryItems: [URLQueryItem(name: "id", value: String(itemId))])
        guard response.statusCode == 200 else {
            throw HNWriteError.serverError(status: response.statusCode)
        }
        let html = String(decoding: data, as: UTF8.self)
        let state = try HNHTMLParser.voteState(for: itemId, in: html, pageURL: "https://news.ycombinator.com/item?id=\(itemId)")

        switch state {
        case .alreadyVoted:
            HNDebugLog.log("Already voted for \(kind) \(itemId)")
            return .alreadyVoted
        case .upvoteAvailable(let href):
            let sanitized = href.hasPrefix("/") ? String(href.dropFirst()) : href
            let (_, voteResponse) = try await writeClient.get(path: sanitized)
            guard voteResponse.statusCode == 200 else {
                throw HNWriteError.serverError(status: voteResponse.statusCode)
            }
            return try await verifyVote(itemId: itemId)
        case .unknown:
            HNDebugLog.log("Vote state unknown for \(kind) \(itemId)")
            throw HNWriteError.tokenParseFailed(context: "vote state unknown")
        }
    }

    private func persistCookies(_ cookies: [HTTPCookie]) {
        cookies.forEach { cookieStorage.setCookie($0) }
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: false)
            try HNKeychainStore.set(data: data, account: cookiesKey)
        } catch {
            HNDebugLog.error("Failed to persist cookies: \(error)")
        }
    }

    private func persistUsername(_ username: String) {
        guard let data = username.data(using: .utf8) else { return }
        do {
            try HNKeychainStore.set(data: data, account: usernameKey)
        } catch {
            HNDebugLog.error("Failed to persist username: \(error)")
        }
    }

    private func persistLastVerified(_ date: Date) {
        let interval = String(date.timeIntervalSince1970)
        guard let data = interval.data(using: .utf8) else { return }
        do {
            try HNKeychainStore.set(data: data, account: lastVerifiedKey)
        } catch {
            HNDebugLog.error("Failed to persist last verified: \(error)")
        }
    }

    private func loadSessionFromKeychain() {
        do {
            if let data = try HNKeychainStore.get(account: cookiesKey),
               let cookies = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [HTTPCookie] {
                cookies.filter { isAllowedCookie($0) }.forEach { cookieStorage.setCookie($0) }
            }

            if let data = try HNKeychainStore.get(account: usernameKey),
               let username = String(data: data, encoding: .utf8) {
                self.username = username
                self.isLoggedIn = true
            }

            if let data = try HNKeychainStore.get(account: lastVerifiedKey),
               let intervalString = String(data: data, encoding: .utf8),
               let interval = TimeInterval(intervalString) {
                self.lastVerifiedAt = Date(timeIntervalSince1970: interval)
            }
        } catch {
            HNDebugLog.error("Failed to load session: \(error)")
        }
    }

    private func verifySessionInternal() async throws -> HNVerifySessionResult {
        if let username = username, !username.isEmpty {
            let (data, response) = try await writeClient.get(path: "user", queryItems: [URLQueryItem(name: "id", value: username)])
            guard response.statusCode == 200 else {
                return HNVerifySessionResult(isLoggedIn: false, username: nil, reason: .serverError(response.statusCode))
            }
            let html = String(decoding: data, as: UTF8.self)
            let parsedUsername = try HNHTMLParser.loggedInUsername(in: html, pageURL: "https://news.ycombinator.com/user?id=\(username)")
            if let parsedUsername, parsedUsername == username {
                return HNVerifySessionResult(isLoggedIn: true, username: parsedUsername, reason: .verified)
            }
        }

        let (data, response) = try await writeClient.get(path: "login")
        guard response.statusCode == 200 else {
            return HNVerifySessionResult(isLoggedIn: false, username: nil, reason: .serverError(response.statusCode))
        }
        let html = String(decoding: data, as: UTF8.self)
        let parsedUsername = try HNHTMLParser.loggedInUsername(in: html, pageURL: "https://news.ycombinator.com/login")
        if let parsedUsername {
            return HNVerifySessionResult(isLoggedIn: true, username: parsedUsername, reason: .verified)
        }

        return HNVerifySessionResult(isLoggedIn: false, username: nil, reason: .noUserMarker)
    }

    private func applyVerifyResult(_ result: HNVerifySessionResult) {
        isLoggedIn = result.isLoggedIn
        username = result.username
        lastVerifiedAt = Date()
        lastVerifyStatus = result.displayStatus
        if let username = result.username {
            persistUsername(username)
        }
        persistLastVerified(Date())
    }

    private func verifyVote(itemId: Int) async throws -> HNVoteVerificationResult {
        let (data, response) = try await writeClient.get(path: "item", queryItems: [URLQueryItem(name: "id", value: String(itemId))])
        guard response.statusCode == 200 else {
            return .verificationFailed
        }
        let html = String(decoding: data, as: UTF8.self)
        let state = try HNHTMLParser.voteState(for: itemId, in: html, pageURL: "https://news.ycombinator.com/item?id=\(itemId)")
        switch state {
        case .alreadyVoted:
            return .voted
        case .upvoteAvailable:
            return .verificationFailed
        case .unknown:
            return .verificationFailed
        }
    }

    private func verifyReply(storyId: Int, nonce: String?) async throws -> HNReplyVerificationResult {
        guard let nonce else { return .verificationFailed }
        let (data, response) = try await writeClient.get(path: "item", queryItems: [URLQueryItem(name: "id", value: String(storyId))])
        guard response.statusCode == 200 else {
            return .verificationFailed
        }
        let html = String(decoding: data, as: UTF8.self)
        return HNHTMLParser.containsNonce(nonce, in: html) ? .posted : .verificationFailed
    }

    private func isAllowedCookie(_ cookie: HTTPCookie) -> Bool {
        let domain = cookie.domain.lowercased()
        return domain == "news.ycombinator.com"
        || domain.hasSuffix(".news.ycombinator.com")
        || domain == "ycombinator.com"
        || domain.hasSuffix(".ycombinator.com")
    }
}

enum HNVerifyFailureReason {
    case verified
    case noUserMarker
    case serverError(Int)
    case requestFailed(String)
}

struct HNVerifySessionResult {
    let isLoggedIn: Bool
    let username: String?
    let reason: HNVerifyFailureReason

    var displayStatus: String {
        if isLoggedIn, let username {
            return "Logged in as \(username)"
        }
        switch reason {
        case .verified:
            return "Logged in"
        case .noUserMarker:
            return "Not logged in"
        case .serverError(let status):
            return "Server error \(status)"
        case .requestFailed(let message):
            return "Verify failed: \(message)"
        }
    }
}

enum HNVoteVerificationResult {
    case voted
    case alreadyVoted
    case verificationFailed
}

enum HNReplyVerificationResult {
    case posted
    case verificationFailed
}
