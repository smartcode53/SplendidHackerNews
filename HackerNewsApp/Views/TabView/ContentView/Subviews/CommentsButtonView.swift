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
            
            HStack(spacing: 5) {
                Image(systemName: "bubble.right")
                Text(String(commentCount))
            }
            .padding(8)
            .background(.secondary.opacity(0.2))
            .cornerRadius(7)
            .foregroundColor(.primary)
            .fontWeight(.regular)
            .overlay {
                NavigationLink {
                    CommentsView(vm: vm)
                } label: {
                    EmptyView()
                }
                .buttonStyle(.bordered)
                .opacity(0)
            }
                
        }
    }
}
