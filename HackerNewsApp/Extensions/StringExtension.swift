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
    
    var markdown: AttributedString {
        let html = self

        if let data = html.data(using: .utf8) {
            if let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            ) {
                let mutable = NSMutableAttributedString(attributedString: attributed)
                let baseFont = UIFont.preferredFont(forTextStyle: .body)
                let fullRange = NSRange(location: 0, length: mutable.length)
                mutable.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
                    let font = (value as? UIFont) ?? baseFont
                    var descriptor = baseFont.fontDescriptor
                    let traits = font.fontDescriptor.symbolicTraits
                    if let adjusted = descriptor.withSymbolicTraits(traits) {
                        descriptor = adjusted
                    }
                    let newFont = UIFont(descriptor: descriptor, size: baseFont.pointSize)
                    mutable.addAttribute(.font, value: newFont, range: range)
                }
                return AttributedString(mutable)
            }
        }

        if let fallback = try? SwiftSoup.parseBodyFragment(html).text(trimAndNormaliseWhitespace: true) {
            return AttributedString(fallback)
        }

        return AttributedString(html)
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
