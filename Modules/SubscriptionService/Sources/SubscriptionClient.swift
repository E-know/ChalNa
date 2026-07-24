import ComposableArchitecture
import Foundation

/// 주간 구독 상품의 표시 정보. 실제 값은 StoreKit(Product)에서 로드한다.
public struct SubscriptionProduct: Equatable, Sendable {
    public let id: String
    public let displayName: String
    /// 지역화된 가격 문자열 (예: "₩1,500").
    public let displayPrice: String
    public let hasFreeTrial: Bool
    public let trialDays: Int

    public init(id: String, displayName: String, displayPrice: String, hasFreeTrial: Bool, trialDays: Int) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.hasFreeTrial = hasFreeTrial
        self.trialDays = trialDays
    }
}

public enum PurchaseOutcome: Equatable, Sendable {
    case success
    case cancelled
    case pending
}

public enum SubscriptionConstants {
    public static let weeklyProductID = "ios.inho.ChalNa.pro.weekly"
}

public enum SubscriptionError: LocalizedError, Equatable {
    case productNotFound
    case unverifiedTransaction

    public var errorDescription: String? {
        switch self {
        case .productNotFound:      return String(localized: "구독 상품 정보를 불러오지 못했어요.")
        case .unverifiedTransaction: return String(localized: "구매를 확인하지 못했어요. 다시 시도해주세요.")
        }
    }
}

@DependencyClient
public struct SubscriptionClient: Sendable {
    public var loadProduct: @Sendable () async throws -> SubscriptionProduct
    public var purchase: @Sendable () async throws -> PurchaseOutcome
    /// AppStore.sync 후 활성 entitlement 존재 여부.
    public var restore: @Sendable () async throws -> Bool
    public var isSubscribed: @Sendable () async -> Bool = { false }
    /// 리듀서 동기 컨텍스트용 캐시 (isSubscribed/purchase 가 갱신).
    public var isSubscribedCached: @Sendable () -> Bool = { false }
    /// 앱 수명 동안 StoreKit 트랜잭션 업데이트(갱신·환불·승인 완료)를 관찰하고 finish 한다.
    /// 앱 시작 시 1회 호출해 장기 실행 — AppFeature `.task` 에서 구동.
    public var observeTransactionUpdates: @Sendable () async -> Void = {}
}

extension SubscriptionClient: TestDependencyKey {
    public static let testValue = SubscriptionClient()
    public static let previewValue = SubscriptionClient(
        loadProduct: {
            SubscriptionProduct(
                id: SubscriptionConstants.weeklyProductID,
                displayName: "ChalNa Pro",
                displayPrice: "₩1,500",
                hasFreeTrial: true,
                trialDays: 3
            )
        },
        purchase: { .success },
        restore: { false },
        isSubscribed: { false },
        isSubscribedCached: { false },
        observeTransactionUpdates: {}
    )
}

public extension DependencyValues {
    var subscriptionClient: SubscriptionClient {
        get { self[SubscriptionClient.self] }
        set { self[SubscriptionClient.self] = newValue }
    }
}
