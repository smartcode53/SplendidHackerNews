//
//  SayNoToListsViewModifier.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/24/22.
//

import Foundation
import SwiftUI


struct SayNoToListsViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

extension View {
    func sayNoToLists() -> some View {
        modifier(SayNoToListsViewModifier())
    }
}
