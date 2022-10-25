//
//  SafariViewReaderProtocol.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/24/22.
//

import Foundation
import SwiftUI

protocol SafariViewLoader: ObservableObject {
    
    var networkManager: NetworkManager { get }
    
    func returnSafelyLoadedUrl(url: String) -> URL
}

extension SafariViewLoader {
    func returnSafelyLoadedUrl(url: String) -> URL {
        return networkManager.safelyLoadUrl(url: url)
    }
}
