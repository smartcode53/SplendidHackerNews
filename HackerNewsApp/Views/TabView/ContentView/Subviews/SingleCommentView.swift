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
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
#if DEBUG
    @EnvironmentObject var account: HNAccount
#endif
    @State private var showReplySheet = false
    @State private var showVoteAlert = false
    @State private var voteAlertMessage = ""
    @State private var didVote = false
    @State private var isVoting = false
    
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

#if DEBUG
            if globalSettings.isHNWriteEnabled && account.isLoggedIn {
                Button {
                    Task { await handleCommentVote(commentId: comment.id) }
                } label: {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .opacity(didVote ? 0.4 : 1)
                .disabled(didVote || isVoting)

                Button("Reply") {
                    showReplySheet = true
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
#endif

            Button {
                withAnimation(.easeInOut) {
                    threadVM.toggleCollapse(comment.id)
                }
            } label: {
                Image(systemName: "chevron.up")
                    .rotationEffect(Angle(degrees: threadVM.isCollapsed(comment.id) ? 180 : 0))
            }
            .buttonStyle(.plain)
        }
        .font(.callout)
        .background(Color("CardColor"))
        .padding(.bottom, 10)
        .foregroundColor(.secondary)
#if DEBUG
        .sheet(isPresented: $showReplySheet) {
            HNReplySheet(commentId: comment.id, storyId: comment.storyId)
                .environmentObject(account)
        }
#endif
        .alert("Vote", isPresented: $showVoteAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(voteAlertMessage)
        }
    }
}

#if DEBUG
extension SingleCommentView {
    @MainActor
    private func handleCommentVote(commentId: Int) async {
        guard !isVoting else { return }
        isVoting = true
        didVote = true
        do {
            let result = try await account.upvoteComment(id: commentId)
            switch result {
            case .voted:
                break
            case .alreadyVoted:
                voteAlertMessage = "Already voted."
                showVoteAlert = true
            case .verificationFailed:
                didVote = false
                voteAlertMessage = "Vote sent, but verification failed."
                showVoteAlert = true
            }
        } catch {
            didVote = false
            voteAlertMessage = error.localizedDescription
            showVoteAlert = true
            HNDebugLog.error("Comment upvote failed: \(error)")
        }
        isVoting = false
    }
}
#endif
