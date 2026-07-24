# 온보딩 + 주간 구독 페이월 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 첫 실행 시 온보딩 6페이지(가치3 + 맞춤질문 + 자막 + 권한) → 하드 페이월(주간 ₩1,500 · 3일 무료 체험)을 거쳐야 Home 에 진입하는 게이트를 구현한다.

**Architecture:** 신규 모듈 2개 — `SubscriptionService`(StoreKit 2 래핑 `@DependencyClient`) + `OnboardingFeature`(TCA `@Reducer` + 온보딩/페이월 View). `AppFeature`가 실행 시 구독 상태를 확인해 `@Presents var onboarding` 으로 오버레이 게이트를 띄우고, Onboarding 의 `delegate(.completed)` 로 해제한다. ExportFeature 는 구독 활성 시 기존 ExportQuota 를 우회한다.

**Tech Stack:** Swift 6 / iOS 18+ / SwiftUI / TCA 1.18+ (`@Reducer`·`@ObservableState`·`@Shared(.appStorage)`) / StoreKit 2 / UserNotifications / Swift Testing / Tuist.

## Global Constraints

- Swift 6.0+, iOS 18+ 고정. **GCD 금지** — Swift Concurrency 전용 (`async/await`, `actor`, `AsyncStream`).
- `ObservableObject`/`@Published` 금지. Observation + TCA `@ObservableState`.
- 테스트는 **Swift Testing** (`import Testing`, `@Test`, `#expect`). XCTest 금지.
- Feature 간 직접 import 금지. 네비게이션 인텐트는 `Action.Delegate` → `AppFeature` 해석.
- UI 는 DDS 토큰만: 색 `ChalNaColor.*`, 폰트 `ChalNaTypography.*`, 라디우스 `ChalNaRadius.*`, 그림자 `ChalNaShadow`. **spacing/padding 만 리터럴 숫자**. `Color(hex:)`·`.font(.system(...))`·리터럴 cornerRadius 직접 호출 금지 (기존 헤더 컴포넌트 내부의 시스템 폰트는 기존 코드 관례이므로 유지).
- 새 모듈은 `Tuist/ProjectDescriptionHelpers/Module.swift` 헬퍼 사용 → `Project.swift` 등록 → `tuist generate`.
- Product ID: `ios.inho.ChalNa.pro.weekly`. 표시 가격은 StoreKit `displayPrice` 동적 로드 (₩1,500 은 .storekit 로컬 설정값).
- 온보딩 노출 조건 키: `hasSeenOnboarding`, 관심사 키: `onboardingInterest` (둘 다 `@Shared(.appStorage)`).
- devMock(`CHALNA_APP_MODE=devMock`)에서는 게이트 **스킵**(기존 UITests 보호). `CHALNA_FORCE_ONBOARDING=1` 이면 강제 표시.
- 커밋 메시지는 한국어 + gitmoji 프리픽스, 끝에 `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- 각 태스크 종료 시 커밋. 빌드 검증 명령:
  `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- 테스트 실행: 같은 명령의 `test` + `-only-testing:<타겟>`.
- 알려진 이슈: `TimelineFeatureTests` 는 stale 참조로 이 작업과 무관하게 깨져 있음 — 전체 `test` 대신 타겟 지정 실행.

---

### Task 1: SubscriptionService 모듈 뼈대 (모델 + Client + Tuist 등록)

**Files:**
- Create: `Modules/SubscriptionService/Sources/SubscriptionClient.swift`
- Modify: `Project.swift` (모듈 타겟 + 앱 의존성)

**Interfaces:**
- Produces (후속 태스크가 사용):
  - `SubscriptionProduct { id, displayName, displayPrice, hasFreeTrial, trialDays }` (Equatable, Sendable)
  - `PurchaseOutcome { .success, .cancelled, .pending }` (Equatable, Sendable)
  - `SubscriptionConstants.weeklyProductID: String`
  - `SubscriptionClient { loadProduct() async throws -> SubscriptionProduct; purchase() async throws -> PurchaseOutcome; restore() async throws -> Bool; isSubscribed() async -> Bool; isSubscribedCached() -> Bool }`
  - `DependencyValues.subscriptionClient`

- [ ] **Step 1: SubscriptionClient.swift 작성**

```swift
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
        isSubscribedCached: { false }
    )
}

public extension DependencyValues {
    var subscriptionClient: SubscriptionClient {
        get { self[SubscriptionClient.self] }
        set { self[SubscriptionClient.self] = newValue }
    }
}
```

주의: `liveValue` 는 Task 2 의 `StoreKitSubscriptionService.swift` 에서 `DependencyKey` conformance 로 제공한다. 이 파일에서는 `TestDependencyKey` 만 채택 (분리하지 않으면 Task 2 에서 중복 conformance 에러).

- [ ] **Step 2: Project.swift 에 모듈 타겟 등록**

`Project.swift` 의 `Module.framework(name: "AnalyticsService", ...)` 블록 아래에 추가:

```swift
        Module.framework(
            name: "SubscriptionService",
            dependencies: [
                .external(name: "ComposableArchitecture"),
            ]
        ),
```

그리고 앱 타겟(`name: "ChalNa"`)의 `dependencies` 배열에서 `.target(name: "AnalyticsService"),` 다음 줄에 추가:

```swift
                .target(name: "SubscriptionService"),
```

- [ ] **Step 3: 재생성 + 빌드 검증**

Run: `tuist generate --no-open && xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Modules/SubscriptionService Project.swift
git commit -m "✨ feat: SubscriptionService 모듈 추가 (SubscriptionClient 인터페이스)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: StoreKit 2 live 구현 + 체험 종료 알림 클라이언트

**Files:**
- Create: `Modules/SubscriptionService/Sources/StoreKitSubscriptionService.swift`
- Create: `Modules/SubscriptionService/Sources/TrialReminderClient.swift`

**Interfaces:**
- Consumes: Task 1 의 `SubscriptionClient`, `SubscriptionProduct`, `PurchaseOutcome`, `SubscriptionError`, `SubscriptionConstants`
- Produces: `SubscriptionClient.liveValue`; `TrialReminderClient { scheduleTrialEndingReminder(priceText: String) async -> Bool }` + `DependencyValues.trialReminderClient`

- [ ] **Step 1: StoreKitSubscriptionService.swift 작성**

```swift
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
```

- [ ] **Step 2: TrialReminderClient.swift 작성**

```swift
import ComposableArchitecture
import Foundation
import UserNotifications

