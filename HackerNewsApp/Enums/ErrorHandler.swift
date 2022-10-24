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
    case urlError
    case noIDArray
    case decodingError
    case noStoryArray
    case infiniteLoadingFailed
    case bookmarkLoadFailed
    case settingsLoadError
    case diskSaveError
    case diskLoadError
    
    var errorDescription: String? {
        switch self {
        case .noInternet:
            return NSLocalizedString("You're not connected to the internet!", comment: "")
        case .urlError:
            return NSLocalizedString("Invalid URL", comment: "")
        case .noIDArray:
            return NSLocalizedString("Unable to fetch the ID array", comment: "")
        case .decodingError:
            return NSLocalizedString("Decoding error", comment: "")
        case .noStoryArray:
            return NSLocalizedString("Stories could not be fetched at the moment. Please try again", comment: "")
        case .infiniteLoadingFailed:
            return NSLocalizedString("Could not load posts further, try refreshing the page", comment: "")
        case .bookmarkLoadFailed:
            return NSLocalizedString("Failed to load bookmark. Please reinstall the app.", comment: "")
        case .settingsLoadError:
            return NSLocalizedString("Failed to load saved settings. Reverting to defaults.", comment: "")
        case .diskSaveError:
            return NSLocalizedString("Failed to save stories to the disk, please reinstall the app", comment: "")
        case .diskLoadError:
            return NSLocalizedString("Failed to load stories from disk. Make sure you're connected to the internet and try again.", comment: "")
        }
    }
}


struct ErrorType: Identifiable, Equatable {
    let id = UUID()
    let error: ErrorHandler
}
