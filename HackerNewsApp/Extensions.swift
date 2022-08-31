//
//  Extensions.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/25/22.
//

import Foundation
import SwiftUI
import WebKit

extension Date {
    static func unixToRegular(_ seconds: Int) -> String {
        let date = Date(timeIntervalSince1970: Double(seconds))
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        dateFormatter.timeZone = .autoupdatingCurrent
        
        return dateFormatter.string(from: date)
    }
}

extension String {
    var toHTML: String {
        let attr = try? NSAttributedString(data: Data(utf8), options: [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ], documentAttributes: nil)

        return attr?.string ?? self
    }
    
    var toCleanHTML: String {
        let data = Data(self.utf8)
        
        do {
            let attributedString = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil)
            return attributedString.string
        } catch {
            print("There was an error converting the string from HTML to text")
        }
        
        return "No Comment"
    }
}

extension WKWebView {
    func load(_ urlString: String) {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            load(request)
        }
    }
}

