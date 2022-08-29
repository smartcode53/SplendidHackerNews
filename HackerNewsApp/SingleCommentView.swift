//
//  SingleCommentView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/29/22.
//

import SwiftUI

struct SingleCommentView: View {
    
    var commentText: String?
    var commentReplies: [Comment]?
    var commentAuthor: String
    var commentDate: String
    
    @State var indentLevel: Double = 0
    @State var isExpanded = true
    
    var animateArrow: Bool {
        isExpanded
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            HStack {
                Text(commentAuthor)
                    .padding(.trailing)
                
                Text(commentDate)
                
                Spacer()
                
                Image(systemName: "arrow.up.square.fill")
                    .rotationEffect(Angle(degrees: !animateArrow ? 180 : 0))
            }
            .font(.headline.weight(.semibold))
            .foregroundColor(.orange)
            .padding(.bottom, 10)
            .onTapGesture {
                withAnimation(.easeInOut) {
                    isExpanded.toggle()
                }
                
            }
            
            if isExpanded {
                if let text = commentText {
                    Text(text.toCleanHTML)
                }
                
                
                if commentReplies != nil {
                    ForEach(commentReplies!) { comment in
                        SingleCommentView(commentText: comment.text ?? "Bad Comment", commentReplies: comment.commentChildren ?? nil, commentAuthor: comment.author ?? "Unknown", commentDate: comment.commentDate, indentLevel: indentLevel + 1)
                            .overlay(
                                Capsule()
                                    .fill(Color.orange)
                                    .frame(width: 1)
                                    ,
                                alignment: .leading
                            )
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
    }
}

struct SingleCommentView_Previews: PreviewProvider {
    static var previews: some View {
        SingleCommentView(commentAuthor: "skrillex", commentDate: "12/11/11")
    }
}
