import Foundation

#if DEBUG

@MainActor
final class HNDiagnosticsViewModel: ObservableObject {
    @Published private(set) var report: HNDiagnosticsReport?
    @Published private(set) var isRunning = false
    @Published private(set) var dryRunResult: String?
    @Published var knownStoryIdText: String = ""
    @Published var knownCommentIdText: String = ""

    private let defaults = UserDefaults.standard
    private let storyKey = "hn.debug.knownStoryId"
    private let commentKey = "hn.debug.knownCommentId"

    private let account: HNAccount

    init(account: HNAccount) {
        self.account = account
        loadDefaults()
    }

    func runSelfTest() {
        guard !isRunning else { return }
        isRunning = true
        dryRunResult = nil
        Task {
            let checks = await buildSelfTestChecks()
            report = HNDiagnosticsReport(generatedAt: Date(), checks: checks)
            isRunning = false
        }
    }

    func runDryRunTokens() {
        guard !isRunning else { return }
        isRunning = true
        Task {
            defer { isRunning = false }
            do {
                let storyId = knownStoryId() ?? 8863
                let itemResponse = try await account.fetchHTML(path: "item", queryItems: [URLQueryItem(name: "id", value: String(storyId))])
                if itemResponse.statusCode != 200 {
                    dryRunResult = "Dry run failed: HTTP \(itemResponse.statusCode)"
                    return
                }
                let voteState = try HNHTMLParser.voteState(for: storyId, in: itemResponse.html, pageURL: itemResponse.url.absoluteString)

                let commentId = try await resolveCommentId(itemHTML: itemResponse.html, storyId: storyId)
                let replyResponse = try await account.fetchHTML(path: "reply", queryItems: [URLQueryItem(name: "id", value: String(commentId))])
                if replyResponse.statusCode != 200 {
                    dryRunResult = "Dry run failed: HTTP \(replyResponse.statusCode)"
                    return
                }
                _ = try HNHTMLParser.replyForm(in: replyResponse.html, pageURL: replyResponse.url.absoluteString)

                var lines: [String] = []
                lines.append("Dry Run Tokens")
                lines.append("Story ID: \(storyId)")
                lines.append("Vote State: \(describeVoteState(voteState))")
                lines.append("Reply Form: OK for comment \(commentId)")
                dryRunResult = lines.joined(separator: "\n")
            } catch {
                dryRunResult = "Dry run failed: \(error.localizedDescription)"
                HNDebugLog.error("Dry run failed: \(error)")
            }
        }
    }

    func persistKnownIds() {
        defaults.set(knownStoryIdText, forKey: storyKey)
        defaults.set(knownCommentIdText, forKey: commentKey)
    }

    private func loadDefaults() {
        if let story = defaults.string(forKey: storyKey), !story.isEmpty {
            knownStoryIdText = story
        } else {
            knownStoryIdText = "8863"
        }
        if let comment = defaults.string(forKey: commentKey) {
            knownCommentIdText = comment
        }
    }

