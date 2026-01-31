import Foundation
import SwiftUI

@MainActor
final class HistoryViewModel: ObservableObject, SafariViewLoader {
    @Published var entries: [HistoryEntry] = []
    
    private let historyStore: HistoryStore
    private let readStateStore: ReadStateStore
    
    lazy var networkManager: NetworkManager = NetworkManager.instance
    
    init(historyStore: HistoryStore = HistoryStore.shared,
         readStateStore: ReadStateStore = ReadStateStore.shared) {
        self.historyStore = historyStore
        self.readStateStore = readStateStore
    }
    
    func load() async {
        entries = await historyStore.allEntries()
    }
    
    func clear() async {
        await historyStore.clear()
        entries = []
    }
    
    func markRead(storyID: Int) async {
        await readStateStore.markRead(storyID: storyID)
    }
}
