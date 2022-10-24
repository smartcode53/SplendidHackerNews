//
//  CustomPullToRefreshProtocol.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/24/22.
//

import Foundation
import SwiftUI


protocol CustomPullToRefresh: ObservableObject {
    
    var functionHasRan: Bool {get set}
    var hasAskedToReload: Bool {get set}
    
    func refresh()
}
