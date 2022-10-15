//
//  CustomNavLink.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/15/22.
//

import SwiftUI

struct CustomNavLink<Label: View, Destination: View>: View {
    
    let destination: Destination
    let label: Label
    
    var body: some View {
        NavigationLink {
            CustomNavbarContainerView {
                destination
            }
            .toolbar(.hidden, for: .navigationBar)
        } label: {
            Text("Click me")
        }
    }
}


extension CustomNavLink {
    
    init(destination: Destination, @ViewBuilder label: () -> Label) {
        self.destination = destination
        self.label = label()
    }
    
}

struct CustomNavLink_Previews: PreviewProvider {
    static var previews: some View {
        CustomNavView {
            CustomNavLink(destination: Text("Destination"), label: Text("Navigate"))
        }
    }
}
