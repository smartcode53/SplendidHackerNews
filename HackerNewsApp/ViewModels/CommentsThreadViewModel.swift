import Foundation

@MainActor
final class CommentsThreadViewModel: ObservableObject {
    @Published private(set) var topLevelIDs: [Int] = []
    @Published private(set) var matchCount: Int = 0
    @Published var collapsedIDs: Set<Int> = []
    @Published var loadState: LoadState = .idle
    @Published private(set) var visibleRows: [CommentRow] = []

    private var currentQuery: String = ""
    private var visibleIDs: Set<Int> = []
    private var hasActiveSearch = false
    private var indexedComments: [IndexedComment] = []

    /// Cancellable handle for the background pre-parse task.
    private var preParseTask: Task<Void, Never>?

    struct CommentRow: Identifiable {
        let id: Int
        let comment: Comment
        let depth: Int
        let descendantCount: Int
    }

    private struct IndexedComment {
        let id: Int
        let comment: Comment
        let depth: Int
        let ancestorIDs: [Int]
        let lowercasedText: String
        let lowercasedAuthor: String
        let descendantCount: Int
    }

    private struct PreparedComments {
        let indexed: [IndexedComment]
        let topLevelIDs: [Int]
    }

    func setComments(_ comments: [Comment]) async {
        let prepared = await Task.detached(priority: .userInitiated) {
            Self.prepareComments(comments)
        }.value
        applyPreparedComments(prepared)
    }

    func loadComments(using loader: any CommentsButtonProtocol, storyID: Int) async {
        loadState = .loading
        await loader.loadComments(withId: storyID)

        guard let children = loader.comments?.children else {
            let message = ErrorPresenter.message(
                for: nil,
                defaultMessage: "Check your connection and try again.",
                debugTag: "ALGOLIA_COMMENTS"
            )
            loadState = .error(message: message, canRetry: true)
            return
        }

        await setComments(children)

        if children.isEmpty {
            loadState = .empty
        } else {
            loadState = .loaded
            // Pre-parse all comment HTML on a background thread so the
            // AttributedStringCache is warm before the user scrolls.
            // This is fire-and-forget; the view will still work if parsing
            // hasn't finished yet (it just parses on-demand via .markdown).
            preParseTask?.cancel()
            preParseTask = Task.detached(priority: .utility) { [comments = children] in
                Self.preParseCommentTree(comments)
            }
        }
    }

    // MARK: - Background Pre-Parsing

    /// Walks the entire comment tree and pre-parses each comment's HTML
    /// into the AttributedStringCache. Runs on a background thread.
    /// O(n) where n = total number of comments in the tree.
    /// Uses an iterative stack to avoid deep recursion on large threads.
    private nonisolated static func preParseCommentTree(_ roots: [Comment]) {
        let cache = AttributedStringCache.instance

        // Iterative DFS using an explicit stack -- avoids stack overflow
        // on deeply nested comment chains (HN threads can be 50+ levels deep).
        var stack: [Comment] = roots.reversed() // reversed so we process in order
        while let comment = stack.popLast() {
            guard !Task.isCancelled else { return }

            if let html = comment.text, !html.isEmpty {
                // Only parse if not already cached
                if cache.get(forKey: html) == nil {
                    let parsed = CommentHTMLParser.parse(html)
                    cache.set(parsed, forKey: html)
                }
            }

            // Push children in reverse order for in-order traversal
            if !comment.children.isEmpty {
                for child in comment.children.reversed() {
                    stack.append(child)
                }
            }
        }
    }

    func applySearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        currentQuery = trimmed

        guard !trimmed.isEmpty else {
            visibleIDs.removeAll()
            matchCount = 0
            hasActiveSearch = false
            rebuildVisibleRows()
            return
        }

        visibleIDs.removeAll(keepingCapacity: true)
        matchCount = 0
        hasActiveSearch = true
        let lowered = trimmed.lowercased()

