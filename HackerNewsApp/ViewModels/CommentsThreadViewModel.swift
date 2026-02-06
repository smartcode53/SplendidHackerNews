import Foundation

@MainActor
final class CommentsThreadViewModel: ObservableObject {
    @Published private(set) var topLevelIDs: [Int] = []
    @Published private(set) var visibleTopLevelIDs: [Int] = []
    @Published private(set) var matchCount: Int = 0
    @Published var collapsedIDs: Set<Int> = []
    @Published var loadState: LoadState = .idle

    private var visibleIDs: Set<Int> = []
    private var currentQuery: String = ""
    private var comments: [Comment] = []

    /// Cancellable handle for the background pre-parse task.
    private var preParseTask: Task<Void, Never>?

    // MARK: - Flat Search Index
    // Pre-computed on setComments. Avoids re-lowercasing on every keystroke
    // and allows O(1) lookup by comment ID instead of recursive tree traversal.

    /// Pre-lowercased text and author for each comment, plus parent chain for
    /// propagating visibility up the tree. Built once in O(n), reused per query.
    private struct SearchEntry {
        let id: Int
        let lowercasedText: String   // comment.text?.lowercased() ?? ""
        let lowercasedAuthor: String  // comment.author?.lowercased() ?? ""
        let ancestorIDs: [Int]        // chain of parent IDs up to root (for visibility propagation)
        let childIDs: [Int]           // direct child IDs
    }

    /// Flat array of all comments in DFS order with pre-computed search fields.
    private var searchIndex: [SearchEntry] = []

    /// Maps comment ID -> index in searchIndex for O(1) lookup.
    private var searchIndexMap: [Int: Int] = [:]

    func setComments(_ comments: [Comment]) {
        self.comments = comments
        topLevelIDs = comments.map { $0.id }
        buildSearchIndex(from: comments)
        applySearch(query: currentQuery)
    }

    /// Builds the flat search index from the comment tree. O(n) time and space.
    /// Uses iterative DFS with explicit stack to avoid deep recursion.
    private func buildSearchIndex(from roots: [Comment]) {
        searchIndex.removeAll()
        searchIndexMap.removeAll()

        // Each stack frame: (comment, ancestorIDs)
        var stack: [(Comment, [Int])] = roots.reversed().map { ($0, []) }

        while let (comment, ancestors) = stack.popLast() {
            let idx = searchIndex.count
            searchIndexMap[comment.id] = idx

            let entry = SearchEntry(
                id: comment.id,
                lowercasedText: comment.text?.lowercased() ?? "",
                lowercasedAuthor: comment.author?.lowercased() ?? "",
                ancestorIDs: ancestors,
                childIDs: comment.children.map { $0.id }
            )
            searchIndex.append(entry)

            // Push children with updated ancestor chain
            let childAncestors = ancestors + [comment.id]
            for child in comment.children.reversed() {
                stack.append((child, childAncestors))
            }
        }

        // Reserve capacity for visibleIDs based on total comment count
        visibleIDs.reserveCapacity(searchIndex.count)
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

        setComments(children)

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
    
    /// Applies search filter using the pre-computed flat index.
    /// O(n) scan over the flat array -- no recursion, no per-query allocations
    /// for lowercased strings. Ancestor propagation uses the pre-built chain.
    func applySearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        currentQuery = trimmed

        guard !trimmed.isEmpty else {
            visibleIDs.removeAll()
            matchCount = 0
            visibleTopLevelIDs = topLevelIDs
            return
        }

        visibleIDs.removeAll(keepingCapacity: true)
        matchCount = 0
        let lowered = trimmed.lowercased()

        // Single pass: for each matching comment, mark it and all its ancestors visible.
        // O(n * d) worst case where d = average depth, but d is typically small (~10-20).
        for entry in searchIndex {
            let isMatch = entry.lowercasedText.contains(lowered) || entry.lowercasedAuthor.contains(lowered)
            if isMatch {
                matchCount += 1
                visibleIDs.insert(entry.id)
                // Propagate visibility up the ancestor chain
                for ancestorID in entry.ancestorIDs {
                    visibleIDs.insert(ancestorID)
                }
            }
        }

        visibleTopLevelIDs = topLevelIDs.filter { visibleIDs.contains($0) }
    }
    
    func isVisible(_ id: Int) -> Bool {
        visibleIDs.isEmpty || visibleIDs.contains(id)
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
    }
    
    func collapseTopLevel() {
        collapsedIDs.formUnion(topLevelIDs)
    }
    
    func expandTopLevel() {
        collapsedIDs.subtract(topLevelIDs)
    }

    func countDescendants(_ comment: Comment) -> Int {
        var count = comment.children.count
        for child in comment.children {
            count += countDescendants(child)
        }
        return count
    }

    // Search matching is now handled by applySearch using the flat searchIndex.
    // The old recursive collectVisible/matches methods have been replaced by a
    // single O(n) pass over the pre-indexed array with pre-lowercased strings.
}
