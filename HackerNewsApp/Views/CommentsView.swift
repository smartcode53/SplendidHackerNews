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
    @GestureState var dragOffset = CGSize.zero
    
    let storyTitle: String
    let storyAuthor: String
    let points: Int
    let totalCommentCount: Int
    let storyDate: Int
    let storyId: String
    let storyUrl: String
    
    var body: some View {
        ZStack {
            
            Color.orange
                .ignoresSafeArea()
            
            VStack {
                
                backButton
                
                ScrollView {
                    
                    titlePalate
                    
                    metaInfoPalate
                    
                    if vm.isLoadingComments {
                        ProgressView()
                    } else {
                        LazyVStack {
                            ForEach(comments) { comment in
                                if let commentText = comment.text {
                                    SingleCommentView(vm: vm, commentText: commentText, commentReplies: comment.commentChildren ?? nil, commentAuthor: comment.author ?? "Unknown", commentDate: comment.createdAtI)
                                }
                            }
                        }
                    }
                }
            }
            
            .task {
                do {
                    comments = try await vm.getComments(for: storyId)
                } catch let error {
                    print("Error fetching data using task modifier on CommentsView: \(error)")
                }
            }
        }
        .fullScreenCover(isPresented: $vm.showStoryInComments) {
            SafariView(vm: vm, url: storyUrl)
        }
        .toolbar(.hidden, in: .navigationBar)
        .gesture(DragGesture().updating($dragOffset, body: { value, state, transaction in
            if value.startLocation.x < 20 && value.translation.width > 100 {
                dismiss()
            }
        }))
    }
}

struct CommentsView_Previews: PreviewProvider {
    static var previews: some View {
        CommentsView(vm: MainViewModel(), storyTitle: "Something you aren't aware of in technology", storyAuthor: "skrillex", points: 24, totalCommentCount: 12, storyDate: 343434525, storyId: "someID", storyUrl: "google.com")
    }
}


