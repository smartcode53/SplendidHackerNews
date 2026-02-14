import UIKit
import Combine

@MainActor
final class HNAccountViewController: UIViewController {
    private let account: HNAccount
    private let proFeatureGate: ProFeatureGate

    private var cancellables: Set<AnyCancellable> = []

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    private let proTeaserCard = UIView()
    private let proTeaserLabel = UILabel()
    private let unlockButton = UIButton(type: .system)

    private let statusCard = UIView()
    private let statusLabel = UILabel()
    private let karmaLabel = UILabel()
    private let verifyButton = UIButton(type: .system)
    private let signOutButton = UIButton(type: .system)

    private let loginCard = UIView()
    private let usernameField = UITextField()
    private let passwordField = UITextField()
    private let signInButton = UIButton(type: .system)

    private let messageLabel = UILabel()

    convenience init() {
        self.init(account: HNAccount.shared, proFeatureGate: ProFeatureGate.shared)
    }

    init(account: HNAccount, proFeatureGate: ProFeatureGate) {
        self.account = account
        self.proFeatureGate = proFeatureGate
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "HN Account"
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        configureLayout()
        configureActions()
        bindState()
        refreshUI()

        Task {
            _ = await account.verifySession()
            await refreshKarmaIfNeeded()
        }
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 14
        stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor)
        ])

        configureProTeaserCard()
        configureStatusCard()
        configureLoginCard()

        messageLabel.font = .preferredFont(forTextStyle: .footnote)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0

        stackView.addArrangedSubview(proTeaserCard)
        stackView.addArrangedSubview(statusCard)
        stackView.addArrangedSubview(loginCard)
        stackView.addArrangedSubview(messageLabel)
    }

    private func configureProTeaserCard() {
        styleCard(proTeaserCard)

        proTeaserLabel.font = .preferredFont(forTextStyle: .body)
        proTeaserLabel.numberOfLines = 0
        proTeaserLabel.text = "HN account actions are a Pro feature. Upgrade to unlock login, voting, and replies."

        unlockButton.configuration = .filled()
        unlockButton.configuration?.baseBackgroundColor = .systemOrange
        unlockButton.configuration?.title = "Unlock Pro"

        let stack = UIStackView(arrangedSubviews: [proTeaserLabel, unlockButton])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        proTeaserCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: proTeaserCard.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: proTeaserCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: proTeaserCard.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: proTeaserCard.bottomAnchor, constant: -14)
        ])
    }

    private func configureStatusCard() {
        styleCard(statusCard)

        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.numberOfLines = 0

        karmaLabel.font = .preferredFont(forTextStyle: .subheadline)
        karmaLabel.textColor = .secondaryLabel
        karmaLabel.numberOfLines = 1

        verifyButton.configuration = .filled()
        verifyButton.configuration?.baseBackgroundColor = .systemOrange
        verifyButton.configuration?.title = "Verify Session"

        signOutButton.configuration = .plain()
        signOutButton.configuration?.title = "Sign Out"

        let buttons = UIStackView(arrangedSubviews: [verifyButton, signOutButton])
        buttons.axis = .horizontal
        buttons.spacing = 10

        let stack = UIStackView(arrangedSubviews: [statusLabel, karmaLabel, buttons])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        statusCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: statusCard.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: -14)
        ])
    }

    private func configureLoginCard() {
        styleCard(loginCard)

        usernameField.borderStyle = .roundedRect
        usernameField.autocapitalizationType = .none
        usernameField.autocorrectionType = .no
        usernameField.placeholder = "HN username"

        passwordField.borderStyle = .roundedRect
        passwordField.isSecureTextEntry = true
        passwordField.placeholder = "HN password"

        signInButton.configuration = .filled()
        signInButton.configuration?.baseBackgroundColor = .systemOrange
        signInButton.configuration?.title = "Sign In"

        let stack = UIStackView(arrangedSubviews: [usernameField, passwordField, signInButton])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        loginCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: loginCard.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: loginCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: loginCard.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: loginCard.bottomAnchor, constant: -14)
        ])
    }

    private func styleCard(_ card: UIView) {
        card.backgroundColor = UIColor(named: "CardColor") ?? .secondarySystemBackground
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous
    }

    private func configureActions() {
        unlockButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.proFeatureGate.triggerPaywall(from: self)
        }, for: .touchUpInside)

        verifyButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            Task {
                _ = await self.account.verifySession()
                await self.refreshKarmaIfNeeded()
            }
        }, for: .touchUpInside)

        signOutButton.addAction(UIAction { [weak self] _ in
            self?.account.signOut()
        }, for: .touchUpInside)

        signInButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            Task {
                await self.signInTapped()
            }
        }, for: .touchUpInside)
    }

    private func bindState() {
        proFeatureGate.$isPro
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshUI()
            }
            .store(in: &cancellables)

        account.$isLoggedIn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.refreshKarmaIfNeeded() }
                self?.refreshUI()
            }
            .store(in: &cancellables)

        account.$username
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshUI()
            }
            .store(in: &cancellables)

        account.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.messageLabel.text = error
            }
            .store(in: &cancellables)
    }

    private func refreshUI() {
        let isPro = proFeatureGate.isPro
        let isLoggedIn = account.isLoggedIn

        proTeaserCard.isHidden = isPro
        statusCard.isHidden = !isPro
        loginCard.isHidden = !isPro || isLoggedIn

        if isLoggedIn {
            statusLabel.text = "Logged in as \(account.username ?? "Unknown")"
        } else {
            statusLabel.text = isPro ? "Not logged in" : "Pro required"
            karmaLabel.text = nil
        }

        verifyButton.isEnabled = isPro
        signOutButton.isEnabled = isPro && isLoggedIn
    }

    private func signInTapped() async {
        let username = usernameField.text ?? ""
        let password = passwordField.text ?? ""

        setSubmitting(true)
        defer { setSubmitting(false) }

        do {
            _ = try await account.login(username: username, password: password)
            passwordField.text = nil
            messageLabel.text = "Logged in."
            await refreshKarmaIfNeeded()
        } catch {
            messageLabel.text = error.localizedDescription
        }
    }

    private func refreshKarmaIfNeeded() async {
        guard account.isLoggedIn, let username = account.username else {
            karmaLabel.text = nil
            return
        }
        let karma = await account.fetchKarma(for: username)
        if let karma {
            karmaLabel.text = "Karma: \(karma)"
        } else {
            karmaLabel.text = "Karma: unavailable"
        }
    }

    private func setSubmitting(_ submitting: Bool) {
        signInButton.isEnabled = !submitting
        verifyButton.isEnabled = !submitting
        if submitting {
            messageLabel.text = "Working..."
        }
    }
}
