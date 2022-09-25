//
//  CommentsButtonView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/23/22.
//

import SwiftUI

struct CommentsButtonView<T>: View where T: CommentsButtonProtocol, T: SafariViewLoader {
    
    @ObservedObject var vm: T
    
    var body: some View {
        if let commentCount =  vm.story?.descendants {
            NavigationLink {
                CommentsView(vm: vm)
            } label: {
                Label(String(commentCount), systemImage: "bubble.right")
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
        }
    }
}
