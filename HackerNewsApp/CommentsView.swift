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
    
    @State var isExpanded = true
    
    let storyTitle: String
    let storyAuthor: String
    let points: Int
    let totalCommentCount: Int
    let storyDate: String
    let storyId: String
    let storyUrl: String
    
    
    
    
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
                        
                        if let urlDomain = vm.getUrlDomain(for: storyUrl) {
                            Text(urlDomain)
                                .font(.headline)
                                .foregroundColor(.black.opacity(0.5))
                        }
                        
                        
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
                
                ScrollView {
                    ForEach(comments) { comment in
                        SingleCommentView(commentText: comment.text ?? "No Comment", commentReplies: comment.commentChildren ?? nil, commentAuthor: comment.author ?? "Unknown", commentDate: comment.commentDate)
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
        CommentsView(vm: MainViewModel(), storyTitle: "Something you aren't aware of in technology", storyAuthor: "skrillex", points: 24, totalCommentCount: 12, storyDate: "Date", storyId: "someID", storyUrl: "google.com")
    }
}


