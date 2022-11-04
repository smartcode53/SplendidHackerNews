//
//  CustomNavView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/15/22.
//

import SwiftUI

struct CustomNavView<Content: View>: View {
    
    let content: Content
    
    var body: some View {
        NavigationStack {
            CustomNavbarContainerView {
                content
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .toolbarColorScheme(.dark, for: .navigationBar)

    }
}

extension CustomNavView {
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
}

struct CustomNavView_Previews: PreviewProvider {
    static var previews: some View {
        CustomNavView {
            LinearGradient(colors: [.orange, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(0.5)
                .ignoresSafeArea()
                
        }
    }
}
