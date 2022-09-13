//
//  StringExtension.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/5/22.
//

import Foundation
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
    
}
