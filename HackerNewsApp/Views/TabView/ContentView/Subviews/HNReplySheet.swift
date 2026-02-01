import SwiftUI

struct HNReplySheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var account: HNAccount

    let commentId: Int
    let storyId: Int?

    @State private var text = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextEditor(text: $text)
                    .frame(minHeight: 180)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Reply")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Submitting" : "Submit") {
                        submitReply()
                    }
                    .disabled(isSubmitting || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func submitReply() {
        errorMessage = nil
        isSubmitting = true
        let payload = text.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let nonce = DebugNonce.makeNonce()
                let finalText = DebugNonce.appendNonceIfNeeded(payload, nonce: nonce)
                let result = try await account.reply(to: commentId, storyId: storyId, text: finalText, nonce: nonce)
                if result == .verificationFailed {
                    errorMessage = "Reply sent, but verification failed."
                    isSubmitting = false
                    return
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                HNDebugLog.error("Reply failed: \(error)")
            }
            isSubmitting = false
        }
    }
}

private enum DebugNonce {
    static func makeNonce() -> String? {
        #if DEBUG
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let token = String((0..<6).compactMap { _ in letters.randomElement() })
        return "HP-\(token)"
        #else
        return nil
        #endif
    }

    static func appendNonceIfNeeded(_ text: String, nonce: String?) -> String {
        guard let nonce else { return text }
        return "\(text) \(nonce)"
    }
}