/// 체험 종료 D-2 로컬 알림. 페이월 타임라인의 "2일차 — 종료 전 알림" 약속을 이행한다.
/// 알림 권한 요청도 이 맥락("종료 전에 알려드려요")에서 수행한다.
@DependencyClient
public struct TrialReminderClient: Sendable {
    /// 권한 요청 후 체험 시작 2일 뒤 알림 예약. 반환값 = 권한 허용 여부.
    public var scheduleTrialEndingReminder: @Sendable (_ priceText: String) async -> Bool = { _ in false }
}

extension TrialReminderClient: DependencyKey {
    public static let liveValue = TrialReminderClient(
        scheduleTrialEndingReminder: { priceText in
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return false }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "찰나 무료 체험이 곧 끝나요")
            content.body = String(localized: "내일 \(priceText)/주 구독이 시작돼요. 원치 않으면 지금 취소할 수 있어요.")
            content.sound = .default

            // 체험 3일 중 2일차 시점 (48시간 뒤).
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60 * 48, repeats: false)
            let request = UNNotificationRequest(
                identifier: "trial-ending-reminder",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
            return true
        }
    )

    public static let testValue = TrialReminderClient()
}

public extension DependencyValues {
    var trialReminderClient: TrialReminderClient {
        get { self[TrialReminderClient.self] }
        set { self[TrialReminderClient.self] = newValue }
    }
}
```

- [ ] **Step 3: 빌드 검증**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Modules/SubscriptionService
git commit -m "✨ feat: StoreKit 2 구독 live 구현 + 체험 종료 D-2 알림 클라이언트

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: AnalyticsEvent 온보딩/구독 이벤트 추가

**Files:**
- Modify: `Modules/AnalyticsService/Sources/AnalyticsEvent.swift`

**Interfaces:**
- Produces: `.onboardingStepViewed(step: Int)`, `.onboardingInterestSelected(interest: String)`, `.paywallViewed`, `.trialStarted`, `.purchaseFailed(reason: String)`, `.purchasesRestored`

- [ ] **Step 1: enum case 추가**

`case feedbackSendFailed(reason: String)` 아래에 추가:

```swift
    // 온보딩 / 구독
    case onboardingStepViewed(step: Int)
    case onboardingInterestSelected(interest: String)
    case paywallViewed
    case trialStarted
    case purchaseFailed(reason: String)
    case purchasesRestored
```

`name` 스위치의 `case .feedbackSendFailed:` 줄 아래에 추가:

```swift
        case .onboardingStepViewed:       return "onboarding_step_viewed"
        case .onboardingInterestSelected: return "onboarding_interest_selected"
        case .paywallViewed:              return "paywall_viewed"
        case .trialStarted:               return "trial_started"
        case .purchaseFailed:             return "purchase_failed"
        case .purchasesRestored:          return "purchases_restored"
```

`parameters` 스위치 수정 — 파라미터 없는 묶음 case 에 `.paywallViewed, .trialStarted, .purchasesRestored` 를 추가하고:

```swift
        case .homeViewed, .newVlogTapped, .timelineOpened, .exportScreenOpened, .vlogSavedToLibrary, .settingsOpened,
             .paywallViewed, .trialStarted, .purchasesRestored:
            return [:]
```

파라미터 있는 case 는 `case let .feedbackSendFailed(reason):` 블록 아래에 추가:

```swift
        case let .onboardingStepViewed(step):
            return ["step": .int(step)]
        case let .onboardingInterestSelected(interest):
            return ["interest": .string(interest)]
        case let .purchaseFailed(reason):
            return ["reason": .string(reason)]
