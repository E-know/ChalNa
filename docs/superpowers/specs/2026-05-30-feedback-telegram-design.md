# 설계: 설정(Settings) 화면 — 불편 신고 → Telegram 봇 전송

- 날짜: 2026-05-30
- 대상 앱: ChalNa (iOS, Tuist + SwiftUI + TCA)
- 작성 근거: 사용자 요청(브레인스토밍 합의) + 코드베이스 현황 + Telegram Bot API

## 1. 목표

1. **설정 화면**에 "문의·신고" 메뉴 행을 추가하고, 탭하면 신고 하위 화면으로 push 한다.
2. **신고 화면**에서 사용자가 불편/버그/제안을 자유 텍스트로 작성한다.
3. **카테고리**(버그/제안/기타)를 선택하고, **앱·기기 메타데이터**(앱 버전·빌드·iOS 버전·기기 모델)를 자동 첨부한다.
4. "전송"을 누르면 **Telegram 봇(`@ChalNa_CS_bot`)** 으로 신고 내용을 보낸다. 성공/실패를 사용자에게 알린다.

## 2. 비목표 (YAGNI)

- 연락처(이메일) 입력 — 이번 범위 제외(사용자 합의).
- 첨부 파일/스크린샷 전송 — 텍스트 신고만.
- 신고 이력 저장/목록 — 보내고 끝(로컬 영속화 없음).
- 백엔드 프록시 — 앱에 백엔드가 없어 토큰을 클라이언트에 내장(결정 D2).
- 별도 `SupportService` Tuist 모듈 — 단일 기능이라 `SettingsFeature` 내부에 둔다(결정 D1).
- 답장 수신(봇 → 앱) — 단방향 송신만.

## 3. 합의된 결정

- **D1 — 코드 위치(접근 B)**: 텔레그램 전송 코드를 **새 모듈 대신 `SettingsFeature` 모듈 내부**에 둔다. `@DependencyClient`로 감싸 목/테스트 가능성은 유지한다. 신고는 설정 화면 전용 단일 POST라 새 Tuist 모듈은 오버엔지니어링. 향후 지원 기능(FAQ·평점 등)이 늘면 그때 `SupportService` 모듈로 승격한다.
- **D2 — 토큰 보안**: 봇 토큰을 **앱 클라이언트에 내장**한다(사용자 합의). 앱 바이너리 디컴파일 시 토큰 추출이 가능하다는 리스크를 인지하고 수용한다. 우려 시 차후 프록시 서버/원격 설정으로 전환 가능.
- **D3 — 수신처**: 신고는 **개발자 개인 Telegram 1:1 DM**(`chat_id = 7298669942`)으로 도착한다. 토큰·chat_id 검증 완료(getMe·getUpdates·sendMessage 실측 성공, `ok: true`).
- **D4 — 메시지 포맷**: `parse_mode` 미사용(사용자 입력의 특수문자 이스케이프 이슈 회피), 본문은 plain text. Telegram 4096자 제한에 맞춰 텍스트 클램프.
- **D5 — Analytics**: `feedbackSubmitted(category:)` / `feedbackSendFailed(reason:)` 이벤트 추가.
- **D6 — 디자인 언어**: 기존 코드의 Danawa DDS(흰 배경/보라 Primary/시스템 폰트)를 따른다. 신고 화면은 `LabelSettingsView`/`SettingsView`와 동일한 헤더·화면 패턴.

## 4. 현황 (앵커가 되는 기존 코드)

- `Modules/SettingsFeature/Sources/SettingsView.swift:23-27` — `menuRow(title:subtitle:action:)`로 메뉴 행 구성. "라벨" 행 1개 존재, 주석에 "여기에 행 추가" 안내.
- `Modules/SettingsFeature/Sources/SettingsFeature.swift:14-17` — `Action`에 `labelMenuTapped`. 메뉴 탭은 `.none` 반환, push는 View+Router 가 처리.
- `Modules/SettingsFeature/Sources/LabelSettingsFeature.swift` / `LabelSettingsView.swift` — 하위 화면 1쌍(Reducer+View)의 표준 패턴. 신고 화면이 미러할 대상.
- `Modules/AppCore/Sources/AppRouter.swift:6-14` — `Route` enum(`mediaPicker`/.../`settings`/`labelSettings`/`labelPosition`).
- `ChalNa/Sources/App/AppFeature.swift:42-51,94-104` — `Path` enum(`@Reducer`) + `routerPushed*` 액션 + `state.path.append(...)`.
- `ChalNa/Sources/App/RootView.swift:41-74` — `destinationView(for:)` switch + `wireRouterHandlers()` 라우트 분기.
- `Modules/CompositionService/Sources/CompositionClient.swift:6-35` — `@DependencyClient` + `DependencyKey`(liveValue/testValue) + `DependencyValues` 확장의 표준 패턴. `FeedbackClient`가 미러할 대상.
- `Modules/AnalyticsService/Sources/AnalyticsEvent.swift` — 이벤트 enum(`name`/`parameters`). 신고 이벤트 추가 위치.
- `Modules/DesignSystem/Sources/Components/ChalNaChip.swift:5-21` — `ChalNaChipVariant`에 `.selected`(ink 배경/흰 글씨)·`.dashed`(테두리만) 존재 → 카테고리 선택 칩에 사용.
- `Modules/DesignSystem/Sources/Components/ChalNaTextField.swift:34` — **단일 라인 `TextField`**. 신고 본문은 멀티라인이 필요하므로 `TextEditor` + placeholder 오버레이로 별도 구성.
- 네트워킹 코드: **없음**(URLSession 신규 도입).

