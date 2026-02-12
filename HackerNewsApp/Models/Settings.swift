//
//  Settings.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/27/22.
//

import Foundation
import SwiftUI

struct Settings: Codable {
    var cardStyleString: String
    var themeString: String
    var openInReader: Bool
    var openReaderLinksInReader: Bool
    var readerFontScale: Double
    var readerLineSpacing: Double
    
    enum CardStyle: String, CaseIterable {
        case compact = "Compact"
        case normal = "Normal"
    }
    
    enum Theme: String, CaseIterable {
        case dark = "Dark"
        case light = "Light"
        case automatic = "Automatic"
    }

    init(cardStyleString: String,
         themeString: String,
         openInReader: Bool = false,
         openReaderLinksInReader: Bool = false,
         readerFontScale: Double = 1.0,
         readerLineSpacing: Double = 2.0) {
        self.cardStyleString = cardStyleString
        self.themeString = themeString
        self.openInReader = openInReader
        self.openReaderLinksInReader = openReaderLinksInReader
        self.readerFontScale = readerFontScale
        self.readerLineSpacing = readerLineSpacing
    }

    enum CodingKeys: String, CodingKey {
        case cardStyleString
        case themeString
        case openInReader
        case openReaderLinksInReader
        case readerFontScale
        case readerLineSpacing
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.cardStyleString = try container.decode(String.self, forKey: .cardStyleString)
        self.themeString = try container.decode(String.self, forKey: .themeString)
        self.openInReader = try container.decodeIfPresent(Bool.self, forKey: .openInReader) ?? false
        self.openReaderLinksInReader = try container.decodeIfPresent(Bool.self, forKey: .openReaderLinksInReader) ?? false
        self.readerFontScale = try container.decodeIfPresent(Double.self, forKey: .readerFontScale) ?? 1.0
        self.readerLineSpacing = try container.decodeIfPresent(Double.self, forKey: .readerLineSpacing) ?? 2.0
    }
}

#if DEBUG
struct DebugSettings: Codable {
    var enableHNWriteActions: Bool

    init(enableHNWriteActions: Bool = false) {
        self.enableHNWriteActions = enableHNWriteActions
    }

    enum CodingKeys: String, CodingKey {
        case enableHNWriteActions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enableHNWriteActions = try container.decodeIfPresent(Bool.self, forKey: .enableHNWriteActions) ?? false
    }
}

@MainActor
final class DebugEnvironment: ObservableObject {
    static let shared = DebugEnvironment()

    @Published var fixtureMode: Bool {
        didSet {
            defaults.set(fixtureMode, forKey: Keys.fixtureMode)
            triggerFixtureReload()
        }
    }

    @Published var fixtureStoryIDText: String {
        didSet {
            defaults.set(fixtureStoryIDText, forKey: Keys.fixtureStoryID)
        }
    }

    @Published var fixtureURLString: String {
        didSet {
            defaults.set(fixtureURLString, forKey: Keys.fixtureURL)
        }
    }

    @Published var fixtureRefreshToken: Int = 0

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.fixtureMode = defaults.bool(forKey: Keys.fixtureMode)
        self.fixtureStoryIDText = defaults.string(forKey: Keys.fixtureStoryID) ?? "8863"
        self.fixtureURLString = defaults.string(forKey: Keys.fixtureURL) ?? "https://example.com/fixture"
    }

    var fixtureStoryID: Int {
        Int(fixtureStoryIDText.filter { $0.isNumber }) ?? 8863
    }

    var fixtureURL: URL {
        if let url = URL(string: fixtureURLString), url.scheme != nil {
            return url
        }
        return URL(string: "https://example.com/fixture")!
    }

    func triggerFixtureReload() {
        fixtureRefreshToken += 1
    }

    private enum Keys {
        static let fixtureMode = "debug.fixtureMode"
        static let fixtureStoryID = "debug.fixtureStoryID"
        static let fixtureURL = "debug.fixtureURL"
    }
}

enum DebugFixtures {
    static let feedStories: [Story] = {
        let baseTime = 1_700_000_000
        return (1...25).map { index in
            let id = 900_000 + index
            return Story(
                by: "fixture_user_\(index)",
                descendants: 30,
                id: id,
                score: 200 - index,
                time: baseTime + (index * 3600),
                title: "Fixture Story \(index): Deterministic Feed Row",
                type: "story",
                url: "https://example.com/fixture/\(id)"
            )
        }
    }()

