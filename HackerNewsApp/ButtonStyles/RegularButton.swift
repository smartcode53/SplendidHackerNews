//
//  RegularButton.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/21/22.
//

import Foundation
import SwiftUI

struct RegularButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.clear)
    }
}

extension View {
    func createRegularButton() -> some View {
        buttonStyle(RegularButton())
    }
}

