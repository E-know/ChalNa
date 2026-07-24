import ComposableArchitecture
import Foundation
import StoreKit

/// StoreKit 2 기반 live 구현. 모든 호출은 Swift Concurrency 로만 동작한다.
extension SubscriptionClient: DependencyKey {
    public static let liveValue: SubscriptionClient = {
        let cache = LockIsolated(false)

        @Sendable func weeklyProduct() async throws -> Product {
            guard let product = try await Product.products(for: [SubscriptionConstants.weeklyProductID]).first else {
                throw SubscriptionError.productNotFound
            }
            return product
        }

        @Sendable func hasActiveEntitlement() async -> Bool {
            for await result in Transaction.currentEntitlements {
                guard case let .verified(transaction) = result else { continue }
                if transaction.productID == SubscriptionConstants.weeklyProductID,
                   transaction.revocationDate == nil {
                    cache.setValue(true)
                    return true
                }
            }
            cache.setValue(false)
            return false
        }

        return SubscriptionClient(
            loadProduct: {
                let product = try await weeklyProduct()
                let intro = product.subscription?.introductoryOffer
                let trialDays: Int = {
                    guard let intro, intro.paymentMode == .freeTrial else { return 0 }
                    switch intro.period.unit {
                    case .day:  return intro.period.value
                    case .week: return intro.period.value * 7
                    default:    return 0
                    }
                }()
                return SubscriptionProduct(
                    id: product.id,
                    displayName: product.displayName,
                    displayPrice: product.displayPrice,
                    hasFreeTrial: trialDays > 0,
                    trialDays: trialDays
                )
            },
            purchase: {
                let product = try await weeklyProduct()
                let result = try await product.purchase()
                switch result {
                case let .success(verification):
                    guard case let .verified(transaction) = verification else {
                        throw SubscriptionError.unverifiedTransaction
                    }
                    await transaction.finish()
                    cache.setValue(true)
                    return .success
                case .userCancelled:
                    return .cancelled
                case .pending:
                    return .pending
                @unknown default:
                    return .cancelled
                }
            },
            restore: {
                try await AppStore.sync()
                return await hasActiveEntitlement()
            },
            isSubscribed: { await hasActiveEntitlement() },
            isSubscribedCached: { cache.value }
        )
    }()
}
