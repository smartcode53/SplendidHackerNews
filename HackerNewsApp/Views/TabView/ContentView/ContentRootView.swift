import SwiftUI

struct ContentRootView: View {
    @State private var path: [AppRoute] = []
    
    var body: some View {
        NavigationStack(path: $path) {
            ContentView(path: $path)
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