## 5. 컴포넌트 설계 (모두 `Modules/SettingsFeature/Sources/`)

### 5.1 `FeedbackCategory` (신규 `Feedback.swift`)

```swift
public enum FeedbackCategory: String, CaseIterable, Sendable, Equatable {
    case bug, suggestion, other
    var koreanName: String   // 버그 / 제안 / 기타
    var emoji: String        // 🐞 / 💡 / 💬  (텔레그램 메시지 헤더용)
}
```

### 5.2 `FeedbackReport` (신규 `Feedback.swift`)

```swift
public struct FeedbackReport: Equatable, Sendable {
    public var text: String
    public var category: FeedbackCategory
    public var appVersion: String   // CFBundleShortVersionString
    public var build: String        // CFBundleVersion
    public var iosVersion: String   // UIDevice.current.systemVersion
    public var deviceModel: String  // sysctl "hw.machine" (예: iPhone16,1)
}
```

- `static func current(text:category:)` — 메타데이터를 런타임에서 수집해 채우는 팩토리.
- `var telegramMessageText: String` — 텔레그램에 보낼 plain text 포맷(순수 함수, **단위 테스트 대상**). 4096자 클램프.

  ```
  🐞 [버그] ChalNa 신고
  ────────────
  <사용자 텍스트>
  ────────────
  앱 1.0.0 (12) · iOS 18.4 · iPhone16,1
  ```

### 5.3 `FeedbackClient` (신규 `FeedbackClient.swift`, `@DependencyClient`)

```swift
@DependencyClient
public struct FeedbackClient: Sendable {
    public var send: @Sendable (FeedbackReport) async throws -> Void
}

extension FeedbackClient: DependencyKey {
    public static let liveValue: FeedbackClient   // URLSession POST → sendMessage
    public static let testValue = FeedbackClient() // no-op 기본값
}
public extension DependencyValues { var feedbackClient: FeedbackClient { ... } }
```

- liveValue: `https://api.telegram.org/bot<TOKEN>/sendMessage` 에 `application/x-www-form-urlencoded`로 `chat_id` + `text` POST. HTTP 200 & 응답 JSON `ok == true` 검증, 아니면 throw.
- `TelegramConfig`(파일 내 private enum): `token`, `chatID` 상수 보관(D2/D3).

### 5.4 `FeedbackError` (신규, `LocalizedError`)

```swift
enum FeedbackError: LocalizedError {
    case emptyText
    case network(Error)
    case telegram(description: String)  // ok=false 또는 비정상 status
    var errorDescription: String?       // 한국어 사용자 메시지
}
```

### 5.5 `SupportFeature` (신규 `SupportFeature.swift`, `@Reducer`)

- State: `text: String = ""`, `category: FeedbackCategory = .bug`, `isSending = false`, `alert: AlertState<Action.Alert>?`
- Action: `textChanged(String)`, `categorySelected(FeedbackCategory)`, `sendTapped`, `sendResponse(Result<Void, Error>)`, `alert(PresentationAction<Alert>)`
  - `sendTapped`: 공백 trim 후 빈 텍스트면 무시. 아니면 `isSending = true` → `.run`에서 `feedbackClient.send(.current(text:category:))` 호출 → 결과를 `sendResponse`로.
  - `sendResponse(.success)`: `isSending=false`, `text=""`, 성공 alert, `analytics.log(.feedbackSubmitted(category:))`.
  - `sendResponse(.failure)`: `isSending=false`, 실패 alert, `analytics.log(.feedbackSendFailed(reason:))`.

### 5.6 `SupportView` (신규 `SupportView.swift`)

