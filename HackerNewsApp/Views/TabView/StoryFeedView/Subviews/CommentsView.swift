//
//  CommentsView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/26/22.
//

import SwiftUI

struct CommentsView<T>: View where T: CommentsButtonProtocol, T: SafariViewLoader {
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject var vm: T
    
    var body: some View {
        if let story = vm.story {
            VStack(spacing: 0) {
                
                ScrollView {
                    // Top section (Info Card with back navigation button)
                    VStack {
                        
                        // Domain, Title, and meta info
                        VStack(alignment: .leading, spacing: 0) {
                            if let urlDomain = story.url?.urlDomain {
                                Text(urlDomain)
                                    .foregroundColor(Color("PostDateName"))
                                    .font(.headline)
                                    .padding(.bottom, 5)
                            }
                            
                            Text(story.url == nil ? "\(story.title)" : "\(story.title) \(Image(systemName: "arrow.up.forward.app"))")
                                    .font(.title2.weight(.bold))
                                    .padding(.bottom, 12)
                                    .foregroundColor(Color("PostTitle"))
                                    .onTapGesture {
                                        vm.showStoryInComments = true
                                    }
                            
                            HStack {
                                Text(Date.getTimeInterval(with: story.time))
                                
                                Text("|")
                                    .foregroundColor(Color("DateNameSeparator"))
                                
                                Text(story.by)
                                
                                Spacer()
                            }
                            .foregroundColor(Color("PostDateName"))
                            .font(.subheadline)
                        }
                        .padding(.bottom, 35)
                        .padding(.horizontal)
                        .padding(.top)
                        
                        Rectangle()
                            .fill(.orange.opacity(0.21))
                            .frame(height: 2)
                        
                        // Points and Action Button
                        HStack {
                            if let points = story.score {
                                Text(points == 1 ? "\(points) point" : "\(points) points")
                                    .foregroundColor(.orange)
                                    .font(.subheadline.weight(.semibold))
                            }
                            
                            
                            Spacer()
                            
                            if let storyUrl = story.url {
                                ShareLink(item: storyUrl) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.title3.weight(.semibold))
                                }
//                                .createPressableButton()
                            }
                            
                            
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 5)
                        
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(Color("ButtonColor"))
                    }
                    .background(Color("CardColor"))
                    
                    // Comment count
                    if let commentCount = story.descendants {
                        HStack {
                            
                            Text(commentCount == 1 ? "\(commentCount) comment" : "\(commentCount) comments")
                                .padding()
                                .font(.title2.weight(.bold))
                            
                            Spacer()
                        }
                    }
                    
                    Group {
                        if let comments = vm.comments?.children {
                            LazyVStack {
                                ForEach(comments) { comment in
                                    if let _ = comment.text {
                                        SingleCommentView(comment: comment)
                                    }
                                }
                            }
                        } else {
                            ProgressView()
                        }
                    }
                    .background(Color("BackgroundColor"))
                    .onAppear {
                        vm.loadComments(withId: story.id)
                    }
                    .task {
                        if vm.comments != nil {
                            if let (numComments, points) = await vm.getCommentAndPointCounts(forPostWithId: story.id) {
                                vm.story?.descendants = numComments
                                vm.story?.score = points
                            }
                        }
                    }
                    
                        
                    
                    
                    
                    Spacer()
                }
                
            }
            .background(Color("BackgroundColor"))
            .fullScreenCover(isPresented: $vm.showStoryInComments) {
                SafariView(vm: vm, url: story.url)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color("NavigationBarColor"), for: .navigationBar)
        }
    }
}
