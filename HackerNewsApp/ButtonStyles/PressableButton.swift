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
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

extension View {
    func createPressableButton() -> some View {
        buttonStyle(PressableButton())
    }
}
