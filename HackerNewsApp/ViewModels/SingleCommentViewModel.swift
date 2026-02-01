//
//  SingleCommentViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/5/22.
//

import Foundation

@MainActor
class SingleCommentViewModel: ObservableObject {
    @Published var indentLevel: Double = 0
    @Published var isExpanded = true
}
