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
    @State var urlDomain: String?
    @State var isExpanded = true
    @GestureState var dragOffset = CGSize.zero
    
    let storyTitle: String
    let storyAuthor: String
    let points: Int
    let totalCommentCount: Int?
    let storyDate: Int
    let storyId: String
    let storyUrl: String?
    
    var body: some View {
        
        VStack(spacing: 0) {
            
            // Navigation Back Button
            HStack {
                
                Image(systemName: "arrow.left")
                    .font(.title.weight(.semibold))
                    .foregroundColor(.primary)
                    .onTapGesture {
                        dismiss()
                    }
                
                Spacer()
            }
            .padding(.bottom, 30)
            .padding(.leading, 10)
            .background(Color("CardColor"))
            
            ScrollView {
                // Top section (Info Card with back navigation button)
                VStack {
                    
                    // Domain, Title, and meta info
                    VStack(alignment: .leading, spacing: 0) {
                        if let urlDomain {
                            Text(urlDomain)
                                .foregroundColor(Color("PostDateName"))
                                .font(.headline)
                                .padding(.bottom, 5)
                        }
                        
                        Text(storyUrl == nil ? "\(storyTitle)" : "\(storyTitle) \(Image(systemName: "arrow.up.forward.app"))")
                            .font(.title2.weight(.bold))
                            .padding(.bottom, 12)
                            .foregroundColor(Color("PostTitle"))
                            .onTapGesture {
                                vm.showStoryInComments = true
                            }
                        
                        HStack {
                            Text(Date.getTimeInterval(with: storyDate))
                            Text("|")
                                .foregroundColor(Color("DateNameSeparator"))
                            Text(storyAuthor)
                            
                            Spacer()
                        }
                        .foregroundColor(Color("PostDateName"))
                        .font(.subheadline)
                    }
                    .padding(.bottom, 35)
                    .padding(.horizontal)
                    
                    Rectangle()
                        .fill(.orange.opacity(0.21))
                        .frame(height: 2)
                    
                    // Points and Action Button
                    HStack {
                        Text(points == 1 ? "\(points) point" : "\(points) points")
                            .foregroundColor(.orange)
                            .font(.headline)
                        
                        Spacer()
                        
                        if let storyUrl {
                            ShareLink(item: storyUrl) {
                                Image(systemName: "square.and.arrow.up.fill")
                            }
                            .createPressableButton()
                        }
                        
                        
                    }
                    .padding()
                    
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(.primary)
                }
                .background(Color("CardColor"))
                
                // Comment count
                HStack {
                    Text("\(totalCommentCount ?? 0) comments")
                        .padding()
                        .font(.title2.weight(.bold))
                    
                    Spacer()
                }
                
                VStack {
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
                .background(Color("BackgroundColor"))
                .task {
                    do {
                        comments = try await vm.getComments(for: storyId)
                    } catch let error {
                        print("Error fetching data using task modifier on CommentsView: \(error)")
                    }
                }
                
                Spacer()
            }
            
            
            
        }
        .background(Color("BackgroundColor"))
        .onAppear {
            if let storyUrl {
                urlDomain = vm.getUrlDomain(for: storyUrl)
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
        
//        ZStack {
//
//            Color.orange
//                .ignoresSafeArea()
//
//            VStack {
//
//                backButton
//
//                ScrollView {
//
//                    titlePalate
//
//                    metaInfoPalate
//
             
//                }
//            }
//
            
//        }
    }
}

struct CommentsView_Previews: PreviewProvider {
    static var previews: some View {
        CommentsView(vm: MainViewModel(), storyTitle: "Something you aren't aware of in technology", storyAuthor: "skrillex", points: 24, totalCommentCount: 12, storyDate: 343434525, storyId: "someID", storyUrl: "google.com")
    }
}


