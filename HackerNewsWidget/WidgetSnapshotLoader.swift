import Foundation

struct WidgetSnapshotLoader {
    static let appGroupID = "group.com.hackerpillar.shared"

    static func loadSnapshot() -> WidgetSnapshot? {
        let decoder = JSONDecoder()

        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let url = container.appendingPathComponent("widget_snapshot.json")
            if let data = try? Data(contentsOf: url),
               let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data) {
                return snapshot
            }
        }
        return nil
    }
}
