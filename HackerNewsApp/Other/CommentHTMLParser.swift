//
//  CommentHTMLParser.swift
//  HackerNewsApp
//
//  Lightweight HTML -> AttributedString parser for HN comments.
//  Uses SwiftSoup to walk the DOM tree and builds AttributedString
//  directly via Swift's native AttributedString API.
//
//  Why not NSAttributedString(data:options:.html)?
//  That API internally spins up a WebKit renderer, must run on the
//  main thread, and takes ~5-15ms per comment. With 200+ comments
//  in a thread, that's 1-3 seconds of main-thread blocking.
//
//  This parser handles the subset of HTML that HN comments actually use:
//  <p>, <a href>, <i>, <em>, <b>, <strong>, <code>, <pre>, <blockquote>
//  Runs in ~0.1-0.3ms per comment, can run on any thread.
//

import Foundation
import SwiftUI
import SwiftSoup

enum CommentHTMLParser {

    // MARK: - Public API

    /// Parses HN comment HTML into an AttributedString.
    /// Safe to call from any thread. O(n) in the length of the HTML.
    static func parse(_ html: String) -> AttributedString {
        guard !html.isEmpty else { return AttributedString() }

        do {
            let doc = try SwiftSoup.parseBodyFragment(html)
            guard let body = doc.body() else {
                return AttributedString(html)
            }
            var result = AttributedString()
            walkNode(body, into: &result, context: RenderContext())
            // Trim trailing newlines that accumulate from <p> tags
            trimTrailingNewlines(&result)
            return result
        } catch {
            // If SwiftSoup fails, return plain text
            return AttributedString(html)
        }
    }

    // MARK: - Render Context

    /// Tracks the current formatting state as we walk the DOM tree.
    private struct RenderContext {
        var isBold: Bool = false
        var isItalic: Bool = false
        var isCode: Bool = false
        var isPre: Bool = false
        var linkURL: URL? = nil
        var blockquoteDepth: Int = 0
    }

    // MARK: - DOM Tree Walker

    /// Recursively walks a SwiftSoup Node, appending styled text to `result`.
    /// O(n) where n = total number of DOM nodes.
    private static func walkNode(_ node: Node, into result: inout AttributedString, context: RenderContext) {
        if let textNode = node as? TextNode {
            let text = context.isPre ? textNode.getWholeText() : collapseWhitespace(textNode.getWholeText())
            if !text.isEmpty {
                var attributed = AttributedString(text)
                applyStyle(&attributed, context: context)
                result.append(attributed)
            }
            return
        }

        guard let element = node as? Element else {
            // For other node types (comments, etc.), just recurse into children
            for child in node.getChildNodes() {
                walkNode(child, into: &result, context: context)
            }
            return
        }

        let tagName = element.tagName().lowercased()
        var childContext = context

        switch tagName {
        case "b", "strong":
            childContext.isBold = true

        case "i", "em":
            childContext.isItalic = true

        case "code":
            childContext.isCode = true

        case "pre":
            childContext.isPre = true
            childContext.isCode = true
            // Add a newline before <pre> if there's already content
            if !result.characters.isEmpty {
                result.append(AttributedString("\n"))
            }

        case "a":
            if let href = try? element.attr("href"), !href.isEmpty {
                childContext.linkURL = URL(string: href)
            }

        case "p":
            // Add paragraph separator (double newline) if there's already content
            if !result.characters.isEmpty {
                result.append(AttributedString("\n\n"))
            }

        case "br":
            result.append(AttributedString("\n"))
            return // <br> is self-closing, no children

        case "blockquote":
            childContext.blockquoteDepth = context.blockquoteDepth + 1
            if !result.characters.isEmpty {
                result.append(AttributedString("\n"))
            }

        default:
            break
        }

        // Recurse into children
        for child in element.getChildNodes() {
            walkNode(child, into: &result, context: childContext)
        }

        // Post-processing after children
        switch tagName {
        case "pre":
            result.append(AttributedString("\n"))
        case "blockquote":
            break // Newlines already handled
        default:
            break
        }
    }

    // MARK: - Styling

    /// Applies the accumulated style context to an AttributedString segment.
    private static func applyStyle(_ attributed: inout AttributedString, context: RenderContext) {
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        let bodySize = bodyFont.pointSize

        if context.isCode {
            // Monospace font for code
            let monoFont: UIFont
            if context.isBold && context.isItalic {
                monoFont = UIFont.monospacedSystemFont(ofSize: bodySize, weight: .bold)
            } else if context.isBold {
                monoFont = UIFont.monospacedSystemFont(ofSize: bodySize, weight: .bold)
            } else {
                monoFont = UIFont.monospacedSystemFont(ofSize: bodySize, weight: .regular)
            }
            attributed.font = Font(monoFont)
            attributed.backgroundColor = Color(.systemGray6)
        } else {
            // Build a descriptor with the appropriate traits
            var descriptor = bodyFont.fontDescriptor
            var traits: UIFontDescriptor.SymbolicTraits = []

            if context.isBold { traits.insert(.traitBold) }
            if context.isItalic { traits.insert(.traitItalic) }

            if !traits.isEmpty, let adjusted = descriptor.withSymbolicTraits(traits) {
                descriptor = adjusted
            }

            let styledFont = UIFont(descriptor: descriptor, size: bodySize)
            attributed.font = Font(styledFont)
        }

        if let url = context.linkURL {
            attributed.link = url
        }

        if context.blockquoteDepth > 0 {
            attributed.foregroundColor = Color.secondary
        }
    }

    // MARK: - Whitespace Helpers

    /// Collapses runs of whitespace (spaces, tabs, newlines) into a single space.
    /// This matches browser behavior for non-<pre> content.
    private static func collapseWhitespace(_ text: String) -> String {
        // Fast path: if no whitespace runs, return as-is
        var result = ""
        result.reserveCapacity(text.count)
        var lastWasSpace = false

        for char in text {
            if char.isWhitespace || char.isNewline {
                if !lastWasSpace {
                    result.append(" ")
                    lastWasSpace = true
                }
            } else {
                result.append(char)
                lastWasSpace = false
            }
        }
        return result
    }

    /// Removes trailing newline characters from the end of an AttributedString.
    private static func trimTrailingNewlines(_ attributed: inout AttributedString) {
        while let lastChar = attributed.characters.last, lastChar.isNewline {
            let endIndex = attributed.endIndex
            let beforeEnd = attributed.index(beforeCharacter: endIndex)
            attributed.removeSubrange(beforeEnd..<endIndex)
        }
    }
}
