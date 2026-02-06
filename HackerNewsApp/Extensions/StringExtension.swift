//
//  StringExtension.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/5/22.
//

import Foundation
import UIKit
import SwiftSoup

extension String {
    var parsedText: String {
        do {
            let document = try SwiftSoup.parse(self)
            return try document.text(trimAndNormaliseWhitespace: true)
        } catch let error {
            print("There was an error parsing the text from HTML. Here's the error description: \(error)")
        }
        
        return ""
    }
    
    var parsedBodyFragment: String {
        do {
            let html: String = self
            let doc: Document = try SwiftSoup.parseBodyFragment(html)
            return try doc.text(trimAndNormaliseWhitespace: true)
        } catch let error {
            print("There was an error parsing the text from HTML. Here's the error description: \(error)")
        }
        
        return ""
    }
    
    /// Parses HTML into an `AttributedString` using the lightweight
    /// `CommentHTMLParser` (SwiftSoup-based, no WebKit overhead).
    /// Results are cached in `AttributedStringCache` keyed by the HTML string.
    /// First access: O(n) parse via SwiftSoup. Subsequent: O(1) cache hit.
    var markdown: AttributedString {
        let cache = AttributedStringCache.instance
        if let cached = cache.get(forKey: self) {
            return cached
        }
        let parsed = CommentHTMLParser.parse(self)
        cache.set(parsed, forKey: self)
        return parsed
    }
    
    var urlDomain: String? {
        if let generatedUrl = URL(string: self) {
            return generatedUrl.host
        }
        return nil
    }
    
    func fixToBrowserString() -> String {
        self.replacingOccurrences(of: ";", with: "%3B")
            .replacingOccurrences(of: "\n", with: "%0D%0A")
            .replacingOccurrences(of: " ", with: "+")
            .replacingOccurrences(of: "!", with: "%21")
            .replacingOccurrences(of: "\"", with: "%22")
            .replacingOccurrences(of: "\\", with: "%5C")
            .replacingOccurrences(of: "/", with: "%2F")
            .replacingOccurrences(of: "‘", with: "%91")
            .replacingOccurrences(of: ",", with: "%2C")
        //more symbols fixes here: https://mykindred.com/htmlspecialchars.php
    }
    
}
