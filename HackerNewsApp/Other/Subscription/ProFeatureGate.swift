import Foundation
import UIKit

@MainActor
final class ProFeatureGate: ObservableObject {
    static let shared = ProFeatureGate()

    @Published private(set) var isPro: Bool = false

    private let subscriptionManager: SubscriptionManager
    private let gracePeriod: TimeInterval = 7 * 24 * 60 * 60

    private var cachedDateProvider: () -> Date? = { nil }
    private var cacheDateUpdater: (Date?) -> Void = { _ in }

    private init(subscriptionManager: SubscriptionManager = .shared) {
        self.subscriptionManager = subscriptionManager
    }

    func configure(cachedDateProvider: @escaping () -> Date?,
                   cacheDateUpdater: @escaping (Date?) -> Void) {
        self.cachedDateProvider = cachedDateProvider
        self.cacheDateUpdater = cacheDateUpdater
    }

    func refreshEntitlement() async {
        let isCurrentlyPro = await subscriptionManager.hasActiveProEntitlement()
        if isCurrentlyPro {
            applyEntitlement(isPro: true, persistDate: Date())
            return
        }

        if let cachedAt = cachedDateProvider(),
           Date().timeIntervalSince(cachedAt) <= gracePeriod {
            applyEntitlement(isPro: true, persistDate: cachedAt)
            return
        }

        applyEntitlement(isPro: false, persistDate: nil)
    }

    func triggerPaywall(from presentingViewController: UIViewController?) {
        guard !isPro else { return }

        let paywallViewController = PaywallViewController(featureGate: self)
        let navController = UINavigationController(rootViewController: paywallViewController)
        navController.modalPresentationStyle = .pageSheet

        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }

        presentingViewController?.present(navController, animated: true)
    }

    private func applyEntitlement(isPro: Bool, persistDate: Date?) {
        self.isPro = isPro
        cacheDateUpdater(persistDate)
    }
}
