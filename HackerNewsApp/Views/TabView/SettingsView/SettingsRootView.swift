import SwiftUI

struct SettingsRootView: View {
    @State private var path: [AppRoute] = []
#if DEBUG
    @EnvironmentObject var account: HNAccount
#endif
    
    var body: some View {
        NavigationStack(path: $path) {
            SettingsView(path: $path)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .comments(let story):
                        CommentsView(vm: CommentsRouteViewModel(story: story))
                    case .reader(let story):
                        ReaderView(story: story)
                    case .history:
                        HistoryView(path: $path)
#if DEBUG
                    case .hnAccount:
                        HNAccountView()
                    case .hnDiagnostics:
                        HNDiagnosticsView(account: account)
                    case .readerPreview:
                        ReaderPreviewView()
#endif
                    }
                }
        }
    }
}
