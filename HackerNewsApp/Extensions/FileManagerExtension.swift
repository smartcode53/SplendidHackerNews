//
//  FileManagerExtension.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/25/22.
//

import Foundation
import SwiftUI

extension FileManager {
    var documentsDirectory: URL {
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return path[0]
    }
}
