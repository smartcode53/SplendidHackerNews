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

    private let threadColors: [Color] = [
        Color.blue.opacity(0.6),
        Color.purple.opacity(0.6),
        Color.green.opacity(0.6),
        Color.orange.opacity(0.6),
        Color.pink.opacity(0.6),
        Color.cyan.opacity(0.6)
    ]

    private var threadColor: Color {
        threadColors[indentLevel % threadColors.count]
    }

    var body: some View {
        if threadVM.isVisible(comment.id) {
            HStack(alignment: .top, spacing: 0) {
                // Tappable thread indicator line
                if indentLevel > 0 {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            threadVM.toggleCollapse(comment.id)
                        }
                    } label: {
                        Rectangle()
                            .fill(threadColor)
                            .frame(width: 3)
                            .frame(maxHeight: .infinity)
                            .cornerRadius(1.5)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 16)
                }

                VStack(alignment: .leading, spacing: 0) {
                    if threadVM.isCollapsed(comment.id) {
                        // Collapsed summary
                        collapsedSummary
                    } else {
                        // Expanded comment
                        expandedComment
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color("CardColor"))
            .cornerRadius(12)
            .padding(.leading, CGFloat(indentLevel) * 16)
            .padding(.bottom, 8)
        }
    }
}

extension SingleCommentView {

    var collapsedSummary: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                threadVM.toggleCollapse(comment.id)
            }
        } label: {
            HStack(spacing: 8) {
                Text(comment.author ?? "Unknown")
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06), in: Capsule())

                let replyCount = threadVM.countDescendants(comment)
                if replyCount > 0 {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("\(replyCount) \(replyCount == 1 ? "reply" : "replies")")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    var expandedComment: some View {
        VStack(alignment: .leading, spacing: 0) {
            commentMetaInfo

            if let text = comment.text {
                Text(text.markdown)
                    .tint(.accentColor)
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            if let replies = comment.commentChildren {
                VStack(spacing: 0) {
                    ForEach(replies) { child in
                        if threadVM.isVisible(child.id) {
                            SingleCommentView(comment: child, threadVM: threadVM, indentLevel: indentLevel + 1)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    var commentMetaInfo: some View {
        HStack(spacing: 10) {
            Text(comment.author ?? "Unknown")
                .font(.callout.weight(.semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06), in: Capsule())

            Text("•")
                .foregroundColor(.secondary)
                .font(.callout)

            Text(Date.getTimeInterval(with: comment.createdAtI))
                .font(.callout)
                .foregroundColor(.secondary)

            Spacer()

#if DEBUG
            if globalSettings.isHNWriteEnabled && account.isLoggedIn {
                Button {
                    Task { await handleCommentVote(commentId: comment.id) }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .opacity(didVote ? 0.4 : 1)
                .disabled(didVote || isVoting)

                Button("Reply") {
                    showReplySheet = true
                }
                .buttonStyle(.plain)
                .font(.callout.weight(.medium))
                .foregroundColor(.secondary)
            }
#endif

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    threadVM.toggleCollapse(comment.id)
                }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.caption.weight(.semibold))
                    .rotationEffect(Angle(degrees: threadVM.isCollapsed(comment.id) ? 180 : 0))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
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
