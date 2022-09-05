//
//  ActionButtonsViewModifier.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/3/22.
//

import Foundation
import SwiftUI

struct ActionButtonViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title3.weight(.bold))
            .padding(.horizontal)
            .background(
                Color.orange
                    .frame(height: 40)
                    .cornerRadius(10)
            )
            .foregroundColor(.primary)
    }
}

extension View {
    func actionButton() -> some View {
        modifier(ActionButtonViewModifier())
    }
}
