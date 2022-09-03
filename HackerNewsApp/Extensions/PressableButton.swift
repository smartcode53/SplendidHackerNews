//
//  PressableButton.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/3/22.
//

import Foundation
import SwiftUI

struct PressableButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.bold))
            .padding(.horizontal)
            .background(
                Color.orange
                    .frame(height: 40)
                    .cornerRadius(10)
            )
            .foregroundColor(.primary)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
    }
}

extension View {
    func createPressableButton() -> some View {
        buttonStyle(PressableButton())
    }
}
