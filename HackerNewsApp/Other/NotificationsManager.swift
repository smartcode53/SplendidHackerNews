//
//  NotificationsManager.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/21/22.
//

import Foundation
import SwiftUI
import UserNotifications

class NotificationsManager {
    
    static let instance = NotificationsManager()
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if let error {
                print("Error: \(error)")
            } else {
                print(success)
            }
        }
    }
}
