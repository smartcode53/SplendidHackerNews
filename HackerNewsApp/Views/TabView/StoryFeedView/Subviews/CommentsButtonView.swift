//
//  CommentsButtonView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/23/22.
//

import SwiftUI

struct CommentsButtonView<T>: View where T: CommentsButtonProtocol, T: SafariViewLoader {
    
    @ObservedObject var vm: T
    @State private var linkActive = false
    
    var body: some View {
        if let commentCount =  vm.story?.descendants {
            
            NavigationLink {
                CommentsView(vm: vm)
            } label: {
                Label(String(commentCount), systemImage: "bubble.right")
            }
            .buttonStyle(.bordered)
        }
    }
}
