import Foundation
import StoreKit

actor SubscriptionManager {
    static let shared = SubscriptionManager()

    enum ProductID {
        static let monthly = "hackerpillar.pro.monthly"
        static let yearly = "hackerpillar.pro.yearly"

        static let all = [monthly, yearly]
    }

    enum PurchaseOutcome {
        case success
        case pending
        case userCancelled
    }

    private var productsCache: [Product] = []
    private var updatesTask: Task<Void, Never>?

    deinit {
        updatesTask?.cancel()
    }

    func startTransactionListener(onEntitlementChange: (@Sendable () async -> Void)? = nil) {
        guard updatesTask == nil else { return }

        updatesTask = Task.detached(priority: .background) {
            for await update in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(update)
                    guard ProductID.all.contains(transaction.productID) else { continue }
                    await transaction.finish()
                    await onEntitlementChange?()
                } catch {
                    continue
                }
            }
        }
    }

    func products() async throws -> [Product] {
        if !productsCache.isEmpty {
            return productsCache
        }

        let loaded = try await Product.products(for: ProductID.all)
        let sorted = loaded.sorted { lhs, rhs in
            if lhs.id == ProductID.yearly { return false }
            if rhs.id == ProductID.yearly { return true }
            return lhs.displayPrice < rhs.displayPrice
        }
        productsCache = sorted
        return sorted
    }

    func hasActiveProEntitlement() async -> Bool {
        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(entitlement) else { continue }
            guard ProductID.all.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }

            if let expirationDate = transaction.expirationDate {
                if expirationDate > Date() {
                    return true
                }
            } else {
                return true
            }
        }

        return false
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        let products = try await products()
        guard let product = products.first(where: { $0.id == productID }) else {
            throw NSError(domain: "SubscriptionManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Product not found."])
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
            return .success
        case .pending:
            return .pending
        case .userCancelled:
            return .userCancelled
        @unknown default:
            return .pending
        }
    }

    func restorePurchases() async throws -> Bool {
        try await AppStore.sync()
        return await hasActiveProEntitlement()
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw NSError(domain: "SubscriptionManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Transaction verification failed."])
        }
    }
}
