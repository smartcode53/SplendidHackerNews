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
    
    static func getTimeInterval(with seconds: Int) -> String {
        let fromDate = Date(timeIntervalSince1970: Double(seconds))
        let toDate = Date(timeIntervalSince1970: Date.now.timeIntervalSince1970)
        
        let diff = Calendar.autoupdatingCurrent.dateComponents([.hour, .second, .minute, .day], from: fromDate, to: toDate)
        
        if let hour = diff.hour,
           let minute = diff.minute,
           let second = diff.second,
           let day = diff.day {
            
            if hour < 1 && minute < 1 && second < 10 {
                return "now"
            } else if hour < 1 && minute < 1 && second > 10 {
                return "\(second) seconds ago"
            } else if hour < 1 && minute > 1 {
                return "\(minute) minutes ago"
            } else if hour < 1 && minute == 1 {
                return "\(minute) minute ago"
            } else if day < 1 && hour > 1 {
                return "\(hour) hours ago"
            } else  if day < 1 && hour == 1 {
                return "\(hour) hour ago"
            } else if day > 1 {
                return "\(day) days ago"
            } else if day == 1 {
                return "\(day) day ago"
            } else {
                return "nil"
            }
            
        } else {
            return "nil"
        }
        
    }
}