        for entry in indexedComments {
            let isMatch = entry.lowercasedText.localizedStandardContains(lowered)
                || entry.lowercasedAuthor.localizedStandardContains(lowered)
            if isMatch {
                matchCount += 1
                visibleIDs.insert(entry.id)
                for ancestorID in entry.ancestorIDs {
                    visibleIDs.insert(ancestorID)
                }
            }
        }
        rebuildVisibleRows()
    }

    func isVisible(_ id: Int) -> Bool {
        if !hasActiveSearch {
            return true
        }
        return visibleIDs.contains(id)
    }

    func isCollapsed(_ id: Int) -> Bool {
        collapsedIDs.contains(id)
    }

    func toggleCollapse(_ id: Int) {
        if collapsedIDs.contains(id) {
            collapsedIDs.remove(id)
        } else {
            collapsedIDs.insert(id)
        }
        rebuildVisibleRows()
    }

    func collapseTopLevel() {
        collapsedIDs.formUnion(topLevelIDs)
        rebuildVisibleRows()
    }

    func expandTopLevel() {
        collapsedIDs.subtract(topLevelIDs)
        rebuildVisibleRows()
    }

    private func applyPreparedComments(_ prepared: PreparedComments) {
        indexedComments = prepared.indexed
        topLevelIDs = prepared.topLevelIDs
        collapsedIDs.removeAll()
        visibleIDs.removeAll(keepingCapacity: true)
        visibleIDs.reserveCapacity(indexedComments.count)
        applySearch(query: currentQuery)
    }

    private func rebuildVisibleRows() {
        guard !indexedComments.isEmpty else {
            visibleRows = []
            return
        }

        var rows: [CommentRow] = []
        rows.reserveCapacity(indexedComments.count)

        for entry in indexedComments {
            if hasActiveSearch && !visibleIDs.contains(entry.id) {
                continue
            }

            if entry.ancestorIDs.contains(where: { collapsedIDs.contains($0) }) {
                continue
            }

            rows.append(
                CommentRow(
                    id: entry.id,
                    comment: entry.comment,
                    depth: entry.depth,
                    descendantCount: entry.descendantCount
                )
            )
        }

        visibleRows = rows
    }

    private nonisolated static func prepareComments(_ roots: [Comment]) -> PreparedComments {
        struct FlatNode {
            let comment: Comment
            let depth: Int
            let ancestorIDs: [Int]
            let childIDs: [Int]
        }

        var flatNodes: [FlatNode] = []
        flatNodes.reserveCapacity(roots.count * 2)

        var stack: [(comment: Comment, depth: Int, ancestors: [Int])] =
            roots.reversed().map { ($0, 0, []) }

        while let frame = stack.popLast() {
            let childIDs = frame.comment.children.map(\.id)
            flatNodes.append(
                FlatNode(
                    comment: frame.comment,
                    depth: frame.depth,
                    ancestorIDs: frame.ancestors,
                    childIDs: childIDs
                )
            )

            let childAncestors = frame.ancestors + [frame.comment.id]
            for child in frame.comment.children.reversed() {
                stack.append((child, frame.depth + 1, childAncestors))
            }
        }

        var descendantCountByID: [Int: Int] = [:]
        descendantCountByID.reserveCapacity(flatNodes.count)
        for node in flatNodes.reversed() {
            let count = node.childIDs.reduce(into: 0) { partial, childID in
                partial += 1 + (descendantCountByID[childID] ?? 0)
            }
            descendantCountByID[node.comment.id] = count
        }

        let indexed = flatNodes.map { node in
            IndexedComment(
                id: node.comment.id,
                comment: node.comment,
                depth: node.depth,
                ancestorIDs: node.ancestorIDs,
                lowercasedText: node.comment.text?.lowercased() ?? "",
                lowercasedAuthor: node.comment.author?.lowercased() ?? "",
                descendantCount: descendantCountByID[node.comment.id] ?? 0
            )
        }

        return PreparedComments(indexed: indexed, topLevelIDs: roots.map(\.id))
    }
}
