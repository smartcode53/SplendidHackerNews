//
//  CommentsView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/26/22.
//

import SwiftUI

struct CommentsView<T>: View where T: CommentsButtonProtocol, T: SafariViewLoader, T: CustomPullToRefresh {
    
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    @Environment(\.dismiss) var dismiss
    @ObservedObject var vm: T
    
    var body: some View {
        if let story = vm.story {
            VStack(spacing: 0) {
                
                ScrollView {
                    infoCard
                    
                    // Comment count
                    commentCount
                    
                    recursiveComments
                        .background(Color("BackgroundColor"))
                        .onAppear {
                            vm.loadComments(withId: story.id) { error in
                                if let error {
                                    let errorType = ErrorType(error: error)
                                    globalSettings.toastText = errorType.error.localizedDescription
                                    globalSettings.toastTextColor = .black
                                    globalSettings.appError = errorType
                                }
                            }
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
                .overlay(alignment: .bottomTrailing) {
                    DragToRefreshView(refreshFunc: vm.refresh)
                        .padding()
                }
                
            }
            .background(Color("BackgroundColor"))
            .fullScreenCover(isPresented: $vm.showStoryInComments) {
                SafariView(vm: vm, url: story.url)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color("NavigationBarColor"), for: .navigationBar)
            .onChange(of: vm.subToastText) { newValue in
                globalSettings.toastText = newValue
            }
            .onChange(of: vm.subError) { newValue in
                globalSettings.appError = newValue
            }
        }
    }
}


extension CommentsView {
    
    var infoCard: some View {
        VStack {
            if let story = vm.story {
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
                        .createRegularButton()
                    }
                    
                    
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 5)
                
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(Color("ButtonColor"))
            }
        }
        .background(Color("CardColor"))
    }
    
    @ViewBuilder var commentCount: some View {
        if let story = vm.story,
           let commentCount = story.descendants {
            HStack {
                
                Text(commentCount == 1 ? "\(commentCount) comment" : "\(commentCount) comments")
                    .padding()
                    .font(.title2.weight(.bold))
                
                Spacer()
            }
        }
    }
    
    @ViewBuilder var recursiveComments: some View {
        if let comments = vm.comments?.children,
           let storyAuthor = vm.story?.by {
            LazyVStack {
                ForEach(comments) { comment in
                    if let _ = comment.text {
                        SingleCommentView(comment: comment, storyAuthor: storyAuthor)
                    }
                }
            }
        } else {
            ProgressView()
        }
    }
    
}
