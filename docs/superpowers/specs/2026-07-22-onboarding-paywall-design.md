# 온보딩 + 주간 구독 페이월 설계

- 날짜: 2026-07-22 (v2 — 온보딩 리서치 반영)
- 상태: 사용자 승인된 v1 설계에, 사용자 지시("유명 온보딩 리서치 후 반영")에 따른 패턴 적용
- 결과물 범위: Figma 디자인(`1.2.0` 페이지) + SwiftUI(TCA) 구현

## 1. 목표

첫 실행 사용자에게 앱 가치를 소개하고, **주단위 구독(3일 무료 체험 포함)** 을 시작해야 앱을 사용할 수 있는 **하드 페이월**을 도입한다.

## 2. 전체 플로우 & 게이팅

```
첫 실행:   Splash → 가치① → 맞춤 질문 → 가치② → 가치③ → 권한 안내 → 페이월(하드) → 체험 시작 → Home
재실행:    Splash → 구독(체험 포함) 활성 → Home
                  → 비활성 → 페이월만 표시 (온보딩 화면은 첫 1회만)
```

- 하드 페이월: 닫기(X) 없음. 구독/체험 시작 없이 Home 진입 불가.
  - 근거: RevenueCat State of Subscription Apps 2026 — 설치→유료 전환 중앙값 하드 10.7% vs 프리미엄 2.1%. 신규 앱은 하드로 지불의사 검증 권고.
- 구독 상태: StoreKit 2 `Transaction.currentEntitlements` 기반. 체험 중 = 활성.
- 온보딩 1회 노출 여부: `hasSeenOnboarding` (`@Shared(.appStorage)`).
- 권한 화면은 **프라이밍 전용** — 실제 사진 권한 요청은 기존대로 MediaPicker 사용 시점. 권한 로직 코드 변경 없음.
- 기존 `ExportQuota`/리딤 코드는 유지. 구독 활성 시 제한 해제와 동일 취급(리딤 코드 = 구독 우회 경로).

## 3. 화면 구성 (6화면, Figma `1.2.0` 페이지 컨벤션: 393×852 / DDS 토큰 / 한글 Noto Sans KR)

| # | 화면 | 핵심 카피 | 적용 패턴 (근거) |
|---|---|---|---|
| 1 | 가치① | "찰나의 순간이, 한 편의 필름으로" | 결과물 먼저 보여주는 감정 훅 (9:16 프리뷰 + 필름스트립). **SwiftUI 구현 시 정적 이미지 대신 번들 샘플 필름 자동 재생** (`BundledDevMediaSource`/`SampleData.jejuTimeline` 재활용) — 근거: PhotoRoom·Remini·YouCam "결과물 먼저" 패턴, Adapty A/B(가치 시연 추가 시 체험 시작 +25%, ARPU +78%) |
| 2 | **맞춤 질문 (신규)** | "어떤 찰나를 남기고 싶나요?" — 여행/일상/가족·아이/반려동물 2×2 선택 | **Perceived Fit** — Headspace×Irrational Labs 실험: 퀴즈 후 동일 코스 추천만으로 코스 시작률 31%→63%. 실제 맞춤보다 "맞춤됐다는 인식"이 효과의 본체 |
| 3 | 가치② | "고르기만 하세요, 순서는 찰나가" | 촬영일 자동 정렬 시각화 |
| 4 | 가치③ | "그날의 시간까지 함께 기록" | 라벨 오버레이 목업 |
| 5 | 권한 안내 | "추억을 불러올게요" — 선택한 사진에만 접근 | 권한 프라이밍 + 민감 요청 완충 카피 (Noom 패턴) |
| 6 | 페이월 | "ChalNa Pro — 3일 동안 모든 기능이 무료예요" | 아래 상세 |

