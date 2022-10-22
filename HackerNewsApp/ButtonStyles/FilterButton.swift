//
//  FilterButton.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/13/22.
//

import Foundation
import SwiftUI

struct FilterButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(configuration.isPressed ? Color("SortButtonBackground") : .clear)
            .cornerRadius(12)
            .foregroundColor(configuration.isPressed ? Color("SortButtonText") : Color("PostTitle"))
    }
}


extension View {
    func createFilterButton() -> some View {
        buttonStyle(FilterButton())
    }
}
