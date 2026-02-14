import WidgetKit
import SwiftUI

struct HackerPillarWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct HackerPillarWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> HackerPillarWidgetEntry {
        HackerPillarWidgetEntry(
            date: Date(),
            snapshot: WidgetSnapshot(
                generatedAt: Date(),
                bookmarkCount: 12,
                historyCount: 30,
                trackedThreadsCount: 4,
                topBookmarkTitle: "Sample Story"
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (HackerPillarWidgetEntry) -> Void) {
        let snapshot = WidgetSnapshotLoader.loadSnapshot() ?? placeholder(in: context).snapshot
        completion(HackerPillarWidgetEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HackerPillarWidgetEntry>) -> Void) {
        let snapshot = WidgetSnapshotLoader.loadSnapshot() ?? placeholder(in: context).snapshot
        let entry = HackerPillarWidgetEntry(date: Date(), snapshot: snapshot)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct HackerPillarWidgetView: View {
    let entry: HackerPillarWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "newspaper")
                    .foregroundStyle(.orange)
                Text("HackerPillar")
                    .font(.headline)
            }

            Text("Bookmarks: \(entry.snapshot.bookmarkCount)")
                .font(.subheadline)
            Text("History: \(entry.snapshot.historyCount)")
                .font(.subheadline)
            Text("Tracked: \(entry.snapshot.trackedThreadsCount)")
                .font(.subheadline)

            if let title = entry.snapshot.topBookmarkTitle, !title.isEmpty {
                Text(title)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .containerBackground(.background, for: .widget)
    }
}

struct HackerPillarWidget: Widget {
    let kind: String = "HackerPillarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HackerPillarWidgetProvider()) { entry in
            HackerPillarWidgetView(entry: entry)
        }
        .configurationDisplayName("HackerPillar Stats")
        .description("Quick view of bookmarks, history, and tracked threads.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct HackerPillarWidgetBundle: WidgetBundle {
    var body: some Widget {
        HackerPillarWidget()
    }
}

#Preview(as: .systemSmall) {
    HackerPillarWidget()
} timeline: {
    HackerPillarWidgetEntry(
        date: .now,
        snapshot: WidgetSnapshot(
            generatedAt: .now,
            bookmarkCount: 8,
            historyCount: 22,
            trackedThreadsCount: 3,
            topBookmarkTitle: "Introducing HackerPillar Widgets"
        )
    )
}
