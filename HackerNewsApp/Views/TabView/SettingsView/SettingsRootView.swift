import SwiftUI

struct SettingsRootView: View {
    @State private var path: [AppRoute] = []
    
    var body: some View {
        NavigationStack(path: $path) {
            SettingsView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .comments(let story):
                        CommentsView(vm: CommentsRouteViewModel(story: story))
                    case .history:
                        HistoryView(path: $path)
                    }
                }
        }
    }
}
