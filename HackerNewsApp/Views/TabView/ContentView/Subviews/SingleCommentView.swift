//
//  SingleCommentView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/29/22.
//

import SwiftUI
struct SingleCommentView: View {
    let comment: Comment
    @ObservedObject var threadVM: CommentsThreadViewModel
    let indentLevel: Int
    
    var body: some View {
        if threadVM.isVisible(comment.id) {
            VStack(alignment: .leading) {
                
                commentMetaInfo
                
                if !threadVM.isCollapsed(comment.id) {
                    
                    if let text = comment.text {
                        Text(text.markdown)
                            .tint(.accentColor)
                    }
                    
                    Spacer()
                    
                    if let replies = comment.commentChildren {
                        LazyVStack {
                            ForEach(replies) { child in
                                if threadVM.isVisible(child.id) {
                                    SingleCommentView(comment: child, threadVM: threadVM, indentLevel: indentLevel + 1)
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
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color("CardColor"))
            .padding(.leading, CGFloat(indentLevel) * 8)
        }
    }
}

extension SingleCommentView {
    
    var commentMetaInfo: some View {
        HStack {
            Text(comment.author ?? "Unknown")
                .padding(.trailing)
            
            Text(Date.getTimeInterval(with: comment.createdAtI))
            
            Spacer()
            
            
            Image(systemName: "chevron.up")
                .rotationEffect(Angle(degrees: threadVM.isCollapsed(comment.id) ? 180 : 0))
        }
        .font(.callout)
        .background(Color("CardColor"))
        .padding(.bottom, 10)
        .foregroundColor(.secondary)
        .onTapGesture {
            withAnimation(.easeInOut) {
                threadVM.toggleCollapse(comment.id)
            }
            
        }
    }
}
