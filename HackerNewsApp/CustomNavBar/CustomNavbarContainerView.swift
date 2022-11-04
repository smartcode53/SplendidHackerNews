//
//  CustomNavbarContainerView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/15/22.
//

import SwiftUI

struct CustomNavbarContainerView<Content: View>: View {
    
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    @State private var showBackButton: Bool = true
    @State private var title: String = "No Title"
    
    let content: Content
    
    var body: some View {
        VStack(spacing: 0) {
            CustomNavBarView(showBackButton: showBackButton, title: title)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onPreferenceChange(CustomNavBarTitlePreferenceKey.self) { value in
            self.title = value
        }
        .onPreferenceChange(CustomNavBarBackButtonHiddenPreferenceKey.self) { value in
            self.showBackButton = !value
        }
    }
}

extension CustomNavbarContainerView {
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
}

struct CustomNavbarContainerView_Previews: PreviewProvider {
    static var previews: some View {
        CustomNavbarContainerView {
            ZStack {
                Color.orange.ignoresSafeArea()
                
                Text("Hello, World!")
                    .foregroundColor(.white)
            }
        }
    }
}
