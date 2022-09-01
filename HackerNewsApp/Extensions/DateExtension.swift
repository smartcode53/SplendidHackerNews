//
//  DateExtension.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/1/22.
//

import Foundation
import SwiftUI

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