    static func story(for id: Int, title: String? = nil, url: URL? = nil) -> Story {
        Story(
            by: "fixture_author",
            descendants: 30,
            id: id,
            score: 120,
            time: 1_700_000_000,
            title: title ?? "Fixture Story \(id)",
            type: "story",
            url: url?.absoluteString ?? "https://example.com/fixture/\(id)"
        )
    }

    static func commentsItem(storyID: Int) -> Item {
        let baseTime = 1_700_000_000
        var topLevel: [Comment] = []
        for topIndex in 1...5 {
            let topId = storyID * 1000 + topIndex
            var children: [Comment] = []
            for childIndex in 1...3 {
                let childId = storyID * 10_000 + topIndex * 10 + childIndex
                var grandChildren: [Comment] = []
                if childIndex <= 2 {
                    let grandId = storyID * 100_000 + topIndex * 100 + childIndex
                    let grandText = "Deep reply \(topIndex).\(childIndex) with a link to [Example](https://example.com/deep)."
                    var greatGrandChildren: [Comment] = []
                    if topIndex == 1 && childIndex == 1 {
                        let greatId = storyID * 1_000_000 + 1
                        let greatText = "Even deeper nesting level with [Docs](https://example.com/docs)."
                        greatGrandChildren = [
                            Comment(id: greatId,
                                    createdAtI: baseTime + 540,
                                    type: "comment",
                                    author: "fixture_depth",
                                    text: greatText,
                                    parentId: grandId,
                                    storyId: storyID,
                                    children: [])
                        ]
                    }
                    grandChildren = [
                        Comment(id: grandId,
                                createdAtI: baseTime + 360,
                                type: "comment",
                                author: "fixture_child",
                                text: grandText,
                                parentId: childId,
                                storyId: storyID,
                                children: greatGrandChildren)
                    ]
                }
                let childText = "Reply \(topIndex).\(childIndex) with reference to [HN](https://news.ycombinator.com)."
                children.append(
                    Comment(id: childId,
                            createdAtI: baseTime + 180,
                            type: "comment",
                            author: "fixture_user_\(topIndex)",
                            text: childText,
                            parentId: topId,
                            storyId: storyID,
                            children: grandChildren)
                )
            }
            let topText = "Top level comment \(topIndex): deterministic content for UI automation."
            topLevel.append(
                Comment(id: topId,
                        createdAtI: baseTime,
                        type: "comment",
                        author: "fixture_top_\(topIndex)",
                        text: topText,
                        parentId: storyID,
                        storyId: storyID,
                        children: children)
            )
        }

        return Item(
            id: storyID,
            createdAtI: baseTime,
            type: "story",
            author: "fixture_author",
            title: "Fixture Comment Thread",
            url: "https://example.com/fixture/\(storyID)",
            points: 120,
            children: topLevel
        )
    }

    static func readerContent(url: URL, title: String) -> ReaderContent {
        let blocks: [ReaderBlock] = [
            .heading("Fixture Reader Article", level: 1),
            .paragraph([
                .text("This is deterministic reader content with a "),
                .link(text: "sample link", url: URL(string: "https://example.com/link")!),
                .text(" and a bit more narrative to fill space.")
            ]),
            .paragraph([
                .text("Second paragraph with a reference to "),
                .link(text: "documentation", url: URL(string: "https://example.com/docs")!),
                .text(" for action sheet testing.")
            ]),
            .quote("A short quote block that stays visible for automation."),
            .code("let fixture = ReaderBlock.code(\"Deterministic code snippet\")"),
            .heading("Subheading", level: 2),
            .paragraph([
                .text("Final paragraph with another "),
                .link(text: "deep link", url: URL(string: "https://example.com/deep")!),
                .text(" to validate link handling.")
            ])
        ]

        return ReaderContent(
            title: title,
            urlString: url.absoluteString,
            domain: url.host,
            blocks: blocks,
            isTruncated: false
        )
    }
}

extension Comment {
    init(
        id: Int,
        createdAtI: Int,
        type: String,
        author: String?,
        text: String?,
        parentId: Int,
        storyId: Int?,
        children: [Comment]
    ) {
        self.id = id
        self.createdAtI = createdAtI
        self.type = type
        self.author = author
        self.text = text
        self.parentId = parentId
        self.storyId = storyId
        self.children = children
    }
}

extension Item {
    init(
        id: Int,
        createdAtI: Int,
        type: String,
        author: String?,
        title: String,
        url: String?,
        points: Int,
        children: [Comment]?
    ) {
        self.id = id
        self.createdAtI = createdAtI
        self.type = type
        self.author = author
        self.title = title
        self.url = url
        self.points = points
        self.children = children
    }
}
#endif