- `LabelSettingsView`와 동일한 헤더(뒤로가기 + 제목 "문의·신고") + `.chalNaScreen()`.
- 카테고리 칩 행: `FeedbackCategory.allCases`를 `ChalNaChip`으로. 선택=`.selected`, 미선택=`.dashed`. 탭 시 `categorySelected`.
- 본문 입력: `TextEditor` + DS 토큰 스타일(테두리·radius·typography) + 비었을 때 placeholder 오버레이("불편한 점이나 제안을 자유롭게 적어주세요.").
- 전송 버튼: `.chalNa(.filled, size: .lg, fillWidth: true)`. `text` 공백이거나 `isSending`이면 비활성. `isSending`이면 ProgressView 표시.
- `.alert($store.scope(state: \.alert, action: \.alert))`.

## 6. 네비게이션 배선 (labelSettings와 동일 패턴)

1. `Modules/AppCore/Sources/AppRouter.swift` — `Route`에 `case support` 추가.
2. `ChalNa/Sources/App/AppFeature.swift`:
   - `Action`에 `case routerPushedSupport`
   - `Path`에 `case support(SupportFeature)`
   - 리듀서에 `case .routerPushedSupport: state.path.append(.support(SupportFeature.State())); return .none`
3. `ChalNa/Sources/App/RootView.swift`:
   - `destinationView`에 `case let .support(s): SupportView(store: s)`
   - `wireRouterHandlers`에 `case .support: store.send(.routerPushedSupport)`
4. `Modules/SettingsFeature/Sources/SettingsFeature.swift` — `Action`에 `case supportMenuTapped` 추가(`.none` 반환).
5. `Modules/SettingsFeature/Sources/SettingsView.swift` — "라벨" 행 아래 `Divider()` + `menuRow(title: "문의·신고", subtitle: "불편한 점이나 제안을 보내주세요")` → `store.send(.supportMenuTapped); router.push(.support)`.

## 7. Analytics

`Modules/AnalyticsService/Sources/AnalyticsEvent.swift`에 추가:

```swift
case feedbackSubmitted(category: String)   // "feedback_submitted", params {category}
case feedbackSendFailed(reason: String)    // "feedback_send_failed", params {reason}
```

## 8. 에러 처리 / 엣지

- 빈/공백 텍스트: 전송 버튼 비활성으로 1차 차단(`FeedbackError.emptyText`는 방어용).
- 네트워크 실패/타임아웃: `URLSession` 기본 타임아웃, throw → 실패 alert("전송에 실패했어요. 네트워크를 확인하고 다시 시도해 주세요.").
- 텔레그램 API `ok=false`: throw → 동일 실패 alert + analytics reason.
- 4096자 초과: `telegramMessageText`에서 clamp(말줄임).

## 9. 테스트 (Swift Testing, `Modules/SettingsFeature/Tests/`)

- **`FeedbackReportTests`**: `telegramMessageText` 포맷 검증(카테고리 이모지·헤더·메타 라인 포함), 4096자 클램프 동작 — 순수 함수라 네트워크 불필요.
- **`SupportFeatureTests`** (`TestStore`):
  1. 빈 텍스트 `sendTapped` → 상태 변화 없음(effect 없음).
  2. 정상 텍스트 → `isSending=true` → client(override)가 성공 → `sendResponse(.success)` → `isSending=false`, `text=""`, alert 표출.
  3. client(override) throw → `sendResponse(.failure)` → 실패 alert.
- 네트워크 호출 자체는 `feedbackClient`를 `withDependencies`로 override 하여 격리(실제 Telegram 미호출).

## 10. Project.swift / 빌드

- **모듈 추가 없음**(접근 B). `SettingsFeature`는 이미 `AppCore`/`AnalyticsService`/`Models`/`DesignSystem`/TCA 의존 → 추가 의존성 불필요(URLSession은 Foundation, UIDevice는 UIKit — 둘 다 기본 가용).
- `tuist generate` 불필요(새 파일은 `Modules/SettingsFeature/Sources/`의 buildable folder에 자동 포함). 단, 새 파일 인식이 안 되면 `tuist generate` 1회.
- 검증: `ChalNa` 스킴 빌드 + 시뮬레이터 실행 → 설정 → 문의·신고 → 작성 → 전송 → Telegram DM 도착 확인(`ios-build-run` 위임).

## 11. 작업 순서 (구현 계획의 뼈대)

1. `Feedback.swift`(Category·Report·메시지 포맷) → 포맷 테스트.
2. `FeedbackClient.swift`(@DependencyClient + liveValue/URLSession + TelegramConfig) + `FeedbackError`.
3. `SupportFeature.swift` → `SupportFeatureTests`.
4. `SupportView.swift`.
5. 네비게이션 배선(AppRouter·AppFeature·RootView·SettingsFeature·SettingsView).
6. Analytics 이벤트 2종.
7. 빌드·시뮬레이터 실측(전송 → DM 도착).
