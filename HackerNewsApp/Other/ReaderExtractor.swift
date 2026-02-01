import Foundation
import SwiftSoup

enum ReaderBlock: Hashable {
    case heading(String, level: Int)
    case paragraph(String)
    case code(String)
    case quote(String)

    var text: String {
        switch self {
        case .heading(let text, _):
            return text
        case .paragraph(let text):
            return text
        case .code(let text):
            return text
        case .quote(let text):
            return text
        }
    }

    func withText(_ text: String) -> ReaderBlock {
        switch self {
        case .heading(_, let level):
            return .heading(text, level: level)
        case .paragraph:
            return .paragraph(text)
        case .code:
            return .code(text)
        case .quote:
            return .quote(text)
        }
    }
}

struct ReaderExtractionResult {
    let blocks: [ReaderBlock]
    let isTruncated: Bool
    let characterCount: Int
}

enum ReaderExtractorError: LocalizedError {
    case invalidHTML
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .invalidHTML:
            return "Couldn't read the article content."
        case .emptyContent:
            return "Couldn't extract readable text."
        }
    }
}

final class ReaderExtractor {
    private let timeout: TimeInterval = 12
    private let maxCharacters = 32000
    private let minCharacters = 200
    private let maxBlocks = 250

    func extract(from url: URL) async throws -> ReaderExtractionResult {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout

        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        guard let html, !html.isEmpty else {
            throw ReaderExtractorError.invalidHTML
        }

        let doc = try SwiftSoup.parse(html)
        try removeNonContent(from: doc)

        let contentElement = try selectContentElement(from: doc)
        guard let contentElement else {
            throw ReaderExtractorError.emptyContent
        }

        var blocks: [ReaderBlock] = []
        collectBlocks(from: contentElement, into: &blocks)

        var totalCount = 0
        var truncated = false
        var trimmedBlocks: [ReaderBlock] = []
        for block in blocks {
            if totalCount >= maxCharacters { break }
            let text = block.text
            if text.isEmpty { continue }
            let remaining = maxCharacters - totalCount
            if text.count > remaining {
                let clipped = String(text.prefix(remaining))
                trimmedBlocks.append(block.withText(clipped))
                totalCount += clipped.count
                truncated = true
                break
            } else {
                trimmedBlocks.append(block)
                totalCount += text.count
            }
        }

        if totalCount < minCharacters {
            throw ReaderExtractorError.emptyContent
        }

        if blocks.count > trimmedBlocks.count {
            truncated = true
        }

        return ReaderExtractionResult(blocks: trimmedBlocks, isTruncated: truncated, characterCount: totalCount)
    }

    private func removeNonContent(from doc: Document) throws {
        let selectors = [
            "script", "style", "nav", "header", "footer", "aside", "form",
            "noscript", "iframe", "svg", "canvas", "figure", "figcaption",
            ".advertisement", ".promo", ".cookie", ".banner", ".subscribe", ".newsletter", ".share"
        ]
        try doc.select(selectors.joined(separator: ", ")).remove()
    }

    private func selectContentElement(from doc: Document) throws -> Element? {
        if let article = try doc.select("article").first() {
            return article
        }

        let candidates = try doc.select("main, [itemprop=articleBody], div[id*=content], div[class*=content], div[id*=article], div[class*=article], section[id*=content], section[class*=content]")
        if candidates.size() > 0 {
            var best: Element?
            var bestLength = 0
            for candidate in candidates.array() {
                let text = try candidate.text()
                if text.count > bestLength {
                    bestLength = text.count
                    best = candidate
                }
            }
            if let best, bestLength >= minCharacters {
                return best
            }
        }

        return doc.body()
    }

    private func collectBlocks(from node: Node, into blocks: inout [ReaderBlock]) {
        guard blocks.count < maxBlocks else { return }

        if let element = node as? Element {
            let tag = element.tagName().lowercased()
            switch tag {
            case "h1", "h2", "h3", "h4", "h5", "h6":
                if let level = Int(tag.dropFirst()) {
                    let text = normalizedText(from: element)
                    if !text.isEmpty {
                        blocks.append(.heading(text, level: level))
                    }
                }
                return
            case "p":
                let text = normalizedText(from: element)
                if !text.isEmpty {
                    blocks.append(.paragraph(text))
                }
                return
            case "pre":
                let text = codeText(from: element)
                if !text.isEmpty {
                    blocks.append(.code(text))
                }
                return
            case "blockquote":
                let text = normalizedText(from: element)
                if !text.isEmpty {
                    blocks.append(.quote(text))
                }
                return
            case "li":
                let text = normalizedText(from: element)
                if !text.isEmpty {
                    blocks.append(.paragraph("• \(text)"))
                }
                return
            case "code":
                if let parent = element.parent(), parent.tagName().lowercased() == "pre" {
                    return
                }
                let text = codeText(from: element)
                if !text.isEmpty {
                    blocks.append(.code(text))
                }
                return
            default:
                break
            }
        }

        for child in node.getChildNodes() {
            collectBlocks(from: child, into: &blocks)
            if blocks.count >= maxBlocks {
                break
            }
        }
    }

    private func normalizedText(from element: Element) -> String {
        let raw = (try? element.text()) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let normalized = trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func codeText(from element: Element) -> String {
        let raw = (try? element.text()) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
    }
}
