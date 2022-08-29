//
//  CommentsView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/26/22.
//

import SwiftUI

struct CommentsView: View {
    
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var vm: MainViewModel
    
    @State var comments = [Comment]()
    
    //    @State var commentAuthor: String? = nil
    //    @State var commentText: String? = nil
    //    @State var parentId: Int? = nil
    //    @State var commentDate: String? = nil
    //    @State var commentId: String? = nil
    
    @State var isExpanded = true
    
    let storyTitle: String
    let storyAuthor: String
    let points: Int
    let totalCommentCount: Int
    let storyDate: String
    let storyId: String
    
    
    
    
    var body: some View {
        ZStack {
            Color.orange
                .ignoresSafeArea()
            
            VStack {
                
                HStack {
                    Image(systemName: "arrow.turn.down.left")
                        .font(.title.weight(.semibold))
                        .onTapGesture {
                            dismiss()
                        }
                    
                    Spacer()
                }
                .padding([.horizontal, .bottom])
                
                
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(storyDate)
                            .font(.headline)
                            .foregroundColor(.black.opacity(0.5))
                        
                        Text(storyTitle)
                            .font(.title2.weight(.bold))
                        
                        
                        Text("google.com")
                            .font(.headline)
                            .foregroundColor(.black.opacity(0.5))
                        
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.forward.square.fill")
                        .font(.title.weight(.bold))
                        .foregroundColor(.black)
                }
                .padding()
                .background(.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .shadow(radius: 4)
                .padding(.bottom)
                
                
                
                HStack {
                    Label(storyAuthor, systemImage: "person.fill")
                    
                    Spacer()
                    
                    Text(points == 1 ? "\(points) Point" : "\(points) points")
                    
                    Spacer()
                    
                    Text(totalCommentCount == 1 ? "\(totalCommentCount) comment" : "\(totalCommentCount) comments")
                }
                .padding()
                .background(.black)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .shadow(radius: 4)
                
//                ScrollView {
//
//                    OutlineGroup(comments, children: \.children) { comment in
//                        VStack(alignment: .leading) {
//                            HStack {
//                                Text(comment.author ?? "Unknown Author")
//                                    .padding(.trailing)
//                                
//                                Text(comment.commentDate)
//                                
//                                Spacer()
//                            }
//                            .foregroundColor(.orange)
//                            .font(.body.weight(.bold))
//                            
//                            Text(comment.text?.toHTML ?? "Unable to parse comment")
//                                .font(.body.weight(.medium))
//                                .foregroundColor(.black)
//                        }
//                        
//                    }
//                    .background(.white)
//                }
                
                
//                List(comments, children: \.children) { comment in
//                    VStack {
//
//                        HStack {
//                            SingleCommentView(commentAuthor: comment.author ?? "Unknown", commentDate: comment.commentDate)
//                        }
//
//                        Text(comment.text?.toHTML ?? "No Text")
//                            .font(.headline)
//                    }
//                }
//                .listStyle(.plain)
//                .tint(.orange)
                
//                ScrollView {
//                    LazyVStack {
//                        ForEach(comments) { comment in
//                            SingleCommentView(commentAuthor: comment.author ?? "Unknown", commentDate: comment.commentDate)
//                                .onAppear {
//                                    vm.commentIterator(comment: comment)
//                        }
//                    }
//                    .padding()
//                    .background(.white)
//                    .cornerRadius(12)
//                }
//            }
                
                ScrollView {
                    ForEach(comments) { comment in
                        ExtractedView(commentText: comment.text ?? "No Comment", commentReplies: comment.commentChildren ?? nil, commentAuthor: comment.author ?? "Unknown", commentDate: comment.commentDate)
                    }
                }
                
            }
            .navigationBarHidden(true)
            .task {
                do {
                    comments = try await vm.getComments(for: storyId)
                } catch let error {
                    print("Error fetching data using task modifier on CommentsView: \(error)")
                }
            }
        }
    }
}

struct CommentsView_Previews: PreviewProvider {
    static var previews: some View {
        CommentsView(vm: MainViewModel(), storyTitle: "Something you aren't aware of in technology", storyAuthor: "skrillex", points: 24, totalCommentCount: 12, storyDate: "Date", storyId: "someID")
    }
}

struct ExtractedView: View {
    
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
        
        if isExpanded {
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
                
                if let text = commentText {
                    Text(text.toCleanHTML)
                }
                
                
                if commentReplies != nil {
                    ForEach(commentReplies!) { comment in
                        ExtractedView(commentText: comment.text ?? "Bad Comment", commentReplies: comment.commentChildren ?? nil, commentAuthor: comment.author ?? "Unknown", commentDate: comment.commentDate, indentLevel: indentLevel + 1)
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
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
        } else {
            VStack {
                
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
                
//                if let text = commentText {
//                    Text(text.toCleanHTML)
//                }
                
                
//                if commentReplies != nil {
//                    ForEach(commentReplies!) { comment in
//                        ExtractedView(commentText: comment.text ?? "Bad Comment", commentReplies: comment.commentChildren ?? nil, commentAuthor: comment.author ?? "Unknown", commentDate: comment.commentDate, indentLevel: indentLevel + 1, isExpanded: false)
//                            .overlay(
//                                Capsule()
//                                    .fill(Color.orange)
//                                    .frame(width: 1)
//                                    ,
//                                alignment: .leading
//                            )
//                    }
//                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
        }
        
        
        
    }
}
