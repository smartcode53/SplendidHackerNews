//
//  AttributedStringCache.swift
//  HackerNewsApp
//
//  Caches parsed AttributedString values to avoid re-parsing HTML
//  on every SwiftUI render cycle.
//  Thread-safe: NSCache is thread-safe by design.
//

import Foundation

/// Global cache for parsed comment HTML -> AttributedString.
/// Keyed by the raw HTML string. NSCache handles memory pressure eviction automatically.
final class AttributedStringCache: @unchecked Sendable {
    static let instance = AttributedStringCache()

    private init() {
        cache.countLimit = 2000 // Cap at 2000 entries; typical HN thread is 200-500
    }

    private let cache = NSCache<NSString, AttributedStringWrapper>()

    /// Returns a cached AttributedString for the given HTML string, or nil if not cached.
    func get(forKey html: String) -> AttributedString? {
        cache.object(forKey: html as NSString)?.value
    }

    /// Stores a parsed AttributedString for the given HTML string.
    func set(_ value: AttributedString, forKey html: String) {
        cache.setObject(AttributedStringWrapper(value), forKey: html as NSString)
    }

    /// Clears all cached entries (e.g., on memory warning).
    func removeAll() {
        cache.removeAllObjects()
    }
}

/// Reference-type wrapper so AttributedString (a value type) can be stored in NSCache.
private final class AttributedStringWrapper {
    let value: AttributedString

    init(_ value: AttributedString) {
        self.value = value
    }
}
