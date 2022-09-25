//
//  GlobalSettingsViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/25/22.
//

import Foundation
import SwiftUI

class GlobalSettingsViewModel: ObservableObject {
    @Published var tempBookmarks: [Bookmark] = []
}
