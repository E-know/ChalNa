import Testing
import ComposableArchitecture
import SubscriptionService
@testable import OnboardingFeature

@MainActor
struct OnboardingFeatureTests {

    static let sampleProduct = SubscriptionProduct(
        id: SubscriptionConstants.weeklyProductID,
        displayName: "ChalNa Pro",
        displayPrice: "₩1,500",
        hasFreeTrial: true,
        trialDays: 3
    )

    @Test func nextAdvancesPagesThenEntersPaywallAndMarksSeen() async {
        let store = TestStore(initialState: OnboardingFeature.State(mode: .full)) {
            OnboardingFeature()
        }
        store.exhaustivity = .off

        #expect(store.state.stage == .pages)
        for expected in 1...5 {
            await store.send(.nextTapped)
            #expect(store.state.pageIndex == expected)
        }
        await store.send(.nextTapped)   // 마지막(권한) 페이지에서 → 페이월
        #expect(store.state.stage == .paywall)
        #expect(store.state.hasSeenOnboarding == true)
    }

    @Test func paywallOnlyModeStartsAtPaywall() async {
        let store = TestStore(initialState: OnboardingFeature.State(mode: .paywallOnly)) {
            OnboardingFeature()
        }
        #expect(store.state.stage == .paywall)
    }

    @Test func interestSelectionPersistsToAppStorage() async {
        let store = TestStore(initialState: OnboardingFeature.State(mode: .full)) {
            OnboardingFeature()
        }
        store.exhaustivity = .off   // @Shared(appStorage) 변이는 #expect 로 검증

        await store.send(.interestTapped(.family))
        #expect(store.state.selectedInterest == .family)
        #expect(store.state.storedInterest == "family")
    }

    @Test func purchaseSuccessSchedulesReminderAndCompletes() async {
        let didSchedule = LockIsolated(false)
        let store = TestStore(initialState: OnboardingFeature.State(mode: .paywallOnly)) {
            OnboardingFeature()
        } withDependencies: {
            $0.subscriptionClient.purchase = { .success }
            $0.trialReminderClient.scheduleTrialEndingReminder = { _ in
                didSchedule.setValue(true)
                return true
            }
        }
        store.exhaustivity = .off

        await store.send(.purchaseTapped) {
            $0.isPurchasing = true
        }
        await store.receive(\.purchaseResponse) {
            $0.isPurchasing = false
        }
        await store.receive(\.delegate.completed)
        #expect(didSchedule.value)
    }

    @Test func purchaseCancelKeepsPaywallSilently() async {
        let store = TestStore(initialState: OnboardingFeature.State(mode: .paywallOnly)) {
            OnboardingFeature()
        } withDependencies: {
            $0.subscriptionClient.purchase = { .cancelled }
        }
        store.exhaustivity = .off

        await store.send(.purchaseTapped)
        await store.receive(\.purchaseResponse)
        #expect(store.state.isPurchasing == false)
        #expect(store.state.toast == nil)
        #expect(store.state.stage == .paywall)
    }

    @Test func purchaseFailureShowsToast() async {
        struct Boom: Error {}
        let store = TestStore(initialState: OnboardingFeature.State(mode: .paywallOnly)) {
            OnboardingFeature()
        } withDependencies: {
            $0.subscriptionClient.purchase = { throw Boom() }
        }
        store.exhaustivity = .off

        await store.send(.purchaseTapped)
        await store.receive(\.purchaseResponse)
        #expect(store.state.toast != nil)
    }

    @Test func restoreWithoutEntitlementShowsToast() async {
        let store = TestStore(initialState: OnboardingFeature.State(mode: .paywallOnly)) {
            OnboardingFeature()
        } withDependencies: {
            $0.subscriptionClient.restore = { false }
        }
        store.exhaustivity = .off

        await store.send(.restoreTapped)
        await store.receive(\.restoreResponse)
        #expect(store.state.toast == "복원할 구매 내역이 없어요")
    }

    @Test func restoreWithEntitlementCompletes() async {
        let store = TestStore(initialState: OnboardingFeature.State(mode: .paywallOnly)) {
            OnboardingFeature()
        } withDependencies: {
            $0.subscriptionClient.restore = { true }
        }
        store.exhaustivity = .off

        await store.send(.restoreTapped)
        await store.receive(\.delegate.completed)
    }

    @Test func productLoadFailureEnablesRetry() async {
        struct Boom: Error {}
        let store = TestStore(initialState: OnboardingFeature.State(mode: .paywallOnly)) {
            OnboardingFeature()
        } withDependencies: {
            $0.subscriptionClient.loadProduct = { throw Boom() }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.productLoaded)
        #expect(store.state.productLoadFailed == true)

        // 재시도 성공 경로
        store.dependencies.subscriptionClient.loadProduct = { Self.sampleProduct }
        await store.send(.retryLoadTapped)
        await store.receive(\.productLoaded)
        #expect(store.state.product == Self.sampleProduct)
        #expect(store.state.productLoadFailed == false)
    }
}