    private func knownStoryId() -> Int? {
        Int(knownStoryIdText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func knownCommentId() -> Int? {
        let trimmed = knownCommentIdText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    private func buildSelfTestChecks() async -> [HNDiagnosticsCheck] {
        var checks: [HNDiagnosticsCheck] = []

        do {
            let response = try await account.fetchHTML(path: "news")
            if response.statusCode != 200 {
                checks.append(HNDiagnosticsCheck(
                    name: "Login marker",
                    passed: false,
                    errorCode: .requestFailed,
                    url: response.url.absoluteString,
                    statusCode: response.statusCode,
                    selectors: [],
                    excerpt: excerptFromHTML(response.html, selector: nil),
                    message: "HTTP \(response.statusCode)"
                ))
                return checks
            }
            let selectors = [HNHTMLParser.loginSelector]
            let username = try HNHTMLParser.loggedInUsername(in: response.html, pageURL: response.url.absoluteString)
            let passed = username != nil
            let check = HNDiagnosticsCheck(
                name: "Login marker",
                passed: passed,
                errorCode: passed ? nil : .loginMarkerNotFound,
                url: response.url.absoluteString,
                statusCode: response.statusCode,
                selectors: selectors,
                excerpt: excerptFromHTML(response.html, selector: selectors.first),
                message: passed ? "Logged in as \(username ?? "")" : "No username detected"
            )
            checks.append(check)
        } catch {
            checks.append(failureCheck(name: "Login marker", error: error, defaultCode: .loginMarkerNotFound))
        }

        let storyId = knownStoryId() ?? 8863
        do {
            let response = try await account.fetchHTML(path: "item", queryItems: [URLQueryItem(name: "id", value: String(storyId))])
            if response.statusCode != 200 {
                checks.append(HNDiagnosticsCheck(
                    name: "Vote/Reply selectors",
                    passed: false,
                    errorCode: .requestFailed,
                    url: response.url.absoluteString,
                    statusCode: response.statusCode,
                    selectors: [],
                    excerpt: excerptFromHTML(response.html, selector: nil),
                    message: "HTTP \(response.statusCode)"
                ))
                return checks
            }
            let selectors = [HNHTMLParser.voteUpSelector(itemId: storyId), HNHTMLParser.voteUnSelector(itemId: storyId)]
            let state = try HNHTMLParser.voteState(for: storyId, in: response.html, pageURL: response.url.absoluteString)
            let passed: Bool
            switch state {
            case .upvoteAvailable, .alreadyVoted:
                passed = true
            case .unknown:
                passed = false
            }
            let check = HNDiagnosticsCheck(
                name: "Vote link for story \(storyId)",
                passed: passed,
                errorCode: passed ? nil : .voteLinkNotFound,
                url: response.url.absoluteString,
                statusCode: response.statusCode,
                selectors: selectors,
                excerpt: excerptFromHTML(response.html, selector: selectors.first),
                message: passed ? "Vote state: \(describeVoteState(state))" : "Vote state unknown"
            )
            checks.append(check)

            do {
                let commentId = try await resolveCommentId(itemHTML: response.html, storyId: storyId)
                do {
                    let replyResponse = try await account.fetchHTML(path: "reply", queryItems: [URLQueryItem(name: "id", value: String(commentId))])
                    if replyResponse.statusCode != 200 {
                        checks.append(HNDiagnosticsCheck(
                            name: "Reply form (comment \(commentId))",
                            passed: false,
                            errorCode: .requestFailed,
                            url: replyResponse.url.absoluteString,
                            statusCode: replyResponse.statusCode,
                            selectors: [],
                            excerpt: excerptFromHTML(replyResponse.html, selector: nil),
                            message: "HTTP \(replyResponse.statusCode)"
                        ))
                        return checks
                    }
                    let selectors = [HNHTMLParser.replyFormSelector]
                    _ = try HNHTMLParser.replyForm(in: replyResponse.html, pageURL: replyResponse.url.absoluteString)
                    let replyCheck = HNDiagnosticsCheck(
                        name: "Reply form (comment \(commentId))",
                        passed: true,
                        errorCode: nil,
                        url: replyResponse.url.absoluteString,
                        statusCode: replyResponse.statusCode,
                        selectors: selectors,
                        excerpt: excerptFromHTML(replyResponse.html, selector: selectors.first),
                        message: "Reply form parsed"
                    )
                    checks.append(replyCheck)
                } catch {
                    checks.append(failureCheck(name: "Reply form (comment \(commentId))", error: error, defaultCode: .replyFormNotFound))
                }
            } catch {
                checks.append(failureCheck(name: "Comment ID", error: error, defaultCode: .commentIdNotFound))
            }
        } catch {
            checks.append(failureCheck(name: "Vote/Reply selectors", error: error, defaultCode: .voteLinkNotFound))
        }

        return checks
    }

    private func resolveCommentId(itemHTML: String, storyId: Int) async throws -> Int {
        if let manual = knownCommentId() {
            return manual
        }
        if let first = try HNHTMLParser.firstCommentId(in: itemHTML, pageURL: "https://news.ycombinator.com/item?id=\(storyId)") {
            return first
        }
        throw HNDiagnosticsFailure(
            code: .commentIdNotFound,
            message: "No comment ID found",
            url: "https://news.ycombinator.com/item?id=\(storyId)",
            selectors: [HNHTMLParser.commentRowSelector],
            excerpt: excerptFromHTML(itemHTML, selector: HNHTMLParser.commentRowSelector)
        )
    }

    private func failureCheck(name: String, error: Error, defaultCode: HNDiagnosticsErrorCode) -> HNDiagnosticsCheck {
        if let failure = error as? HNDiagnosticsFailure {
            return HNDiagnosticsCheck(
                name: name,
                passed: false,
                errorCode: failure.code,
                url: failure.url ?? "",
                statusCode: failure.statusCode,
                selectors: failure.selectors,
                excerpt: failure.excerpt,
                message: failure.message
            )
        }

        if let parseError = error as? HNHTMLParseError {
            return HNDiagnosticsCheck(
                name: name,
                passed: false,
                errorCode: defaultCode,
                url: parseError.pageURL,
                statusCode: nil,
                selectors: [parseError.selector],
                excerpt: nil,
                message: parseError.errorDescription
            )
        }

        return HNDiagnosticsCheck(
            name: name,
            passed: false,
            errorCode: defaultCode,
            url: "",
            statusCode: nil,
            selectors: [],
            excerpt: nil,
            message: error.localizedDescription
        )
    }

    private func excerptFromHTML(_ html: String, selector: String?) -> String? {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxLength = 1800
        guard !trimmed.isEmpty else { return nil }

        if let selector, let snippet = try? HNHTMLParser.excerpt(for: selector, in: html) {
            return snippet
        }

        return String(trimmed.prefix(maxLength))
    }

    private func describeVoteState(_ state: HNHTMLParser.VoteState) -> String {
        switch state {
        case .upvoteAvailable:
            return "Upvote available"
        case .alreadyVoted:
            return "Already voted"
        case .unknown:
            return "Unknown"
        }
    }
}

struct HNDiagnosticsFailure: Error {
    let code: HNDiagnosticsErrorCode
    let message: String
    let url: String?
    let statusCode: Int?
    let selectors: [String]
    let excerpt: String?

    init(code: HNDiagnosticsErrorCode, message: String, url: String? = nil, statusCode: Int? = nil, selectors: [String] = [], excerpt: String? = nil) {
        self.code = code
        self.message = message
        self.url = url
        self.statusCode = statusCode
        self.selectors = selectors
        self.excerpt = excerpt
    }
}

#endif
