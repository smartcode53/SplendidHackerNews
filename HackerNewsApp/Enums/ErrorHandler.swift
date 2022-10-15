//
//  ErrorHandler.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/14/22.
//

import Foundation
import SwiftUI

enum ErrorHandler: Error, LocalizedError {
    case noInternet
    
    var errorDescription: String? {
        switch self {
        case .noInternet:
            return NSLocalizedString("You're not connected to the internet!", comment: "")
        }
    }
}
