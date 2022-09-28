//
//  SingleCommentView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/29/22.
//

import SwiftUI
import SwiftSoup
import Atributika

struct SingleCommentView: View {
    
    @StateObject var vm = SingleCommentViewModel()
    
    var commentText: String?
    var commentReplies: [Comment]?
    var commentAuthor: String?
    var commentDate: Int
    
    
    var animateArrow: Bool {
        vm.isExpanded
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            
            commentMetaInfo
            
            
            if vm.isExpanded {
                
                if let text = commentText {
                    
                    Text(text.markdown)
                        .tint(.orange)
                }
                
                Spacer()
                
                if commentReplies != nil {
                    LazyVStack {
                        ForEach(commentReplies!) { comment in
                            SingleCommentView(comment: comment, indentLevel: vm.indentLevel + 1)
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
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("CardColor"))
    }
}

extension SingleCommentView {
    
    var commentMetaInfo: some View {
        HStack {
            Text(commentAuthor ?? "Unknown")
                .padding(.trailing)
            
            Text(Date.getTimeInterval(with: commentDate))
            
            Spacer()
            
            
            Image(systemName: "chevron.up")
                .rotationEffect(Angle(degrees: !animateArrow ? 180 : 0))
        }
        .font(.callout)
        .background(Color("CardColor"))
        .padding(.bottom, 10)
        .foregroundColor(.orange)
        .onTapGesture {
            withAnimation(.easeInOut) {
                vm.isExpanded.toggle()
            }
            
        }
    }
    
    init(comment: Comment, indentLevel: Double = 0) {
        self.commentText = comment.text
        self.commentReplies = comment.commentChildren
        self.commentAuthor = comment.author
        self.commentDate = comment.createdAtI
    }
}

