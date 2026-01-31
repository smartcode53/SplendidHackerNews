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
    @StateObject private var threadVM = CommentsThreadViewModel()
    @State private var searchText = ""
    @State private var currentTopIndex = 0
    
    
    var body: some View {
        if let story = vm.story {
            VStack(spacing: 0) {
                
                ScrollViewReader { proxy in
                    ScrollView {
                    // Top section (Info Card with back navigation button)
                    VStack {
                        
                        // Domain, Title, and meta info
                        VStack(alignment: .leading, spacing: 0) {
                            if let urlDomain = story.url?.urlDomain {
                                Text(urlDomain)
                                    .foregroundColor(.accentColor)
                                    .font(.caption.weight(.semibold))
                                    .padding(.bottom, 5)
                            }
                            
                            Text(story.url == nil ? "\(story.title)" : "\(story.title) \(Image(systemName: "arrow.up.forward.app"))")
                                    .font(.title3.weight(.semibold))
                                    .padding(.bottom, 12)
                                    .foregroundColor(.primary)
                                    .onTapGesture {
                                        vm.showStoryInComments = true
                                    }
                            
                            HStack {
                                Text(Date.getTimeInterval(with: story.time))
                                
                                Text("|")
                                    .foregroundColor(.secondary)
                                
                                Text(story.by)
                                
                                Spacer()
                            }
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        }
                        .padding(.bottom, 35)
                        .padding(.horizontal)
                        .padding(.top)
                        
                        Divider()
                        
                        // Points and Action Button
                        HStack {
                                Text(story.score == 1 ? "\(story.score) point" : "\(story.score) points")
                                    .foregroundColor(.secondary)
                                    .font(.headline)
                            
                            
                            Spacer()
                            
                            if let storyUrl = story.url {
                                ShareLink(item: storyUrl) {
                                    Image(systemName: "square.and.arrow.up")
                                }
                                .createPressableButton()
                            }
                            
                            
                        }
                        .padding()
                        
                        Divider()
                    }
                    .background(Color("CardColor"))
                    .padding(.bottom, 8)
                    
                    commentControls(proxy: proxy)
                    
                    // Comment count
                    if let commentCount = story.descendants {
                        HStack {
                            
                            Text(commentCount == 1 ? "\(commentCount) comment" : "\(commentCount) comments")
                                .padding()
                                .font(.title3.weight(.semibold))
                            
                            Spacer()
                        }
                    }
                    
                    
                    VStack {
                        if let comments = vm.comments?.children {
                            LazyVStack {
                                ForEach(comments) { comment in
                                    if threadVM.isVisible(comment.id) {
                                        SingleCommentView(comment: comment, threadVM: threadVM, indentLevel: 0)
                                            .id(comment.id)
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
                
            }
            .background(Color("BackgroundColor"))
            .navigationBarTitleDisplayMode(.inline)
            .background(
                NavigationLink(destination: SafariView(vm: vm, url: story.url), isActive: $vm.showStoryInComments) {
                    EmptyView()
                }
                .hidden()
            )
        }
    }
}

extension CommentsView {
    @ViewBuilder
    private func commentControls(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button("Prev") {
                    let ids = currentTopIDs()
                    guard !ids.isEmpty else { return }
                    currentTopIndex = max(currentTopIndex - 1, 0)
                    proxy.scrollTo(ids[currentTopIndex], anchor: .top)
                }
                .buttonStyle(.bordered)
                
                Text(topIndexLabel())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button("Next") {
                    let ids = currentTopIDs()
                    guard !ids.isEmpty else { return }
                    currentTopIndex = min(currentTopIndex + 1, ids.count - 1)
                    proxy.scrollTo(ids[currentTopIndex], anchor: .top)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Collapse All") {
                    threadVM.collapseTopLevel()
                }
                .buttonStyle(.bordered)
                
                Button("Expand All") {
                    threadVM.expandTopLevel()
                }
                .buttonStyle(.bordered)
            }
            
            HStack {
                TextField("Search comments", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            if !searchText.isEmpty {
                HStack {
                    Text("\(threadVM.matchCount) matches")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .task(id: searchText) {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if let comments = vm.comments?.children {
                threadVM.setComments(comments)
                threadVM.applySearch(query: searchText)
                currentTopIndex = 0
            }
        }
        .onChange(of: vm.comments?.children?.count ?? 0) { _ in
            if let comments = vm.comments?.children {
                threadVM.setComments(comments)
                currentTopIndex = 0
            }
        }
    }
    
    private func currentTopIDs() -> [Int] {
        let ids = threadVM.visibleTopLevelIDs
        return ids.isEmpty ? threadVM.topLevelIDs : ids
    }
    
    private func topIndexLabel() -> String {
        let ids = currentTopIDs()
        guard !ids.isEmpty else { return "0/0" }
        let index = min(currentTopIndex + 1, ids.count)
        return "\(index)/\(ids.count)"
    }
}
