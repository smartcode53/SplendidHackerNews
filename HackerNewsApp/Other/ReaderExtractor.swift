import Foundation
import SwiftSoup

enum ReaderBlock: Hashable {
    case heading(String, level: Int)
    case paragraph([ReaderSpan])
    case code(String)
    case quote(String)

    var text: String {
        switch self {
        case .heading(let text, _):
            return text
        case .paragraph(let spans):
            return spans.map { $0.text }.joined()
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
            return .paragraph([.text(text)])
        case .code:
            return .code(text)
        case .quote:
            return .quote(text)
        }
    }

    func truncated(to length: Int) -> ReaderBlock? {
        guard length > 0 else { return nil }
        switch self {
        case .paragraph(let spans):
            let truncatedSpans = ReaderBlock.truncatedSpans(spans, to: length)
            return truncatedSpans.isEmpty ? nil : .paragraph(truncatedSpans)
        default:
            let clipped = String(text.prefix(length))
            return clipped.isEmpty ? nil : withText(clipped)
        }
    }

    private static func truncatedSpans(_ spans: [ReaderSpan], to length: Int) -> [ReaderSpan] {
        var remaining = length
        var result: [ReaderSpan] = []
        for span in spans {
            guard remaining > 0 else { break }
            let spanText = span.text
            if spanText.count <= remaining {
                result.append(span)
                remaining -= spanText.count
            } else {
                let prefix = String(spanText.prefix(remaining))
                switch span {
                case .text:
                    result.append(.text(prefix))
                case .link(_, let url):
                    result.append(.link(text: prefix, url: url))
                }
                remaining = 0
            }
        }
        return ReaderBlock.mergeAdjacentTextSpans(result)
    }

    private static func mergeAdjacentTextSpans(_ spans: [ReaderSpan]) -> [ReaderSpan] {
        var merged: [ReaderSpan] = []
        for span in spans {
            switch span {
            case .text(let text):
                guard !text.isEmpty else { continue }
                if case .text(let existing) = merged.last {
                    merged[merged.count - 1] = .text(existing + text)
                } else {
                    merged.append(span)
                }
            case .link:
                merged.append(span)
            }
        }
        return merged
    }
}

enum ReaderSpan: Hashable {
    case text(String)
    case link(text: String, url: URL)

