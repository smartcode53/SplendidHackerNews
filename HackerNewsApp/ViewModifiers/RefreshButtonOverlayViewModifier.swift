//
//  RefreshButtonOverlayViewModifier.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/25/22.
//

import Foundation
import SwiftUI

struct RefreshButtonOverlayViewModifier: ViewModifier {
    
    let refreshFunc: () -> Void
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                Button {
                    refreshFunc()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .padding()
                        .background(LinearGradient(colors: [.orange, .blue], startPoint: .topTrailing, endPoint: .bottomLeading))
                        .clipShape(Circle())
                        .padding()
                        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
                }
            }
    }
}


extension View {
    func createRefreshButton(refreshButton: @escaping () -> Void) -> some View {
        modifier(RefreshButtonOverlayViewModifier(refreshFunc: refreshButton))
    }
}
