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
            isSubscribed: {
                // 런치 게이트가 이 호출을 기다린다 — StoreKit 데몬 무응답(설정 미부착 시뮬레이터,
                // 드문 XPC 장애)에 무한 대기하지 않도록 3초 타임아웃. 타임아웃 = 미구독 취급(fail-closed).
                await withTaskGroup(of: Bool?.self) { group in
                    group.addTask { await hasActiveEntitlement() }
                    group.addTask {
                        try? await Task.sleep(for: .seconds(3))
                        return nil
                    }
                    let first = await group.next() ?? nil
                    group.cancelAll()
                    return first ?? false
                }
            },
            isSubscribedCached: { cache.value },
            observeTransactionUpdates: {
                for await result in Transaction.updates {
                    guard case let .verified(transaction) = result else { continue }
                    if transaction.productID == SubscriptionConstants.weeklyProductID {
                        cache.setValue(transaction.revocationDate == nil)
                    }
                    await transaction.finish()
                }
            }
        )
    }()
}
