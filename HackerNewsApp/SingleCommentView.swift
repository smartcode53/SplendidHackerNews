//
//  SingleCommentView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/27/22.
//

import SwiftUI

struct SingleCommentView: View {
    
    let commentAuthor: String
    let commentDate: String
    
    var body: some View {
        HStack {
            Label(commentAuthor, systemImage: "person.fill")
                .foregroundColor(.orange)
            Text("|")
            Text(commentDate)
                .foregroundColor(.orange)
            
            Spacer()
            
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundColor(.black)
        }
        .padding()
        .overlay(
            Rectangle()
                .fill(.black.opacity(0.5))
                .frame(height: 1)
            ,
            alignment: .top
        )
        .overlay(
            Rectangle()
                .fill(.black.opacity(0.5))
                .frame(height: 1)
            ,
            alignment: .bottom
        )
    }
}

struct SingleCommentView_Previews: PreviewProvider {
    static var previews: some View {
        SingleCommentView(commentAuthor: "skrillex", commentDate: "2h ago")
    }
}
