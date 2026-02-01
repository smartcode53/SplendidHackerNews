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
    var enableHNWriteActionsDebug: Bool
    var openInReader: Bool
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
         enableHNWriteActionsDebug: Bool = false,
         openInReader: Bool = false,
         readerFontScale: Double = 1.0,
         readerLineSpacing: Double = 4.0) {
        self.cardStyleString = cardStyleString
        self.themeString = themeString
        self.enableHNWriteActionsDebug = enableHNWriteActionsDebug
        self.openInReader = openInReader
        self.readerFontScale = readerFontScale
        self.readerLineSpacing = readerLineSpacing
    }

    enum CodingKeys: String, CodingKey {
        case cardStyleString
        case themeString
        case enableHNWriteActionsDebug
        case openInReader
        case readerFontScale
        case readerLineSpacing
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.cardStyleString = try container.decode(String.self, forKey: .cardStyleString)
        self.themeString = try container.decode(String.self, forKey: .themeString)
        self.enableHNWriteActionsDebug = try container.decodeIfPresent(Bool.self, forKey: .enableHNWriteActionsDebug) ?? false
        self.openInReader = try container.decodeIfPresent(Bool.self, forKey: .openInReader) ?? false
        self.readerFontScale = try container.decodeIfPresent(Double.self, forKey: .readerFontScale) ?? 1.0
        self.readerLineSpacing = try container.decodeIfPresent(Double.self, forKey: .readerLineSpacing) ?? 4.0
    }
}
