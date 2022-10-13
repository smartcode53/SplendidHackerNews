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
            .font(.headline.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(Color("BlueButton"))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
    }
}

extension View {
    func createPressableButton() -> some View {
        buttonStyle(PressableButton())
    }
}
