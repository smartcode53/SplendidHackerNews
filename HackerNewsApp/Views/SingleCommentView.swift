//
//  SingleCommentView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/29/22.
//

import SwiftUI
import SwiftSoup

struct SingleCommentView: View {
    
    @ObservedObject var vm: MainViewModel
    
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
            
            commentMetaInfo
            
            if isExpanded {
                
                if let text = commentText {
                    Text(vm.parseText(text: text))
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.5)
                }
                
                
                if commentReplies != nil {
                    ForEach(commentReplies!) { comment in
                        SingleCommentView(vm: vm, commentText: comment.text ?? "Bad Comment", commentReplies: comment.commentChildren ?? nil, commentAuthor: comment.author ?? "Unknown", commentDate: comment.commentDate, indentLevel: indentLevel + 1)
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
        SingleCommentView(vm: MainViewModel(), commentAuthor: "skrillex", commentDate: "12/11/11")
    }
}
