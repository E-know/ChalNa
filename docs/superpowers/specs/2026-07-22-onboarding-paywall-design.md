# 온보딩 + 주간 구독 페이월 설계

- 날짜: 2026-07-22
- 상태: 사용자 승인됨 (Figma 디자인 → SwiftUI 구현 순서로 진행)
- 결과물 범위: Figma 디자인(`1.2.0` 페이지) + SwiftUI(TCA) 구현

## 1. 목표

첫 실행 사용자에게 앱 가치를 소개하고, **주단위 구독(3일 무료 체험 포함)** 을 시작해야 앱을 사용할 수 있는 **하드 페이월**을 도입한다.

## 2. 전체 플로우 & 게이팅

```
첫 실행:   Splash → 가치① → 가치② → 가치③ → 권한 안내 → 페이월(하드) → 체험 시작 → Home
재실행:    Splash → 구독(체험 포함) 활성 → Home
                  → 비활성 → 페이월만 표시 (가치/권한 화면은 첫 1회만)
```

- 하드 페이월: 닫기(X) 없음. 구독/체험 시작 없이 Home 진입 불가.
- 구독 상태: StoreKit 2 `Transaction.currentEntitlements` 기반. 체험 중 = 활성.
- 온보딩 1회 노출 여부: `hasSeenOnboarding` (`@Shared(.appStorage)`).
- 권한 화면은 **프라이밍 전용** — 실제 사진 권한 요청은 기존대로 MediaPicker 사용 시점. 권한 로직 코드 변경 없음.
- 기존 `ExportQuota`/리딤 코드는 유지. 구독 활성 시 제한 해제와 동일 취급(리딤 코드 = 구독 우회 경로).

## 3. 화면 구성 (5화면, Figma `1.2.0` 페이지 컨벤션: 393×852 / DDS 토큰 / 한글 Noto Sans KR)

| # | 화면 | 핵심 카피 | 비주얼 |
|---|---|---|---|
| 1 | 가치① | "찰나의 순간이, 한 편의 필름으로" / Live Photo와 짧은 영상을 이어붙여요 | 9:16 프리뷰 카드 + 필름스트립 목업 |
| 2 | 가치② | "고르기만 하세요, 순서는 찰나가" / 촬영일 순서로 자동 정렬 | 클립 카드 행 + 날짜 눈금 시각화 |
| 3 | 가치③ | "그날의 시간까지 함께 기록" / 시간·날짜 라벨 자동 삽입 | 라벨 오버레이 목업(09:30 / 2026/06/04) |
| 4 | 권한 안내 | "추억을 불러올게요" / 선택한 사진에만 접근해요 | 아이콘 + 안내 카드, CTA "계속" |
| 5 | 페이월 | "ChalNa Pro — 3일 무료로 시작" | 아래 상세 |

- 가치 화면 공통: 페이지 인디케이터(dots) + `chalNa(.filled, size: .xl, fillWidth: true)` "다음" CTA, 스와이프 전환(TabView page style).
- 페이월 구성(위→아래):
  1. 타이틀 영역: 필름 아이콘 + "ChalNa Pro" + 서브카피
  2. 혜택 3줄(`ChalNaIcon.check`): 영상 무제한 생성 · 시간·날짜 라벨 자동 삽입 · 모든 편집 기능
  3. 가격 카드(Purple.p600 테두리, radius 8): "3일 무료 체험 후 ₩1,500/주" + "3일 무료" 칩
  4. CTA: "3일 무료로 시작하기" (.filled .xl fillWidth)
  5. caption: "체험 중 언제든 취소할 수 있어요 · 이후 ₩1,500/주 자동 갱신"
  6. 링크 행: 구매 복원 · 이용약관 · 개인정보처리방침
- 가격 ₩1,500/주는 목업 표시용. 실제 가격은 App Store Connect 상품 설정을 UI에서 동적 로드.
- 심사 요건(하드 페이월): 복원 버튼 + 약관/개인정보 링크 + 가격·자동갱신 고지 필수 → 페이월에 모두 포함.

## 4. 구현 아키텍처 (승인된 접근: 신규 모듈 2개)

- **`OnboardingFeature`** (Feature 레이어)
  - `OnboardingFeature.swift`: `@Reducer`. State: `page`, `purchaseState`, `priceDisplay` 등. Action: 페이지 진행, `purchaseTapped`, `restoreTapped`, `delegate(.completed)`.
  - `OnboardingView.swift`: 가치 3장 + 권한 (TabView page style).
  - `PaywallView.swift`: 페이월 화면 (재사용 가능 — 추후 설정 등에서 단독 표시).
  - 의존: AppCore + SubscriptionService + Models + DesignSystem + TCA. (Feature 간 import 금지 준수)
- **`SubscriptionService`** (서비스 레이어)
  - `SubscriptionClient` (`@DependencyClient`): `loadProduct`, `purchase`, `restore`, `entitlementUpdates`(AsyncStream), `isSubscribed`.
  - 구현: StoreKit 2 `actor`. GCD 금지, Swift Concurrency 전용.
  - Product ID: `ios.inho.ChalNa.pro.weekly` (가칭).
- **`AppFeature` 연동**: Onboarding `.delegate(.completed)` → 게이트 해제. 표시 조건 = `!hasSeenOnboarding || !subscriptionActive`.
- **Analytics**: `AnalyticsEvent`에 `onboardingStepViewed(step:)`, `trialStarted`, `purchaseFailed(reason:)`, `restoreTapped` case 추가.

## 5. 에러 & 엣지 케이스

- 구매 취소/실패: 페이월 유지 + 토스트(Export 토스트 패턴 재사용).
- 상품 로드 실패(오프라인): 가격 자리 placeholder + 재시도 버튼.
- 복원 결과 없음: alert 안내.
- 체험 만료 후 실행: 페이월 재표시(가치 화면 없이).

## 6. 테스트

- `OnboardingFeatureTests` (Swift Testing): 페이지 진행, 구매 성공 → `delegate(.completed)`, 실패 → 페이월 유지, 복원 흐름.
- `SubscriptionClient.testValue`로 Feature 격리.
- StoreKit Configuration(`.storekit`) 파일로 체험/갱신 시나리오 로컬 검증.

## 7. 작업 순서

1. Figma `1.2.0` 페이지에 5화면 추가 → 사용자 확인
2. SwiftUI 구현 (writing-plans 스킬로 상세 계획 후 진행)
