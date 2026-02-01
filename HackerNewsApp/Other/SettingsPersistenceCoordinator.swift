//
//  SettingsPersistenceCoordinator.swift
//  HackerNewsApp
//
//  Created by Codex on 1/31/26.
//

import Foundation

actor SettingsPersistenceCoordinator {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let defaultDebounceNanoseconds: UInt64
    private var pendingTask: Task<Void, Never>?

    init(fileURL: URL, debounceNanoseconds: UInt64 = 350_000_000) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.defaultDebounceNanoseconds = debounceNanoseconds
    }

    func scheduleSave(snapshot: Settings, debounceNanoseconds: UInt64? = nil) async {
        pendingTask?.cancel()
        let delay = debounceNanoseconds ?? defaultDebounceNanoseconds
        pendingTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            await self.writeSnapshot(snapshot)
        }
    }

    func saveNow(snapshot: Settings) async {
        pendingTask?.cancel()
        pendingTask = nil
        await writeSnapshot(snapshot)
    }

    private func writeSnapshot(_ snapshot: Settings) async {
        do {
            let data = try encoder.encode(snapshot)
            let tempURL = fileURL
                .deletingLastPathComponent()
                .appending(component: "\(fileURL.lastPathComponent).tmp.\(UUID().uuidString)")

            try data.write(to: tempURL, options: .atomic)

            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL, backupItemName: nil, options: .usingNewMetadataOnly)
            } else {
                try FileManager.default.moveItem(at: tempURL, to: fileURL)
            }
        } catch let error {
            print(error)
        }
    }
}
