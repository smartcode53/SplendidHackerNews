//
//  Protocols.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/5/22.
//

import Foundation

protocol SafariViewLoader: ObservableObject {
    func returnSafelyLoadedUrl(url: String) -> URL
}