- 온보딩(1~5) 공통: 페이지 dots 5개 + `chalNa(.filled, .xl, fillWidth)` CTA, 스와이프 전환.
- 질문 답변은 강제 아님(기본 선택 제공). 답변은 `@Shared(.appStorage)` 저장 → 추후 페이월 서브카피·홈 추천 개인화에 활용 가능.

### 페이월 구성 (Blinkist "Honest Paywall" 패턴, 위→아래)

1. 필름 아이콘 + **"ChalNa Pro"** + 서브카피 "3일 동안 모든 기능이 무료예요" — 기능 자랑 대신 체험 조건을 전면에
2. **트라이얼 타임라인 3단계** (세로, 아이콘 + 연결선):
   - 오늘 — 모든 기능 잠금 해제 (자물쇠 열림, 보라 채움)
   - 2일차 — 종료 전 알림 "체험이 끝나기 전에 미리 알려드려요" (종)
   - 3일차 — 구독 시작 "₩1,500/주 · 시작 전 언제든 취소" (별)
3. 가격 카드(Purple 테두리): "주간 구독 / 3일 무료 체험 후 ₩1,500/주" + "3일 무료" 칩 — Apple Schedule 2 §3.8(b) 필수 3요소(구독명·기간·가격)를 이 화면에 크게 명시
4. CTA "3일 무료로 시작하기"
5. CTA 직하단 안심 문구: **"지금은 결제되지 않아요"** + "3일 후 ₩1,500/주 자동 갱신 · 언제든 취소 가능"
6. 하단 링크 행: 구매 복원 · 이용약관 · 개인정보처리방침 (Apple 심사 필수)

- 근거: Blinkist 타임라인 페이월 — 체험 시작 +23%, 푸시 옵트인 6%→74%, 과금 불만 -55% (growth.design / Purchasely / B2B Pricing Insights 교차 확인). 사용자가 구독을 망설이는 1순위 이유는 "언제 결제되는지 몰라서"라는 공포.
- **사회적 증거(평점·사용자 수)는 보류** — Adapty: 실제 평점이 좋을 때만 효과. 출시 전이므로 실지표 확보 후 A/B로 추가.
- 가격 ₩1,500/주는 목업 표시용. 실제 가격은 App Store Connect 상품 설정을 UI에서 동적 로드.

## 4. 구현 아키텍처 (승인된 접근: 신규 모듈 2개)

- **`OnboardingFeature`** (Feature 레이어)
  - `OnboardingFeature.swift`: `@Reducer`. State: `page`, `selectedInterest`, `purchaseState`, `priceDisplay` 등. Action: 페이지 진행, `interestSelected`, `purchaseTapped`, `restoreTapped`, `delegate(.completed)`.
  - `OnboardingView.swift`: 가치 3장 + 질문 + 권한 (TabView page style).
  - `PaywallView.swift`: 페이월 (재사용 가능 — 체험 만료 후 단독 표시).
  - 의존: AppCore + SubscriptionService + Models + DesignSystem + TCA.
- **`SubscriptionService`** (서비스 레이어)
  - `SubscriptionClient` (`@DependencyClient`): `loadProduct`, `purchase`, `restore`, `entitlementUpdates`(AsyncStream), `isSubscribed`.
  - 구현: StoreKit 2 `actor`. Product ID: `ios.inho.ChalNa.pro.weekly` (가칭).
- **`AppFeature` 연동**: Onboarding `.delegate(.completed)` → 게이트 해제.
- **체험 시작 직후 알림 퍼미션 프라이밍 (신규, 리서치 반영)**: "2일차에 종료 알림을 보내려면 알림 권한이 필요해요" 맥락으로 요청 → 허용 시 **D-2 로컬 알림 실제 발송** (타임라인 약속 이행). 근거: Blinkist 푸시 옵트인 6%→74%, 약속 이행이 불만 -55%의 원천.
- **Analytics**: `onboardingStepViewed(step:)`, `onboardingInterestSelected(interest:)`, `trialStarted`, `purchaseFailed(reason:)`, `restoreTapped`.

