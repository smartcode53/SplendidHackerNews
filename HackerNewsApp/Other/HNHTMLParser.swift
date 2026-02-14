import Foundation
import SwiftSoup

enum HNHTMLParser {
    static let loginSelector = ".pagetop a[href^=user?id=]"
    static let loginFormSelector = "form"
    static let replyFormSelector = "form"
    static let commentRowSelector = "tr.athing.comtr"

    static func voteUpSelector(itemId: Int) -> String { "a#up_\(itemId)" }
    static func voteUnSelector(itemId: Int) -> String { "a#un_\(itemId)" }

    enum VoteState {
        case upvoteAvailable(href: String)
        case alreadyVoted
        case unknown
    }

    struct ReplyForm {
        let action: String
        let fields: [String: String]
    }

    struct LoginForm {
        let action: String
        let fields: [String: String]
    }

    static func loggedInUsername(in html: String, pageURL: String) throws -> String? {
        do {
            let doc = try SwiftSoup.parse(html)
            if let userLink = try doc.select(loginSelector).first() {
                let href = try userLink.attr("href")
                if let username = href.split(separator: "=").last {
                    return String(username)
                }
            }
            return nil
        } catch {
            throw HNHTMLParseError(pageURL: pageURL, itemID: nil, selector: loginSelector, underlying: error)
        }
    }

    static func voteState(for itemId: Int, in html: String, pageURL: String) throws -> VoteState {
        do {
            let doc = try SwiftSoup.parse(html)
            if let upvote = try doc.select(voteUpSelector(itemId: itemId)).first() {
                let href = try upvote.attr("href")
                if !href.isEmpty {
                    return .upvoteAvailable(href: href)
                }
            }

            if let unvote = try doc.select(voteUnSelector(itemId: itemId)).first() {
                let href = try unvote.attr("href")
                if !href.isEmpty {
                    return .alreadyVoted
                }
            }

            if let upSpan = try doc.select("span#up_\(itemId)").first() {
                let className = try upSpan.className()
                if className.contains("votedisabled") || className.contains("votearrow") {
                    return .alreadyVoted
                }
            }

            return .unknown
        } catch {
            throw HNHTMLParseError(pageURL: pageURL, itemID: itemId, selector: "\(voteUpSelector(itemId: itemId))/\(voteUnSelector(itemId: itemId))", underlying: error)
        }
    }

    static func replyForm(in html: String, pageURL: String) throws -> ReplyForm {
        do {
            let doc = try SwiftSoup.parse(html)
            guard let form = try doc.select(replyFormSelector).first() else {
                throw HNHTMLParseError(pageURL: pageURL, itemID: nil, selector: replyFormSelector, underlying: nil)
            }

            let action = try form.attr("action")
            if action.isEmpty {
                throw HNHTMLParseError(pageURL: pageURL, itemID: nil, selector: "form[action]", underlying: nil)
            }

            var fields: [String: String] = [:]
            let inputs = try form.select("input[name]")
            for input in inputs.array() {
                let name = try input.attr("name")
                let value = try input.attr("value")
                if !name.isEmpty {
                    fields[name] = value
                }
            }

            return ReplyForm(action: action, fields: fields)
        } catch let parseError as HNHTMLParseError {
            throw parseError
        } catch {
            throw HNHTMLParseError(pageURL: pageURL, itemID: nil, selector: "form input[name]", underlying: error)
        }
    }

    static func loginForm(in html: String, pageURL: String) throws -> LoginForm {
        do {
            let doc = try SwiftSoup.parse(html)
            let forms = try doc.select(loginFormSelector).array()
            let form = forms.first { form in
                let hasAcct = (try? form.select("input[name=acct]").first()) != nil
                let hasPassword = (try? form.select("input[name=pw]").first()) != nil
                return hasAcct && hasPassword
            } ?? forms.first
            guard let form else {
                throw HNHTMLParseError(pageURL: pageURL, itemID: nil, selector: loginFormSelector, underlying: nil)
            }

            let action = try form.attr("action")
            if action.isEmpty {
                throw HNHTMLParseError(pageURL: pageURL, itemID: nil, selector: "form[action]", underlying: nil)
            }

            var fields: [String: String] = [:]
            let inputs = try form.select("input[name]")
            for input in inputs.array() {
                let name = try input.attr("name")
                let value = try input.attr("value")
                if !name.isEmpty {
                    fields[name] = value
                }
            }

            return LoginForm(action: action, fields: fields)
        } catch let parseError as HNHTMLParseError {
            throw parseError
        } catch {
            throw HNHTMLParseError(pageURL: pageURL, itemID: nil, selector: "form input[name]", underlying: error)
        }
    }

    static func firstCommentId(in html: String, pageURL: String) throws -> Int? {
        do {
            let doc = try SwiftSoup.parse(html)
            if let row = try doc.select(commentRowSelector).first() {
                let idValue = try row.attr("id")
                return Int(idValue)
            }
            return nil
        } catch {
            throw HNHTMLParseError(pageURL: pageURL, itemID: nil, selector: commentRowSelector, underlying: error)
        }
    }

    static func containsNonce(_ nonce: String, in html: String) -> Bool {
        html.contains(nonce)
    }

    static func excerpt(for selector: String, in html: String, maxLength: Int = 1800) throws -> String? {
        do {
            let doc = try SwiftSoup.parse(html)
            if let element = try doc.select(selector).first() {
                let snippet = try element.outerHtml()
                return String(snippet.prefix(maxLength))
            }
            return nil
        } catch {
            throw HNHTMLParseError(pageURL: "unknown", itemID: nil, selector: selector, underlying: error)
        }
    }
}

struct HNHTMLParseError: Error, LocalizedError {
    let pageURL: String
    let itemID: Int?
    let selector: String
    let underlying: Error?

    var errorDescription: String? {
        var parts: [String] = ["HTML parse failed", "selector=\(selector)", "page=\(pageURL)"]
        if let itemID {
            parts.append("itemID=\(itemID)")
        }
        if let underlying {
            parts.append("error=\(underlying.localizedDescription)")
        }
        return parts.joined(separator: ", ")
    }
}