```

- [ ] **Step 2: 빌드 검증** (switch exhaustive 확인)

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Modules/AnalyticsService
git commit -m "✨ feat: 온보딩·구독 Analytics 이벤트 6종 추가

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: OnboardingFeature 리듀서 (TDD)

**Files:**
- Create: `Modules/OnboardingFeature/Sources/OnboardingFeature.swift`
- Create: `Modules/OnboardingFeature/Tests/OnboardingFeatureTests.swift`
- Modify: `Project.swift` (OnboardingFeature 프레임워크 + 테스트 타겟)

**Interfaces:**
- Consumes: `SubscriptionClient`(Task 1/2), `TrialReminderClient`(Task 2), Analytics case(Task 3)
- Produces: `OnboardingFeature`(@Reducer), `OnboardingFeature.State(mode:)`, `OnboardingMode { .full, .paywallOnly }`, `OnboardingInterest`, `Action.delegate(.completed)` — Task 5~7 이 사용. State 프로퍼티: `stage`, `pageIndex`, `selectedInterest`, `product`, `productLoadFailed`, `isPurchasing`, `isRestoring`, `toast`, `paywallSubtitle`(computed), `Page.count == 6`

- [ ] **Step 1: Project.swift 타겟 2개 추가**

`Module.framework(name: "SubscriptionService", ...)` 아래에:

```swift
        Module.framework(
            name: "OnboardingFeature",
            dependencies: [
                .target(name: "AnalyticsService"),
                .target(name: "Models"),
                .target(name: "DesignSystem"),
                .target(name: "SubscriptionService"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
```

`Module.unitTests(for: "SettingsFeature", ...)` 아래에:

```swift
        Module.unitTests(
            for: "OnboardingFeature",
            dependencies: [
                .target(name: "SubscriptionService"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
```

앱 타겟 `dependencies` 의 `.target(name: "SettingsFeature"),` 아래에:

```swift
                .target(name: "OnboardingFeature"),
```

- [ ] **Step 2: 실패하는 테스트 먼저 작성** — `Modules/OnboardingFeature/Tests/OnboardingFeatureTests.swift`

```swift
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
```

- [ ] **Step 3: `tuist generate` 후 테스트 실행 → 컴파일 실패 확인**

Run: `tuist generate --no-open && xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:OnboardingFeatureTests 2>&1 | tail -10`
Expected: FAIL — `OnboardingFeature.swift` 미존재로 컴파일 에러

- [ ] **Step 4: OnboardingFeature.swift 구현**

```swift
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
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:OnboardingFeatureTests 2>&1 | tail -10`
Expected: `** TEST SUCCEEDED **` (9 tests)

- [ ] **Step 6: Commit**

```bash
git add Modules/OnboardingFeature Project.swift
git commit -m "✨ feat: OnboardingFeature 리듀서 + 테스트 (페이지 진행·구매·복원 플로우)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: 온보딩 페이지 뷰 6종 (+ 등장 애니메이션)

**Files:**
- Create: `Modules/OnboardingFeature/Sources/OnboardingView.swift`
- Create: `Modules/OnboardingFeature/Sources/OnboardingPageViews.swift`

**Interfaces:**
- Consumes: `OnboardingFeature`(Task 4), DDS 토큰/컴포넌트, `ChalNaIcon`, `ThumbnailPreset`(Models)
- Produces: `OnboardingView(store:)` — Task 7 의 RootView 가 사용. `PaywallView(store:)` 는 Task 6 에서 제공되므로 이 태스크에서는 `store.stage == .paywall` 분기에 임시로 `Color.clear` 를 두지 말고 **Task 6 과 같은 커밋 전에 빌드하지 않는다** — 아래 Step 2 참고. (실제로는 Task 5·6 을 연속 구현 후 함께 빌드 검증)

- [ ] **Step 1: OnboardingView.swift 작성** (루트 + dots + CTA + 토스트)

```swift
import ComposableArchitecture
import DesignSystem
import SwiftUI

/// 온보딩 루트. stage 에 따라 페이지(TabView) ↔ 페이월을 전환한다.
/// 하드 페이월: 닫기 수단 없음. 게이트 해제는 delegate(.completed) → AppFeature.
public struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(store: StoreOf<OnboardingFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.stage {
            case .pages:   pages
            case .paywall: PaywallView(store: store)
            }
        }
        .chalNaScreen()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: store.stage)
        .onAppear { store.send(.onAppear) }
    }

    private var pages: some View {
        VStack(spacing: 0) {
            TabView(selection: $store.pageIndex.sending(\.pageChanged)) {
                Value1PageView()
                    .tag(OnboardingFeature.Page.value1.rawValue)
                InterestPageView(
                    selected: store.selectedInterest,
                    onTap: { store.send(.interestTapped($0)) }
                )
                .tag(OnboardingFeature.Page.interest.rawValue)
                SortingPageView()
                    .tag(OnboardingFeature.Page.sorting.rawValue)
                LabelsPageView()
                    .tag(OnboardingFeature.Page.labels.rawValue)
                SubtitlePageView()
                    .tag(OnboardingFeature.Page.subtitle.rawValue)
                PermissionPageView()
                    .tag(OnboardingFeature.Page.permission.rawValue)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageDots
                .padding(.bottom, 24)

            Button(store.pageIndex == OnboardingFeature.Page.permission.rawValue ? "계속" : "다음") {
                store.send(.nextTapped)
            }
            .buttonStyle(.chalNa(.filled, size: .xl, fillWidth: true))
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<OnboardingFeature.Page.count, id: \.self) { index in
                Circle()
                    .fill(index == store.pageIndex ? ChalNaColor.Purple.p600 : ChalNaColor.Gray.g200)
                    .frame(width: 8, height: 8)
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.pageIndex)
    }
}

#Preview("온보딩 전체") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State(mode: .full)) { OnboardingFeature() }
    )
}
```

- [ ] **Step 2: OnboardingPageViews.swift 작성** (페이지 6종 — 긴밀 결합 helper 로 한 파일)

공통 규칙: 각 페이지는 `PageScaffold`(비주얼 + 헤드라인 + 본문 배치)를 공유. 등장 애니메이션은 `.onAppear` 1회, `@Environment(\.accessibilityReduceMotion)` 이면 fade-only.

```swift
import DesignSystem
import Models
import SwiftUI

// MARK: - 공용 스캐폴드

/// 페이지 공통 레이아웃: 상단 비주얼 존 + 하단 카피 블록.
struct PageScaffold<Visual: View>: View {
    let headline: String
    let body_: String
    @ViewBuilder var visual: () -> Visual

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)
            visual()
                .frame(maxHeight: .infinity)
            VStack(spacing: 12) {
                Text(headline)
                    .font(ChalNaTypography.title(ChalNaTypography.Size.h1, weight: .bold))
                    .tracking(ChalNaTypography.Tracking.titleKR)
                    .foregroundColor(ChalNaColor.Gray.g900)
                    .multilineTextAlignment(.center)
                Text(body_)
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body2))
                    .foregroundColor(ChalNaColor.Gray.g500)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }
}

/// 9:16 목업 캔버스 (프리뷰 카드 공통).
struct MockCanvas<Content: View>: View {
    var width: CGFloat = 200
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack { content() }
            .frame(width: width, height: width * 16 / 9)
            .background(ChalNaColor.Gray.g200)
            .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous))
            .chalNaShadow(ChalNaShadow.md)
    }
}

// MARK: - 가치① 필름 소개

struct Value1PageView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cellsShown = 0
    @State private var pulsing = false

    var body: some View {
        PageScaffold(
            headline: "찰나의 순간이,\n한 편의 필름으로",
            body_: "Live Photo와 짧은 영상을 이어붙여\n하나의 브이로그가 돼요"
        ) {
            VStack(spacing: 20) {
                MockCanvas(width: 180) {
                    ZStack {
                        ThumbnailPreset.jejuOrange.view()
                        Circle()
                            .fill(ChalNaColor.Purple.p600)
                            .frame(width: 48, height: 48)
                            .overlay(
                                ChalNaIcon(.play, size: 18)
                                    .foregroundColor(.white)
                                    .offset(x: 2)
                            )
                            .scaleEffect(pulsing && !reduceMotion ? 1.06 : 1.0)
                    }
                }
                filmStrip
            }
        }
        .onAppear {
            guard cellsShown == 0 else { return }
            if reduceMotion {
                cellsShown = 5
            } else {
                for i in 1...5 {
                    withAnimation(.easeOut(duration: 0.35).delay(Double(i) * 0.05)) { cellsShown = i }
                }
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulsing = true }
        }
    }

    private var filmStrip: some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: ChalNaRadius.film, style: .continuous)
                    .fill(ChalNaColor.Gray.g400)
                    .frame(width: 40, height: 52)
                    .overlay {
                        if index == 0 {
                            RoundedRectangle(cornerRadius: ChalNaRadius.film, style: .continuous)
                                .strokeBorder(ChalNaColor.Purple.p600, lineWidth: 2)
                        }
                    }
                    .opacity(index < cellsShown ? 1 : 0)
                    .offset(x: index < cellsShown ? 0 : 24)
            }
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 6)
        .background(
            // 라디우스는 토큰만 — 앱 Timeline 필름스트립과 동일하게 sheet(16).
            RoundedRectangle(cornerRadius: ChalNaRadius.sheet, style: .continuous)
                .fill(ChalNaColor.Gray.g900)
                .frame(height: 64)
        )
    }
}

// MARK: - 맞춤 질문

struct InterestPageView: View {
    let selected: OnboardingInterest
    let onTap: (OnboardingInterest) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private let columns = [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)]

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 40)
            Text("어떤 찰나를 남기고 싶나요?")
                .font(ChalNaTypography.title(ChalNaTypography.Size.h1, weight: .bold))
                .tracking(ChalNaTypography.Tracking.titleKR)
                .foregroundColor(ChalNaColor.Gray.g900)
            Text("딱 맞는 시작을 준비해드릴게요")
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.body2))
                .foregroundColor(ChalNaColor.Gray.g500)

            LazyVGrid(columns: columns, spacing: 13) {
                ForEach(Array(OnboardingInterest.allCases.enumerated()), id: \.element) { index, interest in
                    interestCard(interest)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared || reduceMotion ? 0 : 16)
                        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.06), value: appeared)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)

            Spacer()
        }
        .onAppear { appeared = true }
    }

    private func interestCard(_ interest: OnboardingInterest) -> some View {
        let isSelected = interest == selected
        return Button {
            onTap(interest)
        } label: {
            VStack(spacing: 12) {
                Image(systemName: interest.symbolName)
                    .font(ChalNaTypography.krBody(24))
                    .foregroundColor(ChalNaColor.Purple.p600)
                Text(interest.koreanName)
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body2, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? ChalNaColor.Purple.p600 : ChalNaColor.Gray.g900)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(
                RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                    .fill(isSelected ? ChalNaColor.Purple.p100.opacity(0.35) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                    .strokeBorder(
                        isSelected ? ChalNaColor.Purple.p600 : ChalNaColor.Gray.g200,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.0 : 0.98)
            .animation(.spring(duration: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

extension OnboardingInterest {
    var symbolName: String {
        switch self {
        case .travel: return "airplane"
        case .daily:  return "sun.max"
        case .family: return "heart"
        case .pet:    return "pawprint"
        }
    }
}

// MARK: - 가치② 촬영일 자동 정렬

struct SortingPageView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 뒤섞인 순서 → 0.8초 후 정렬된 순서로 재정렬 (matched move).
    @State private var order: [Int] = [2, 0, 3, 1]
    @State private var markersLit = 0

    private let presets: [ThumbnailPreset] = [.jejuOrange, .seoulSun, .field, .sunset]
    private let dates = ["06.01", "06.02", "", "06.04"]

    var body: some View {
        PageScaffold(
            headline: "고르기만 하세요,\n순서는 찰나가",
            body_: "촬영일 순서로 자동 정렬돼요\n뒤섞인 클립도 걱정 없어요"
        ) {
            VStack(spacing: 28) {
                HStack(spacing: 12) {
                    ForEach(order, id: \.self) { index in
                        RoundedRectangle(cornerRadius: ChalNaRadius.film, style: .continuous)
                            .fill(ChalNaColor.Gray.g200)
                            .overlay(presets[index].view().clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.film, style: .continuous)))
                            .frame(width: 56, height: 74)
                            .chalNaShadow(ChalNaShadow.sm)
                    }
                }
                timelineBar
            }
        }
        .onAppear {
            guard order != [0, 1, 2, 3] else { return }
            if reduceMotion {
                order = [0, 1, 2, 3]
                markersLit = 4
                return
            }
            Task {
                try? await Task.sleep(for: .seconds(0.8))
                withAnimation(.spring(duration: 0.7)) { order = [0, 1, 2, 3] }
                for i in 1...4 {
                    try? await Task.sleep(for: .seconds(0.15))
                    withAnimation(.easeOut(duration: 0.2)) { markersLit = i }
                }
            }
        }
    }

    private var timelineBar: some View {
        VStack(spacing: 6) {
            ZStack {
                Rectangle()
                    .fill(ChalNaColor.Gray.g200)
                    .frame(width: 260, height: 2)
                HStack(spacing: 62) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index < markersLit ? ChalNaColor.Purple.p600 : ChalNaColor.Gray.g200)
                            .frame(width: 6, height: 6)
                    }
                }
            }
            HStack(spacing: 30) {
                ForEach(Array(dates.enumerated()), id: \.offset) { _, date in
                    Text(date)
                        .font(ChalNaTypography.monoFallback(11, weight: .medium))
                        .foregroundColor(ChalNaColor.Gray.g500)
                        .frame(width: 38)
                }
            }
        }
    }
}

// MARK: - 가치③ 시간·날짜 라벨 (선택 사항)

struct LabelsPageView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var timeShown = false
    @State private var dateShown = false
    @State private var timeToggle = false
    @State private var dateToggle = false

    var body: some View {
        PageScaffold(
            headline: "그날의 시간까지\n함께 기록",
            body_: "영상 위에 시간과 날짜가 자동으로 새겨져요\n필요 없으면 언제든 끌 수 있어요"
        ) {
            VStack(spacing: 16) {
                MockCanvas(width: 200) {
                    ZStack {
                        Text("09:30")
                            .font(ChalNaTypography.keris(40))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                            .opacity(timeShown ? 1 : 0)
                        VStack {
                            Spacer()
                            Text("2026/06/04")
                                .font(ChalNaTypography.keris(11))
                                .foregroundColor(.white)
                                .padding(.bottom, 16)
                                .opacity(dateShown ? 1 : 0)
                        }
                    }
                }
                HStack(spacing: 20) {
                    toggleChip(title: "시간 라벨", isOn: $timeToggle)
                    toggleChip(title: "날짜 라벨", isOn: $dateToggle)
                }
            }
        }
        .onAppear {
            guard !timeShown else { return }
            if reduceMotion {
                timeShown = true; dateShown = true; timeToggle = true; dateToggle = true
                return
            }
            withAnimation(.easeOut(duration: 0.3)) { timeShown = true }
            withAnimation(.easeOut(duration: 0.3).delay(0.15)) { dateShown = true }
            withAnimation(.spring(duration: 0.3).delay(0.45)) { timeToggle = true }
            withAnimation(.spring(duration: 0.3).delay(0.6)) { dateToggle = true }
        }
    }

    private func toggleChip(title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(ChalNaTypography.krBody(13, weight: .medium))
                .foregroundColor(ChalNaColor.Gray.g900)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(ChalNaColor.Purple.p600)
                .allowsHitTesting(false)   // 데모 전용
                .scaleEffect(0.8)
        }
    }
}

// MARK: - 가치④ 자막

struct SubtitlePageView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var typed = ""
    @State private var sliderValue: CGFloat = 0.3

    private let fullText = "제주 바다"

    var body: some View {
        PageScaffold(
            headline: "하고 싶은 말은\n자막으로",
            body_: "원하는 클립에 자막을 얹고\n위치와 크기도 자유롭게 바꿔요"
        ) {
            VStack(spacing: 16) {
                MockCanvas(width: 200) {
                    subtitleBox
                }
                sizeSlider
            }
        }
        .onAppear {
            guard typed.isEmpty else { return }
            if reduceMotion {
                typed = fullText
                sliderValue = 0.45
                return
            }
            Task {
                for character in fullText {
                    typed.append(character)
                    try? await Task.sleep(for: .seconds(0.12))
                }
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.spring(duration: 0.5)) { sliderValue = 0.45 }
            }
        }
    }

    /// LabelEditor 박스 스타일 축소판: 흰 배경 + 검정 테두리, 슬라이더와 크기 연동.
    private var subtitleBox: some View {
        let fontSize = 18 + sliderValue * 14
        return Text(typed.isEmpty ? " " : typed)
            .font(ChalNaTypography.krBody(fontSize, weight: .light))
            .tracking(fontSize * -0.06)
            .foregroundColor(.black)
            .padding(.horizontal, fontSize * 0.35)
            .padding(.vertical, fontSize * 0.22)
            .background(Rectangle().fill(Color.white))
            .overlay(Rectangle().strokeBorder(Color.black, lineWidth: fontSize * 0.06))
            .overlay(
                Rectangle()
                    .strokeBorder(ChalNaColor.Purple.p600, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .padding(-4)
            )
    }

    private var sizeSlider: some View {
        HStack(spacing: 8) {
            Text("크기")
                .font(ChalNaTypography.krBody(13, weight: .medium))
                .foregroundColor(ChalNaColor.Gray.g900)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(ChalNaColor.Gray.g200).frame(height: 4)
                    Capsule().fill(ChalNaColor.Purple.p600)
                        .frame(width: proxy.size.width * sliderValue, height: 4)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(ChalNaColor.Purple.p600, lineWidth: 1.5))
                        .offset(x: proxy.size.width * sliderValue - 9)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(width: 130, height: 18)
        }
    }
}

// MARK: - 사진 권한 프라이밍

struct PermissionPageView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        PageScaffold(
            headline: "추억을 불러올게요",
            body_: "영상을 만들 때 선택한 사진에만 접근해요.\n전체 보관함 권한은 필요하지 않아요."
        ) {
            VStack(spacing: 40) {
                Circle()
                    .fill(ChalNaColor.Purple.p100.opacity(0.55))
                    .frame(width: 96, height: 96)
                    .overlay(
                        Image(systemName: "photo.on.rectangle")
                            .font(ChalNaTypography.krBody(34))
                            .foregroundColor(ChalNaColor.Purple.p600)
                    )
                    .scaleEffect(appeared || reduceMotion ? 1.0 : 0.8)

                Text("사진을 고르는 시점에 iOS가 접근 여부를 물어봐요")
                    .font(ChalNaTypography.krBody(13))
                    .foregroundColor(ChalNaColor.Gray.g500)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                            .fill(ChalNaColor.Gray.g50)
                    )
                    .padding(.horizontal, 24)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5)) { appeared = true }
        }
    }
}
```

주의: `InterestPageView` 는 reducer 상태(`selectedInterest`)를 받아 그리므로 `OnboardingView` 쪽에서 클로저로 액션을 전달한다 (이미 Step 1 코드에 반영됨). `ChalNaTypography.krBody(_:weight:)` 의 첫 인자는 `CGFloat` 리터럴 허용.

- [ ] **Step 3: 커밋은 Task 6 완료 후 함께** (PaywallView 없이는 컴파일 불가)

---

### Task 6: PaywallView (트라이얼 타임라인 + 가격 카드 + 심사 필수 요소)

**Files:**
- Create: `Modules/OnboardingFeature/Sources/PaywallView.swift`

**Interfaces:**
- Consumes: `OnboardingFeature` State/Action (Task 4: `product`, `priceLine`, `paywallSubtitle`, `isPurchasing`, `isRestoring`, `productLoadFailed`, `toast`, `.purchaseTapped`, `.restoreTapped`, `.retryLoadTapped`, `.toastDismissed`)
- Produces: `PaywallView(store:)` — OnboardingView(Task 5)가 사용

- [ ] **Step 1: PaywallView.swift 작성**

```swift
import ComposableArchitecture
import DesignSystem
import SwiftUI

/// 하드 페이월 — Blinkist Honest Paywall 패턴.
/// Apple Schedule 2 §3.8(b): 구독명·기간·가격을 이 화면에 명시. 복원/약관/개인정보 링크 필수.
public struct PaywallView: View {
    @Bindable var store: StoreOf<OnboardingFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stepsShown = 0
    @State private var ctaBounced = false

    public init(store: StoreOf<OnboardingFeature>) {
        self.store = store
    }

    /// ⚠️ 출시 전 실제 URL 확정 필요 (App Store Connect 메타데이터에도 동일 등록).
    private enum Legal {
        static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
        static let privacy = URL(string: "https://chalna.app/privacy")!
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            header
            timeline
                .padding(.horizontal, 24)
                .padding(.top, 28)
            priceCard
                .padding(.horizontal, 24)
                .padding(.top, 24)
            Spacer(minLength: 16)
            ctaBlock
            legalLinks
                .padding(.top, 20)
                .padding(.bottom, 12)
        }
        .overlay(alignment: .bottom) { toast }
        .onAppear(perform: runEntrance)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 10) {
            ChalNaIcon(.film, size: 44)
                .foregroundColor(ChalNaColor.Purple.p600)
            Text(verbatim: "ChalNa Pro")
                .font(ChalNaTypography.displayKR(ChalNaTypography.Size.displayS, weight: .bold))
                .foregroundColor(ChalNaColor.Gray.g900)
            Text(store.paywallSubtitle)
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.body2))
                .foregroundColor(ChalNaColor.Gray.g500)
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            timelineStep(
                index: 0, symbol: "lock.open", filled: true,
                title: "오늘 — 모든 기능 잠금 해제",
                description: "바로 첫 필름을 만들어보세요"
            )
            connector
            timelineStep(
                index: 1, symbol: "bell", filled: false,
                title: "2일차 — 종료 전 알림",
                description: "체험이 끝나기 전에 미리 알려드려요"
            )
            connector
            timelineStep(
                index: 2, symbol: "star", filled: false,
                title: "3일차 — 구독 시작",
                description: "\(store.product?.displayPrice ?? "₩1,500")/주 · 시작 전 언제든 취소"
            )
        }
    }

    private func timelineStep(index: Int, symbol: String, filled: Bool, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Circle()
                .fill(filled ? ChalNaColor.Purple.p600 : ChalNaColor.Purple.p100.opacity(0.55))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: symbol)
                        .font(ChalNaTypography.krBody(15, weight: .semibold))
                        .foregroundColor(filled ? .white : ChalNaColor.Purple.p600)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body2, weight: .bold))
                    .foregroundColor(ChalNaColor.Gray.g900)
                Text(description)
                    .font(ChalNaTypography.krBody(13))
                    .foregroundColor(ChalNaColor.Gray.g500)
            }
            Spacer(minLength: 0)
        }
        .opacity(stepsShown > index ? 1 : 0)
        .offset(y: stepsShown > index || reduceMotion ? 0 : 10)
    }

    private var connector: some View {
        Rectangle()
            .fill(ChalNaColor.Purple.p100)
            .frame(width: 2, height: 22)
            .padding(.leading, 17)
            .padding(.vertical, 4)
    }

    private var priceCard: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("주간 구독")
                    .font(ChalNaTypography.krBody(13))
                    .foregroundColor(ChalNaColor.Gray.g500)
                if store.productLoadFailed {
                    Button("가격을 불러오지 못했어요 · 다시 시도") {
                        store.send(.retryLoadTapped)
                    }
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body2, weight: .semibold))
                    .foregroundColor(ChalNaColor.Purple.p600)
                } else {
                    Text(store.priceLine)
                        .font(ChalNaTypography.krBody(17, weight: .bold))
                        .foregroundColor(ChalNaColor.Gray.g900)
                }
            }
            Spacer()
            // ChalNaChip 은 leading 글리프를 강제하므로 텍스트 전용 캡슐을 인라인 구성.
            Text("3일 무료")
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.tag, weight: .bold))
                .foregroundColor(ChalNaColor.Purple.p600)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule(style: .continuous).fill(ChalNaColor.Purple.p100))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                .strokeBorder(ChalNaColor.Purple.p600, lineWidth: 1.5)
        )
    }

    private var ctaBlock: some View {
        VStack(spacing: 10) {
            Button {
                store.send(.purchaseTapped)
            } label: {
                if store.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text("3일 무료로 시작하기")
                }
            }
            .buttonStyle(.chalNa(.filled, size: .xl, fillWidth: true))
            .disabled(store.isPurchasing)
            .scaleEffect(ctaBounced || reduceMotion ? 1.0 : 0.98)
            .padding(.horizontal, 24)

            VStack(spacing: 3) {
                Text("지금은 결제되지 않아요")
                    .font(ChalNaTypography.krBody(13))
                Text("3일 후 \(store.product?.displayPrice ?? "₩1,500")/주 자동 갱신 · 언제든 취소 가능")
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.caption))
            }
            .foregroundColor(ChalNaColor.Gray.g500)
        }
    }

    private var legalLinks: some View {
        HStack(spacing: 6) {
            Button("구매 복원") { store.send(.restoreTapped) }
                .disabled(store.isRestoring)
            Text(verbatim: "·")
            Link("이용약관", destination: Legal.terms)
            Text(verbatim: "·")
            Link("개인정보처리방침", destination: Legal.privacy)
        }
        .font(ChalNaTypography.krBody(ChalNaTypography.Size.caption))
        .foregroundColor(ChalNaColor.Gray.g500)
    }

    @ViewBuilder
    private var toast: some View {
        if let message = store.toast {
            Text(message)
                .font(ChalNaTypography.krBody(13, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(ChalNaColor.Gray.g900.opacity(0.9)))
                .padding(.bottom, 120)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .task {
                    try? await Task.sleep(for: .seconds(2.2))
                    store.send(.toastDismissed)
                }
        }
    }

    // MARK: - Entrance

    private func runEntrance() {
        guard stepsShown == 0 else { return }
        if reduceMotion {
            stepsShown = 3
            ctaBounced = true
            return
        }
        for i in 1...3 {
            withAnimation(.easeOut(duration: 0.35).delay(Double(i - 1) * 0.12)) { stepsShown = i }
        }
        withAnimation(.spring(duration: 0.4).delay(0.5)) { ctaBounced = true }
    }
}

#Preview("페이월") {
    PaywallView(
        store: Store(initialState: OnboardingFeature.State(mode: .paywallOnly)) { OnboardingFeature() }
    )
    .chalNaScreen()
}
```

- [ ] **Step 2: 빌드 + 전체 Onboarding 테스트 재실행**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:OnboardingFeatureTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 3: Commit (Task 5 + 6 함께)**

```bash
git add Modules/OnboardingFeature
git commit -m "✨ feat: 온보딩 페이지 6종 + 페이월 뷰 (등장 애니메이션·트라이얼 타임라인)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: AppFeature/RootView 게이팅 통합 (+ Transaction.updates 옵저버)

**Files:**
- Modify: `Modules/SubscriptionService/Sources/SubscriptionClient.swift`
- Modify: `Modules/SubscriptionService/Sources/StoreKitSubscriptionService.swift`
- Modify: `ChalNa/Sources/App/AppFeature.swift`
- Modify: `ChalNa/Sources/App/RootView.swift`

**Interfaces:**
- Consumes: `OnboardingFeature`(Task 4~6), `SubscriptionClient.isSubscribed`(Task 1/2), `AppMode.current`(기존)
- Produces: `AppFeature.Action.task` — RootView 의 `.task` 가 전송; `SubscriptionClient.observeTransactionUpdates() async -> Void`

- [ ] **Step 0: Transaction.updates 옵저버 추가** (Task 2 리뷰 발견 사항 — 갱신/환불/Ask-to-Buy 트랜잭션은 `Transaction.updates` 로만 도착하며 finish 하지 않으면 무한 누적된다)

`SubscriptionClient.swift` 의 `isSubscribedCached` 선언 아래에 추가:

```swift
    /// 앱 수명 동안 StoreKit 트랜잭션 업데이트(갱신·환불·승인 완료)를 관찰하고 finish 한다.
    /// 앱 시작 시 1회 호출해 장기 실행 — AppFeature `.task` 에서 구동.
    public var observeTransactionUpdates: @Sendable () async -> Void = {}
```

`StoreKitSubscriptionService.swift` 의 liveValue 반환 `SubscriptionClient(...)` 마지막 인자(`isSubscribedCached:` 다음)에 추가:

```swift
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
```

- [ ] **Step 1: AppFeature.swift 수정**

import 목록에 `import OnboardingFeature`, `import SubscriptionService` 추가.

`State` 에 추가 (path 선언 아래):

```swift
        /// 하드 페이월 게이트. 구독(체험 포함) 비활성 시 온보딩/페이월 오버레이 표시.
        @Presents public var onboarding: OnboardingFeature.State?
        @Shared(.appStorage("hasSeenOnboarding")) public var hasSeenOnboarding = false
```

`Action` 에 추가:

```swift
        case task
        case gateResolved(subscribed: Bool)
        case onboarding(PresentationAction<OnboardingFeature.Action>)
```

Dependencies 에 추가:

```swift
    @Dependency(\.subscriptionClient) var subscriptionClient
```

`Reduce` 스위치의 `case .home, .path:` **위에** 추가:

```swift
            // MARK: Onboarding gate

            case .task:
                // devMock 은 게이트 스킵 (UITests·fixture 플로우 보호). 강제 표시는 env 로.
                let forced = ProcessInfo.processInfo.environment["CHALNA_FORCE_ONBOARDING"] == "1"
                let shouldGate = AppMode.current == .real || forced
                return .merge(
                    // 갱신/환불 트랜잭션 finish (앱 수명 동안 유지되는 옵저버).
                    .run { _ in await subscriptionClient.observeTransactionUpdates() },
                    shouldGate
                        ? .run { send in
                            let subscribed = await subscriptionClient.isSubscribed()
                            await send(.gateResolved(subscribed: subscribed))
                        }
                        : .none
                )

            case let .gateResolved(subscribed):
                guard !subscribed else { return .none }
                state.onboarding = OnboardingFeature.State(
                    mode: state.hasSeenOnboarding ? .paywallOnly : .full
                )
                return .none

            case .onboarding(.presented(.delegate(.completed))):
                state.onboarding = nil
                return .none

            case .onboarding:
                return .none
```

`case .home, .path:` 는 그대로 둔다. `.forEach(\.path, action: \.path)` 아래에 추가:

```swift
        .ifLet(\.$onboarding, action: \.onboarding) {
            OnboardingFeature()
        }
```

- [ ] **Step 2: RootView.swift 수정**

import 목록에 `import OnboardingFeature` 추가. `body` 를 ZStack 으로 감싸 온보딩 오버레이 + `.task` 를 연결:

```swift
    public var body: some View {
        ZStack {
            NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
                HomeView(store: store.scope(state: \.home, action: \.home))
                    .toolbar(.hidden, for: .navigationBar)
                    .chalNaSwipeBack()
            } destination: { childStore in
                destinationView(for: childStore)
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
                    .chalNaSwipeBack()
            }

            // 하드 페이월 게이트 — fullScreenCover 대신 오버레이(런치 플래시 방지, 스플래시와 자연 연결).
            if let onboardingStore = store.scope(state: \.onboarding, action: \.onboarding.presented) {
                OnboardingView(store: onboardingStore)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.onboarding == nil)
        .task { store.send(.task) }
        .environment(session)
        .environment(languageStore)
        .environment(\.locale, languageStore.locale)
    }
```

- [ ] **Step 3: 빌드 검증**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add ChalNa/Sources
git commit -m "✨ feat: AppFeature 온보딩/페이월 게이트 통합 (구독 상태 기반, devMock 스킵)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: ExportFeature 구독 시 쿼터 우회 (TDD)

**Files:**
- Modify: `Modules/ExportFeature/Sources/ExportFeature.swift:103,115`
- Modify: `Modules/ExportFeature/Tests/ExportFeatureQuotaTests.swift`
- Modify: `Project.swift` (ExportFeature·ExportFeatureTests 의존성에 SubscriptionService)

**Interfaces:**
- Consumes: `SubscriptionClient.isSubscribedCached`(Task 1)

- [ ] **Step 1: 실패하는 테스트 추가** — `ExportFeatureQuotaTests.swift` 의 기존 테스트 아래에 (파일 상단에 `import SubscriptionService` 추가). `exportableClip()` 헬퍼와 `output` 패턴은 기존 테스트와 동일하게 재사용:

```swift
    @Test func subscribedUserBypassesQuota() async {
        let clip = exportableClip()
        let output = URL(fileURLWithPath: "/tmp/chalna-export.mp4")
        let store = TestStore(initialState: ExportFeature.State()) {
            ExportFeature()
        } withDependencies: {
            $0.subscriptionClient.isSubscribedCached = { true }
            // 쿼터가 소진돼 있어도 구독자는 통과해야 한다.
            $0.exportQuotaClient.reserveExport = { .blocked(.dailyLimit) }
            $0.compositionClient.export = { _, _, _, _, _ in
                AsyncStream { continuation in
                    continuation.yield(.completed(output))
                    continuation.finish()
                }
            }
            $0.photoLibraryClient.saveVideoToPhotoLibrary = { _ in .ok }
        }
        store.exhaustivity = .off

        await store.send(.startExport(clips: [clip], rotations: [:], transforms: [:], clipLabels: [:]))
        await store.receive(\.exportCompleted)
        #expect(store.state.phase == .done)
    }
```

- [ ] **Step 2: Project.swift 의존성 추가** — `ExportFeature` 프레임워크와 `Module.unitTests(for: "ExportFeature", ...)` 두 곳의 `dependencies` 에 `.target(name: "SubscriptionService"),` 추가 후 `tuist generate --no-open`.

- [ ] **Step 3: 테스트 실행 → 실패 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:ExportFeatureTests/ExportFeatureQuotaTests 2>&1 | tail -10`
Expected: FAIL — `subscribedUserBypassesQuota` 에서 phase == .failed (쿼터 차단됨)

- [ ] **Step 4: ExportFeature.swift 수정**

파일 상단 import 에 `import SubscriptionService` 추가. `@Dependency(\.exportQuotaClient) var exportQuotaClient` 아래에:

```swift
    @Dependency(\.subscriptionClient) var subscriptionClient
```

`case let .startExport(...)` 의 쿼터 스위치를 구독 체크로 감싼다 (115행 부근):

```swift
                guard !clips.isEmpty else { return .none }
                // 구독(체험 포함) 활성 시 쿼터 우회 — 리딤 코드와 동일 취급.
                if !subscriptionClient.isSubscribedCached() {
                    switch exportQuotaClient.reserveExport() {
                    case .allowed:
                        break
                    case let .blocked(reason):
                        state.phase = .failed
                        state.progress = 0
                        state.errorMessage = reason.message
                        state.exportedURL = nil
                        state.didAddToLibrary = false
                        analyticsTracker.log(.exportFailed(reason: "quota_\(reason)"))
                        return .none
                    }
                }
```

- [ ] **Step 5: 테스트 통과 확인** (기존 quota 테스트 2개 + 신규 1개)

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:ExportFeatureTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Modules/ExportFeature Project.swift
git commit -m "✨ feat: 구독 활성 시 ExportQuota 우회

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: StoreKit 로컬 설정 + Paywall Dev 스킴 + 최종 검증

**Files:**
- Create: `ChalNa.storekit` (repo 루트)
- Modify: `Project.swift` (schemes 에 "ChalNa Paywall Dev" 추가)

- [ ] **Step 1: ChalNa.storekit 작성** — 주간 ₩1,500 + 3일 무료 체험 로컬 상품

```json
{
  "identifier" : "F9A1C2D3",
  "nonRenewingSubscriptions" : [ ],
  "products" : [ ],
  "settings" : {
    "_locale" : "ko_KR",
    "_storefront" : "KOR"
  },
  "subscriptionGroups" : [
    {
      "id" : "21000001",
      "localizations" : [ ],
      "name" : "ChalNa Pro",
      "subscriptions" : [
        {
          "adHocOffers" : [ ],
          "codeOffers" : [ ],
          "displayPrice" : "1500",
          "familyShareable" : false,
          "groupNumber" : 1,
          "internalID" : "A1B2C3D4",
          "introductoryOffer" : {
            "internalID" : "B2C3D4E5",
            "paymentMode" : "free",
            "subscriptionPeriod" : "P3D"
          },
          "localizations" : [
            {
              "description" : "영상 무제한 생성과 모든 편집 기능",
              "displayName" : "ChalNa Pro 주간",
              "locale" : "ko_KR"
            }
          ],
          "productID" : "ios.inho.ChalNa.pro.weekly",
          "recurringSubscriptionPeriod" : "P1W",
          "referenceName" : "ChalNa Pro Weekly",
          "subscriptionGroupID" : "21000001",
          "type" : "RecurringSubscription"
        }
      ]
    }
  ],
  "version" : {
    "major" : 3,
    "minor" : 0
  }
}
```

- [ ] **Step 2: Project.swift 스킴 추가** — 기존 "ChalNa Dev" 스킴 아래에:

```swift
        .scheme(
            name: "ChalNa Paywall Dev",
            shared: true,
            buildAction: .buildAction(targets: ["ChalNa"]),
            runAction: .runAction(
                configuration: .debug,
                executable: "ChalNa",
                arguments: .arguments(environmentVariables: [
                    "CHALNA_APP_MODE": "devMock",
                    "CHALNA_FORCE_ONBOARDING": "1",
                ]),
                options: .options(storeKitConfigurationPath: "ChalNa.storekit")
            )
        ),
```

- [ ] **Step 3: 재생성 + 전체 관련 테스트**

Run: `tuist generate --no-open && xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:OnboardingFeatureTests -only-testing:ExportFeatureTests -only-testing:AppCoreTests -only-testing:SettingsFeatureTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 4: 시뮬레이터 시각 검증** — `ios-build-run` 서브에이전트에 위임: "ChalNa Paywall Dev" 스킴으로 fresh build + iPhone 17 Pro 시뮬레이터 실행. 확인 항목: (1) 스플래시 후 온보딩 가치① 표시 (2) 스와이프/다음으로 6페이지 진행 (3) 페이월 타임라인·가격(₩1,500)·복원/약관 링크 표시 (4) "3일 무료로 시작하기" → StoreKit 로컬 결제 시트 (5) 승인 후 Home 진입 (6) 앱 재실행 시 온보딩 미표시(구독 활성). 각 단계 스크린샷.

- [ ] **Step 5: Commit**

```bash
git add ChalNa.storekit Project.swift
git commit -m "🔧 chore: StoreKit 로컬 설정(주간+3일 체험) + Paywall Dev 스킴 추가

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## 남은 운영 항목 (코드 외 — 사용자 결정 필요)

1. **App Store Connect**: `ios.inho.ChalNa.pro.weekly` 구독 상품 생성 (주간 ₩1,500 + 3일 무료 체험 intro offer), 구독 그룹 "ChalNa Pro".
2. **개인정보처리방침 URL**: `PaywallView.Legal.privacy` 의 `https://chalna.app/privacy` 를 실제 URL 로 교체 + App Store Connect 메타데이터 등록.
3. 가치① 화면의 "샘플 필름 자동 재생"은 프로덕션 번들용 영상 에셋이 확보되면 후속 작업 (현재는 그라디언트 목업 + 애니메이션).
