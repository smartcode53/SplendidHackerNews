import SwiftUI

struct BookmarksRootView: View {
    @State private var path: [AppRoute] = []
    @EnvironmentObject var account: HNAccount
    
    var body: some View {
        NavigationStack(path: $path) {
            BookmarksView(path: $path)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .comments(let story):
                        CommentsView(vm: CommentsRouteViewModel(story: story))
                    case .reader(let story):
                        ReaderView(story: story)
                    case .history:
                        HistoryView(path: $path)
                    case .hnAccount:
                        HNAccountView()
                    #if DEBUG
                    case .hnDiagnostics:
                        HNDiagnosticsView(account: account)
                    case .readerPreview:
                        ReaderPreviewView()
                    #else
                    case .readerPreview:
                        EmptyView()
                    #endif
                    }
                }
        }
    }
}