    var text: String {
        switch self {
        case .text(let value):
            return value
        case .link(let value, _):
            return value
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

        var rawBlocks: [ReaderBlock] = []
        collectBlocks(from: contentElement, baseURL: url, into: &rawBlocks)

        let blocks = rawBlocks.filter { !isMetadataBlock($0) }

        var totalCount = 0
        var truncated = false
        var trimmedBlocks: [ReaderBlock] = []
        for block in blocks {
            if totalCount >= maxCharacters { break }
            let text = block.text
            if text.isEmpty { continue }
            let remaining = maxCharacters - totalCount
            if text.count > remaining {
                if let clipped = block.truncated(to: remaining) {
                    trimmedBlocks.append(clipped)
                    totalCount += clipped.text.count
                }
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
            "table.infobox", "table.sidebar", "table.metadata", "table.navbox",
            "table.wikitable.collapsible", ".infobox", ".sidebar", ".navbox",
            ".metadata", ".reflist", ".references", ".mw-references-wrap",
            ".advertisement", ".promo", ".cookie", ".banner", ".subscribe",
            ".newsletter", ".share", ".social", ".related", ".recommended",
            ".comment", ".comments", ".disqus", ".author-bio", ".byline-share",
            ".site-footer", ".site-header", ".nav-wrapper", ".breadcrumb",
            "[role=navigation]", "[role=banner]", "[role=complementary]",
            "[aria-hidden=true]", ".visually-hidden", ".sr-only",
            ".popup", ".modal", ".overlay", ".ad", ".ads", "[id*=ad-]",
            "[class*=ad-wrap]", "[class*=sponsor]"
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

    private func collectBlocks(from node: Node, baseURL: URL, into blocks: inout [ReaderBlock]) {
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
                let spans = inlineSpans(from: element, baseURL: baseURL)
                if !spans.isEmpty {
                    blocks.append(.paragraph(spans))
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
                var spans = inlineSpans(from: element, baseURL: baseURL)
                if !spans.isEmpty {
                    spans.insert(.text("• "), at: 0)
                    blocks.append(.paragraph(spans))
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
            collectBlocks(from: child, baseURL: baseURL, into: &blocks)
            if blocks.count >= maxBlocks {
                break
            }
        }
    }

    private func isMetadataBlock(_ block: ReaderBlock) -> Bool {
        let text = block.text
        // Filter Wikipedia-style template/infobox metadata
        // e.g. "last = Deck | first = Andrew | work = ..."
        let pipeCount = text.filter { $0 == "|" }.count
        let equalsCount = text.filter { $0 == "=" }.count
        if pipeCount >= 3 && equalsCount >= 2 && text.count < 500 {
            return true
        }
        // Filter lines that are mostly metadata keys
        if text.hasPrefix("{") && text.hasSuffix("}") {
            return true
        }
        return false
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

    private func inlineSpans(from element: Element, baseURL: URL) -> [ReaderSpan] {
        var spans: [ReaderSpan] = []
        for child in element.getChildNodes() {
            if let textNode = child as? TextNode {
                let text = normalizedInlineText(textNode.text(), trim: false)
                if !text.isEmpty {
                    spans.append(.text(text))
                }
                continue
            }

            guard let childElement = child as? Element else { continue }
            let tag = childElement.tagName().lowercased()
            if tag == "a" {
                let text = normalizedInlineText((try? childElement.text()) ?? "", trim: true)
                let href = (try? childElement.attr("href"))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if text.isEmpty {
                    continue
                }
                if let url = resolvedLinkURL(href: href, baseURL: baseURL),
                   isSupportedLink(url) {
                    spans.append(.link(text: text, url: url))
                } else {
                    spans.append(.text(text))
                }
            } else {
                spans.append(contentsOf: inlineSpans(from: childElement, baseURL: baseURL))
            }
        }
        return normalizedSpans(spans)
    }

    private func resolvedLinkURL(href: String, baseURL: URL) -> URL? {
        guard !href.isEmpty else { return nil }
        if let url = URL(string: href, relativeTo: baseURL) {
            return url.absoluteURL
        }
        return nil
    }

    private func isSupportedLink(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    private func normalizedInlineText(_ text: String, trim: Bool) -> String {
        let normalized = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        if trim {
            return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return normalized
    }

    private func normalizedSpans(_ spans: [ReaderSpan]) -> [ReaderSpan] {
        var cleaned: [ReaderSpan] = []
        for span in spans {
            switch span {
            case .text(let text):
                if text.isEmpty { continue }
                if case .text(let existing) = cleaned.last {
                    cleaned[cleaned.count - 1] = .text(existing + text)
                } else {
                    cleaned.append(span)
                }
            case .link:
                cleaned.append(span)
            }
        }

        guard !cleaned.isEmpty else { return [] }

        if let first = trimmedSpan(cleaned.first, leading: true, trailing: false) {
            cleaned[0] = first
        } else {
            cleaned.removeFirst()
        }

        if let lastIndex = cleaned.indices.last {
            if let last = trimmedSpan(cleaned[lastIndex], leading: false, trailing: true) {
                cleaned[lastIndex] = last
            } else {
                cleaned.removeLast()
            }
        }

        return cleaned
    }

    private func trimmedSpan(_ span: ReaderSpan?, leading: Bool, trailing: Bool) -> ReaderSpan? {
        guard let span else { return nil }
        var text = span.text
        if leading {
            text = text.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
        }
        if trailing {
            text = text.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
        }
        guard !text.isEmpty else { return nil }
        switch span {
        case .text:
            return .text(text)
        case .link(_, let url):
            return .link(text: text, url: url)
        }
    }
}
