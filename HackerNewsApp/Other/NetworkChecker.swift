//
//  InternetChecker.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/11/22.
//

import Foundation
import SwiftUI
import Network

class NetworkChecker: ObservableObject {
    let monitor = NWPathMonitor()
    let queue = DispatchQueue(label: "NetworkManager")
    @Published var isConnected: Bool = true
    
    
    init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async { [weak self] in
                self?.isConnected = path.status == .satisfied
            }
        }
        
        monitor.start(queue: queue)
    }
}