## 5. 에러 & 엣지 케이스

- 구매 취소/실패: 페이월 유지 + 토스트(Export 토스트 패턴 재사용).
- 상품 로드 실패(오프라인): 가격 자리 placeholder + 재시도 버튼.
- 복원 결과 없음: alert 안내.
- 체험 만료 후 실행: 페이월 재표시(온보딩 없이).

## 6. 테스트

- `OnboardingFeatureTests` (Swift Testing): 페이지 진행, 관심사 선택 저장, 구매 성공 → `delegate(.completed)`, 실패 → 페이월 유지, 복원 흐름.
- `SubscriptionClient.testValue`로 Feature 격리.
- StoreKit Configuration(`.storekit`) 파일로 체험/갱신 시나리오 로컬 검증.

## 7. 운영 노트 (리서치 기반)

- **주간 구독 리스크**: RevenueCat — 주간 플랜 첫 갱신 이탈 30–50%, 12개월 리텐션 3.4%(최저). 출시 후 연간 플랜 추가 + 주간 권장 구조(2플랜이 업계 최다 구성)를 A/B 후보로.
- **체험 기간**: 3일 체험은 Day 0 즉시 취소율 55%로 최고 — 타임라인·D-2 알림 설계가 이를 상쇄하는 장치. 기간 자체는 추후 자체 A/B.
- **온보딩 확장 후보**: Noom식 "맞춤 준비 중" 로딩 연출(labor illusion), 질문 추가. 현재는 1문항으로 시작.
- **주간+3일 체험 조합 검증됨**: Adapty 2026 — 주간+3일 무료 체험이 최고 성과 조합(12개월 LTV 1.5배), Photo&Video 카테고리는 체험의 91.2%가 Day 0 시작(온보딩 페이월이 사실상 표준), 주간가 $4.99–9.99 클러스터. 단 하드 페이월은 전환율이 소프트 대비 낮으므로(LTV는 +21%) 가치 시연(샘플 필름) 뒤 배치가 조건.
- **사회적 증거 추가 시**: 페이월 화면 안이 아니라 **페이월 직전 별도 화면**으로 (Remini "115M MAU" 패턴). "지금까지 만들어진 필름 N개" 카운터·App Store 평점 등 실지표 확보 후.
- **페이월 개인화**: `selectedInterest`를 페이월 서브카피에 바인딩 ("여행 필름, 3일 무료로 만들어보세요") — Airbridge/paywallpro 권고.

## 8. 주요 출처

- growth.design — Blinkist Trial Paywall Challenge / Duolingo Retention / Headspace JTBD
- Purchasely — Headspace×Irrational Labs 온보딩 실험 (Perceived Fit 31%→63%) / Blinkist 페이월 수치
- First Round Review — Duolingo 가입 지연 DAU +20%
- Amplitude — Calm 리마인더 리텐션 3배
- RevenueCat — State of Subscription Apps 2025/2026, Weekly Subscriptions, Schedule 2 §3.8(b) 가이드
- Apple — App Review Guidelines 3.1.2 / Schedule 2 §3.8(b)
- Adapty — 고성과 페이월 2026 (주간+3일 체험 LTV 1.5배) / 구독 현황 2026 (Photo&Video Day 0 체험 91.2%)
- Airbridge — 페이월 전 온보딩 5단계 (체험의 82%가 Day 0 시작)
- screensdesign — Remini UI Breakdown (비주얼 퀴즈 + 페이월 직전 사회적 증거) / Purchasely — 사진·영상 앱 페이월 20선 (Videoleap 타임라인)

## 9. 작업 순서

1. ~~Figma `1.2.0` 페이지에 화면 추가~~ (완료 — 리서치 반영판 6화면)
2. 사용자 확인 후 SwiftUI 구현 (writing-plans 스킬로 상세 계획 후 진행)
