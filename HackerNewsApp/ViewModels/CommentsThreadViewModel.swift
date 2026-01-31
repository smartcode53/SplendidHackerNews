import Foundation

@MainActor
final class CommentsThreadViewModel: ObservableObject {
    @Published private(set) var topLevelIDs: [Int] = []
    @Published private(set) var visibleTopLevelIDs: [Int] = []
    @Published private(set) var matchCount: Int = 0
    @Published var collapsedIDs: Set<Int> = []
    
    private var visibleIDs: Set<Int> = []
    private var currentQuery: String = ""
    private var comments: [Comment] = []
    
    func setComments(_ comments: [Comment]) {
        self.comments = comments
        topLevelIDs = comments.map { $0.id }
        applySearch(query: currentQuery)
    }
    
    func applySearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        currentQuery = trimmed
        
        guard !trimmed.isEmpty else {
            visibleIDs.removeAll()
            matchCount = 0
            visibleTopLevelIDs = topLevelIDs
            return
        }
        
        visibleIDs.removeAll()
        matchCount = 0
        let lowered = trimmed.lowercased()
        
        for comment in comments {
            _ = collectVisible(comment: comment, query: lowered)
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
    
    private func collectVisible(comment: Comment, query: String) -> Bool {
        let selfMatch = matches(comment: comment, query: query)
        var childMatch = false
        
        for child in comment.children {
            if collectVisible(comment: child, query: query) {
                childMatch = true
            }
        }
        
        if selfMatch {
            matchCount += 1
        }
        
        if selfMatch || childMatch {
            visibleIDs.insert(comment.id)
        }
        
        return selfMatch || childMatch
    }
    
    private func matches(comment: Comment, query: String) -> Bool {
        let text = comment.text?.lowercased() ?? ""
        let author = comment.author?.lowercased() ?? ""
        return text.contains(query) || author.contains(query)
    }
}
