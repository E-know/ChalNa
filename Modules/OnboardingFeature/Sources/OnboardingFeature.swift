import ComposableArchitecture
import AnalyticsService
import Foundation
import SubscriptionService

public enum OnboardingMode: Equatable, Sendable {
    /// 첫 실행: 가치 소개 페이지부터.
    case full
    /// 재실행(온보딩은 봤지만 미구독): 페이월만.
    case paywallOnly
}

/// 맞춤 질문 페이지의 관심사. rawValue 가 appStorage/analytics 에 저장된다.
public enum OnboardingInterest: String, CaseIterable, Equatable, Sendable {
    case travel, daily, family, pet

    public var koreanName: String {
        switch self {
        case .travel: return "여행"
        case .daily:  return "일상"
        case .family: return "가족 · 아이"
        case .pet:    return "반려동물"
        }
    }
}

/// 온보딩 6페이지 + 하드 페이월. 구매/복원 성공 시 `delegate(.completed)` 를 방출하고
/// 게이트 해제는 부모(AppFeature)가 수행한다.
@Reducer
public struct OnboardingFeature {
    public init() {}

    /// 온보딩 페이지 (paywall 은 페이지가 아니라 stage).
    public enum Page: Int, CaseIterable, Equatable, Sendable {
        case value1 = 0     // 가치①: 필름 소개
        case interest       // 맞춤 질문
        case sorting        // 가치②: 촬영일 자동 정렬
        case labels         // 가치③: 시간·날짜 라벨 (+선택 사항)
        case subtitle       // 가치④: 자막
        case permission     // 사진 권한 프라이밍

        public static let count = Page.allCases.count
    }

    @ObservableState
    public struct State: Equatable {
        public var mode: OnboardingMode
        public var stage: Stage
        public var pageIndex = 0
        public var selectedInterest: OnboardingInterest = .travel
        public var product: SubscriptionProduct?
        public var productLoadFailed = false
        public var isPurchasing = false
        public var isRestoring = false
        public var toast: String?

        @Shared(.appStorage("hasSeenOnboarding")) public var hasSeenOnboarding = false
        @Shared(.appStorage("onboardingInterest")) public var storedInterest = ""

        public enum Stage: Equatable, Sendable {
            case pages
            case paywall
        }

        /// 페이월 서브카피 — 선택한 관심사를 반영 (Perceived Fit).
        public var paywallSubtitle: String {
            guard mode == .full else { return String(localized: "3일 동안 모든 기능이 무료예요") }
            return String(localized: "\(selectedInterest.koreanName) 필름, 3일 동안 제한 없이 만들어보세요")
        }

        /// 가격 라인 — 상품 로드 전엔 로컬 기본 문구.
        public var priceLine: String {
            let price = product?.displayPrice ?? "₩1,500"
            return String(localized: "3일 무료 체험 후 \(price)/주")
        }

        public init(mode: OnboardingMode = .full) {
            self.mode = mode
            self.stage = (mode == .paywallOnly) ? .paywall : .pages
        }
    }

    public enum Action {
        case onAppear
        case nextTapped
        case pageChanged(Int)
        case interestTapped(OnboardingInterest)
        case productLoaded(Result<SubscriptionProduct, any Error>)
        case retryLoadTapped
        case purchaseTapped
        case purchaseResponse(Result<PurchaseOutcome, any Error>)
        case restoreTapped
        case restoreResponse(Result<Bool, any Error>)
        case toastDismissed
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case completed
        }
    }

    @Dependency(\.subscriptionClient) var subscriptionClient
    @Dependency(\.trialReminderClient) var trialReminderClient
    @Dependency(\.analyticsTracker) var analyticsTracker

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                if state.stage == .paywall {
                    analyticsTracker.log(.paywallViewed)
                } else {
                    analyticsTracker.log(.onboardingStepViewed(step: state.pageIndex))
                }
                return loadProduct()

            case .nextTapped:
                if state.pageIndex < Page.count - 1 {
                    state.pageIndex += 1
                    analyticsTracker.log(.onboardingStepViewed(step: state.pageIndex))
                    return .none
                }
                return enterPaywall(state: &state)

            case let .pageChanged(index):
                guard index != state.pageIndex else { return .none }
                state.pageIndex = index
                analyticsTracker.log(.onboardingStepViewed(step: index))
                return .none

            case let .interestTapped(interest):
                state.selectedInterest = interest
                state.$storedInterest.withLock { $0 = interest.rawValue }
                analyticsTracker.log(.onboardingInterestSelected(interest: interest.rawValue))
                return .none

            case let .productLoaded(.success(product)):
                state.product = product
                state.productLoadFailed = false
                return .none

            case .productLoaded(.failure):
                state.productLoadFailed = true
                return .none

            case .retryLoadTapped:
                state.productLoadFailed = false
                return loadProduct()

            case .purchaseTapped:
                guard !state.isPurchasing else { return .none }
                state.isPurchasing = true
                let price = state.product?.displayPrice ?? "₩1,500"
                return .run { send in
                    do {
                        let outcome = try await subscriptionClient.purchase()
                        if outcome == .success {
                            _ = await trialReminderClient.scheduleTrialEndingReminder(price)
                        }
                        await send(.purchaseResponse(.success(outcome)))
                    } catch {
                        await send(.purchaseResponse(.failure(error)))
                    }
                }

            case let .purchaseResponse(.success(outcome)):
                state.isPurchasing = false
                switch outcome {
                case .success:
                    analyticsTracker.log(.trialStarted)
                    return .send(.delegate(.completed))
                case .cancelled:
                    return .none
                case .pending:
                    state.toast = String(localized: "결제 승인을 기다리고 있어요")
                    return .none
                }

            case let .purchaseResponse(.failure(error)):
                state.isPurchasing = false
                state.toast = String(localized: "구매에 실패했어요. 다시 시도해주세요.")
                analyticsTracker.log(.purchaseFailed(reason: String(describing: error)))
                return .none

            case .restoreTapped:
                guard !state.isRestoring else { return .none }
                state.isRestoring = true
                return .run { send in
                    do {
                        let restored = try await subscriptionClient.restore()
                        await send(.restoreResponse(.success(restored)))
                    } catch {
                        await send(.restoreResponse(.failure(error)))
                    }
                }

            case let .restoreResponse(.success(restored)):
                state.isRestoring = false
                if restored {
                    analyticsTracker.log(.purchasesRestored)
                    return .send(.delegate(.completed))
                }
                state.toast = String(localized: "복원할 구매 내역이 없어요")
                return .none

            case .restoreResponse(.failure):
                state.isRestoring = false
                state.toast = String(localized: "복원에 실패했어요. 다시 시도해주세요.")
                return .none

            case .toastDismissed:
                state.toast = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }

    // MARK: - Helpers

    private func loadProduct() -> Effect<Action> {
        .run { send in
            do {
                let product = try await subscriptionClient.loadProduct()
                await send(.productLoaded(.success(product)))
            } catch {
                await send(.productLoaded(.failure(error)))
            }
        }
    }

    private func enterPaywall(state: inout State) -> Effect<Action> {
        state.stage = .paywall
        state.$hasSeenOnboarding.withLock { $0 = true }
        analyticsTracker.log(.paywallViewed)
        return .none
    }
}
