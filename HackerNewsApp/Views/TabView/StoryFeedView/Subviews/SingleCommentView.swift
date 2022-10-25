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
    var storyAuthor: String
    
    
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
                } else {
                    Text("Comment Not found")
                        .background(.red)
                }
                
                Spacer()
                
                if let commentReplies {
                    LazyVStack {
                        ForEach(commentReplies) { comment in
                            SingleCommentView(comment: comment, indentLevel: vm.indentLevel + 1, storyAuthor: storyAuthor)
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
        .background(Color("CardColor"))
    }
}

extension SingleCommentView {
    
    var commentMetaInfo: some View {
        HStack {
            if commentAuthor == storyAuthor {
                HStack {
                    Text(commentAuthor ?? "Unknown")
                    
                    Text("Author")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.regularMaterial)
                        .font(.caption.bold())
                        .clipShape(Capsule())
                }
                .padding(.trailing)
                
                
            } else {
                Text(commentAuthor ?? "Unknown")
                    .padding(.trailing)
            }
            
            
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
    
    init(comment: Comment, indentLevel: Double = 0, storyAuthor: String) {
        self.commentText = comment.text
        self.commentReplies = comment.commentChildren
        self.commentAuthor = comment.author
        self.commentDate = comment.createdAtI
        self.storyAuthor = storyAuthor
    }
}

