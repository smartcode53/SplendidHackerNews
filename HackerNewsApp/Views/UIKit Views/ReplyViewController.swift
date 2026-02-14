import UIKit

@MainActor
final class ReplyViewController: UIViewController {
    private let commentId: Int
    private let storyId: Int?
    private let account: HNAccount

    private let textView = UITextView()
    private let statusLabel = UILabel()
    private let postButton = UIButton(type: .system)

    convenience init(commentId: Int, storyId: Int?) {
        self.init(commentId: commentId, storyId: storyId, account: HNAccount.shared)
    }

    init(commentId: Int, storyId: Int?, account: HNAccount) {
        self.commentId = commentId
        self.storyId = storyId
        self.account = account
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Reply"
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )

        configureLayout()
        configureActions()
    }

    private func configureLayout() {
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = .preferredFont(forTextStyle: .body)
        textView.backgroundColor = UIColor(named: "CardColor") ?? .secondarySystemBackground
        textView.layer.cornerRadius = 12
        textView.layer.cornerCurve = .continuous

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0

        postButton.translatesAutoresizingMaskIntoConstraints = false
        postButton.configuration = .filled()
        postButton.configuration?.baseBackgroundColor = .systemOrange
        postButton.configuration?.title = "Post Reply"

        view.addSubview(textView)
        view.addSubview(statusLabel)
        view.addSubview(postButton)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.heightAnchor.constraint(equalToConstant: 220),

            statusLabel.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor),

            postButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            postButton.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            postButton.trailingAnchor.constraint(equalTo: textView.trailingAnchor)
        ])
    }

    private func configureActions() {
        postButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            Task {
                await self.postReply()
            }
        }, for: .touchUpInside)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    private func postReply() async {
        let body = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else {
            statusLabel.text = "Reply cannot be empty."
            return
        }

        setSubmitting(true)
        defer { setSubmitting(false) }

        do {
            let result = try await account.reply(to: commentId, storyId: storyId, text: body, nonce: nil)
            switch result {
            case .posted, .verificationFailed:
                dismiss(animated: true)
            }
        } catch {
            statusLabel.text = error.localizedDescription
        }
    }

    private func setSubmitting(_ submitting: Bool) {
        textView.isEditable = !submitting
        postButton.isEnabled = !submitting
        if submitting {
            statusLabel.text = "Posting..."
        }
    }
}
