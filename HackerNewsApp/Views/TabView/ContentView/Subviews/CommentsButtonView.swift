//
//  CommentsButtonView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/23/22.
//

import SwiftUI

struct CommentsButtonView<T>: View where T: CommentsButtonProtocol, T: SafariViewLoader {
    
    @ObservedObject var vm: T
    var action: (() -> Void)? = nil
    
    var body: some View {
        if let commentCount =  vm.story?.descendants {
            if let action {
                Button(action: action) {
                    Label(String(commentCount), systemImage: "bubble.right")
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
            } else {
                Label(String(commentCount), systemImage: "bubble.right")
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
            }
        }
    }
}
