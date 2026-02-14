import UIKit
import StoreKit

@MainActor
final class PaywallViewController: UIViewController {
    private let featureGate: ProFeatureGate
    private let subscriptionManager: SubscriptionManager

    private let stackView = UIStackView()
    private let statusLabel = UILabel()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let monthlyButton = UIButton(type: .system)
    private let yearlyButton = UIButton(type: .system)
    private let restoreButton = UIButton(type: .system)
    private let termsButton = UIButton(type: .system)
    private let privacyButton = UIButton(type: .system)

    init(featureGate: ProFeatureGate,
         subscriptionManager: SubscriptionManager = .shared) {
        self.featureGate = featureGate
        self.subscriptionManager = subscriptionManager
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "HackerPillar Pro"
        view.backgroundColor = UIColor(named: "BackgroundColor") ?? .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )

        configureLayout()
        configureButtons()

        Task {
            await loadPrices()
        }
    }

    private func configureLayout() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 14

        let headerLabel = UILabel()
        headerLabel.font = .preferredFont(forTextStyle: .title2)
        headerLabel.text = "Unlock Pro"
        headerLabel.numberOfLines = 0

        let benefitsLabel = UILabel()
        benefitsLabel.font = .preferredFont(forTextStyle: .body)
        benefitsLabel.numberOfLines = 0
        benefitsLabel.text = "• HN account login, vote, and reply\n• Offline reading\n• Advanced filters + smart feed\n• Enhanced reader mode"

        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0

        loadingIndicator.hidesWhenStopped = true

        let legalButtons = UIStackView(arrangedSubviews: [termsButton, privacyButton])
        legalButtons.axis = .horizontal
        legalButtons.spacing = 8
        legalButtons.distribution = .fillEqually

        [headerLabel, benefitsLabel, monthlyButton, yearlyButton, restoreButton, legalButtons, loadingIndicator, statusLabel].forEach {
            stackView.addArrangedSubview($0)
        }

        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
    }

    private func configureButtons() {
        monthlyButton.configuration = .filled()
        monthlyButton.configuration?.baseBackgroundColor = .systemOrange
        monthlyButton.configuration?.title = "Monthly"
        monthlyButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        monthlyButton.accessibilityLabel = "Buy monthly Pro plan"
        monthlyButton.addTarget(self, action: #selector(monthlyTapped), for: .touchUpInside)

        yearlyButton.configuration = .filled()
        yearlyButton.configuration?.baseBackgroundColor = .systemOrange
        yearlyButton.configuration?.title = "Yearly"
        yearlyButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        yearlyButton.accessibilityLabel = "Buy yearly Pro plan"
        yearlyButton.addTarget(self, action: #selector(yearlyTapped), for: .touchUpInside)

        restoreButton.configuration = .plain()
        restoreButton.configuration?.title = "Restore Purchases"
        restoreButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 10, bottom: 12, trailing: 10)
        restoreButton.accessibilityLabel = "Restore purchases"
        restoreButton.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)

        termsButton.configuration = .tinted()
        termsButton.configuration?.title = "Terms"
        termsButton.configuration?.baseForegroundColor = .systemOrange
        termsButton.addTarget(self, action: #selector(openTerms), for: .touchUpInside)
        termsButton.accessibilityLabel = "View terms of use"

        privacyButton.configuration = .tinted()
        privacyButton.configuration?.title = "Privacy"
        privacyButton.configuration?.baseForegroundColor = .systemOrange
        privacyButton.addTarget(self, action: #selector(openPrivacy), for: .touchUpInside)
        privacyButton.accessibilityLabel = "View privacy policy"

        [monthlyButton, yearlyButton, restoreButton, termsButton, privacyButton].forEach {
            $0.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        }

        let hasTerms = LegalLinks.termsURL != nil
        let hasPrivacy = LegalLinks.privacyURL != nil
        termsButton.isEnabled = hasTerms
        privacyButton.isEnabled = hasPrivacy
        if !hasTerms || !hasPrivacy {
            statusLabel.text = "Legal links are not configured yet."
        }
    }

    private func loadPrices() async {
        do {
            let products = try await subscriptionManager.products()
            if let monthly = products.first(where: { $0.id == SubscriptionManager.ProductID.monthly }) {
                monthlyButton.configuration?.title = "Monthly \(monthly.displayPrice)"
            }
            if let yearly = products.first(where: { $0.id == SubscriptionManager.ProductID.yearly }) {
                yearlyButton.configuration?.title = "Yearly \(yearly.displayPrice)"
            }
        } catch {
            statusLabel.text = messageForStoreError(error, action: "load prices")
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func monthlyTapped() {
        Task {
            await purchase(productID: SubscriptionManager.ProductID.monthly)
        }
    }

    @objc private func yearlyTapped() {
        Task {
            await purchase(productID: SubscriptionManager.ProductID.yearly)
        }
    }

    @objc private func restoreTapped() {
        Task {
            setLoading(true, message: "Restoring purchases…")
            do {
                let restored = try await subscriptionManager.restorePurchases()
                await featureGate.refreshEntitlement()
                if restored {
                    dismiss(animated: true)
                } else {
                    setLoading(false, message: "No active Pro subscription found.")
                }
            } catch {
                setLoading(false, message: messageForStoreError(error, action: "restore purchases"))
            }
        }
    }

    @objc private func openTerms() {
        guard let url = LegalLinks.termsURL else { return }
        UIApplication.shared.open(url)
    }

    @objc private func openPrivacy() {
        guard let url = LegalLinks.privacyURL else { return }
        UIApplication.shared.open(url)
    }

    private func purchase(productID: String) async {
        setLoading(true, message: "Processing purchase…")
        do {
            let outcome = try await subscriptionManager.purchase(productID: productID)
            switch outcome {
            case .success:
                await featureGate.refreshEntitlement()
                dismiss(animated: true)
            case .pending:
                setLoading(false, message: "Purchase is pending approval.")
            case .userCancelled:
                setLoading(false, message: "Purchase cancelled.")
            }
        } catch {
            setLoading(false, message: messageForStoreError(error, action: "complete purchase"))
        }
    }

    private func setLoading(_ isLoading: Bool, message: String?) {
        monthlyButton.isEnabled = !isLoading
        yearlyButton.isEnabled = !isLoading
        restoreButton.isEnabled = !isLoading

        if isLoading {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }

        statusLabel.text = message
    }

    private func messageForStoreError(_ error: Error, action: String) -> String {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain,
           nsError.code == NSURLErrorNotConnectedToInternet {
            return "You're offline. Connect to the internet to \(action)."
        }

        if nsError.domain == SKErrorDomain,
           let code = SKError.Code(rawValue: nsError.code) {
            switch code {
            case .paymentCancelled:
                return "Action cancelled."
            case .storeProductNotAvailable:
                return "This product is not available in your App Store region."
            case .cloudServiceNetworkConnectionFailed:
                return "App Store connection failed. Check your network and try again."
            case .overlayTimeout:
                return "App Store timed out. Please try again."
            default:
                break
            }
        }

        return "Could not \(action). Please try again."
    }
}
