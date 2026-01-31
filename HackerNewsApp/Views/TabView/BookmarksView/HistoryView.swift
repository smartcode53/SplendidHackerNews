import SwiftUI

struct HistoryView: View {
    @Binding var path: [AppRoute]
    @StateObject private var vm = HistoryViewModel()
    @State private var showClearAlert = false
    @Environment(\.openURL) var openURL
    
    var body: some View {
        List {
            if vm.entries.isEmpty {
                HStack {
                    Spacer()
                    Text("No history yet")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else {
                ForEach(vm.entries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.title)
                            .font(.headline)
                        HStack {
                            Text(Date.getTimeInterval(with: entry.openedAt))
                            Text("|")
                            Text(entry.feed)
                            Spacer()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let url = entry.url, let safe = URL(string: url) {
                            openURL(safe, prefersInApp: true)
                        }
                        Task { await vm.markRead(storyID: entry.storyID) }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") {
                    showClearAlert = true
                }
                .disabled(vm.entries.isEmpty)
            }
        }
        .alert("Clear History?", isPresented: $showClearAlert) {
            Button("Clear", role: .destructive) {
                Task { await vm.clear() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all history entries.")
        }
        .task {
            await vm.load()
        }
    }
}
