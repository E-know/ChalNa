# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# ChalNa — iOS 앱

Live Photo와 동영상을 촬영일 순서로 이어붙여 Vlog를 만드는 iOS 앱.

> **네이밍**: Tuist 타겟·Xcode 프로젝트·번들 ID·디자인 시스템 brand prefix 모두 `ChalNa`(`ios.inho.ChalNa`, `ChalNaColor`, `ChalNaTypography`, `ChalNaButton` 등)로 통일. 단 **디자인 토큰의 실제 값은 "Danawa DDS Mobile v2.0"** 으로 교체돼 있다 (식별자명만 ChalNa, 값은 다나와 톤 — 아래 디자인 시스템 참고).

## 빌드 / 실행 / 테스트

**Tuist** 기반이라 `.xcodeproj`/`.xcworkspace`는 생성물이다. 클론 직후 또는 `Project.swift` / `Tuist/Package.swift` 수정 후에는 **반드시 재생성**한다.

```bash
# Xcode 프로젝트 생성/갱신 (필수, 첫 셋업·의존성 변경 후)
tuist generate

# 워크스페이스 열기
open ChalNa.xcworkspace

# CLI 빌드 (시뮬레이터)
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# 전체 테스트
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# 단일 테스트 (Swift Testing 파일/케이스 단위). 테스트 타겟명은 `<모듈>Tests`.
xcodebuild ... test \
  -only-testing:TimelineFeatureTests/TimelinePlaybackTests/testAdvancePlayheadSimulated_UpdatesCurrentIndex
```

- **스킴이 두 개다**:
  - `ChalNa` — 실제 사진 라이브러리 사용(`AppMode.real`).
  - `ChalNa Dev` — `CHALNA_APP_MODE=devMock` 환경변수를 주입해 **번들 고정 fixture 미디어**(`BundledDevMediaSource`)로 동작. 사진 권한 없이 전체 플로우를 돌릴 때 사용 (DEBUG 빌드 한정).
- 단일 모듈만 빌드/포커스: `tuist focus <Module>` (예: `tuist focus DesignSystem`).
- 의존성 그래프: `tuist graph` → `docs/architecture-graph.png`.
- iOS 빌드/시뮬레이터 실행은 가능하면 `ios-build-run` 서브에이전트에 위임한다 (매번 fresh build → 설치/실행으로 시각 검증).
- 테스트 타겟: `AppCoreTests` · `CompositionServiceTests` · `PhotosServiceTests` · `TimelineFeatureTests`. 케이스는 SwiftUI Preview 보조용 `SampleData`를 적극 활용한다.

## 기술 스택 (엄수)
- **Swift 6.0+, iOS 18+** (`AVAssetExportSession` async API 등으로 deployment 18 고정).
- **SwiftUI 전용** (UIKit은 `PHPickerViewController`, `AVPlayerViewController`, edge swipe-back 같은 불가피한 경우에만 `UIViewControllerRepresentable`로 래핑).
- **The Composable Architecture (TCA)** — Feature 는 `@Reducer` + `@ObservableState`, 의존성은 `@Dependency`. SPM `swift-composable-architecture` 1.18+.
- **Firebase Analytics** — `FirebaseAnalytics` (SPM `firebase-ios-sdk` 12.13.0, staticFramework). 모든 Firebase 제품은 `Tuist/Package.swift`의 `PackageSettings`에서 staticFramework 로 강제.
- **Swift Concurrency 전용**: `async/await`, `actor`, `Task`, `AsyncStream`.
  - **GCD(`DispatchQueue`/`DispatchGroup` 등) 금지**. 콜백 API는 `withChecked(Throwing)Continuation`으로 async 래핑.
- **Observation(`@Observable`) + TCA `@ObservableState`** 사용. `ObservableObject`/`@Published` **금지**.
- **Swift Testing** (`import Testing`, `@Test`, `#expect`) 사용. XCTest 금지 (UI 테스트 제외).

## 아키텍처

### 패턴 — TCA + @Observable 하이브리드
- 각 Feature 는 **TCA Reducer**(`XxxFeature.swift`) + **View**(`XxxView.swift`) 한 쌍.
- 루트는 `AppFeature`(TCA `@Reducer`). `RootView`가 `Store(initialState: AppFeature.State()) { AppFeature() }`를 `@State`로 한 번 생성.
- **네비게이션은 TCA `StackState` 기반**이지만, 화면 전환을 *트리거*하는 건 `AppRouter`(`@Observable`), 화면 간 **편집 상태 공유**는 `EditSession`(`@Observable`)이 담당한다 (아래 런타임 흐름 참고).
- ViewModel 류 단일 화면 상태는 TCA State 로 두되, 재생 컨트롤러처럼 명령형 상태는 `@Observable` 모델(예: `TimelineModel`, `ClipPlaybackController`)을 따로 둘 수 있다.

### 모듈 그래프 (Tuist 멀티 타겟, 의존 방향 위 → 아래)
앱은 얇은 셸이고 레이어/피처는 모듈로 쪼개져 있다. **`Modules/<Name>/Sources/`** 가 표준 위치, 리소스는 `Modules/<Name>/Resources/`, 테스트는 `Modules/<Name>/Tests/`.

```
앱 셸     ChalNa  ── @main ChalNaApp · ContentView · App/{AppFeature(TCA root)·RootView·AppMode}
            │
Feature   HomeFeature · MediaPickerFeature · TimelineFeature · ExportFeature · FilmDetailFeature
(모두 @Reducer)   │  (Feature끼리 직접 import 금지)
            │
서비스/코어  AppCore(AppRouter·EditSession) · PhotosService · CompositionService · AnalyticsService
            │
모델/DS    Models ·····  DesignSystem (dynamic framework, 의존 없음 = 최하단)
            │
저장        FileStorage (FilmStorage)

External(SPM): ComposableArchitecture(TCA) · FirebaseAnalytics
```

핵심 의존 규칙 (`Project.swift`가 단일 출처):
- **DesignSystem / FileStorage** 는 다른 모듈에 의존하지 않는다 (최하단). DesignSystem 은 `isDynamic: true`(동적 프레임워크).
- **Models → FileStorage** 만 의존. (과거의 DesignSystem 의존은 제거됨 — 색상 hex 헬퍼를 Models 자체 `ColorHex.swift`로 내재화)
- **PhotosService / CompositionService → Models, TCA**. **AnalyticsService → TCA, FirebaseAnalytics** (Models 도 모름).
- **AppCore → Models, TCA** (Feature 모름).
- **Feature → AppCore + 필요한 서비스 + Models + DesignSystem + TCA**. Feature 끼리는 절대 직접 import 안 한다 — 화면 전환은 AppCore 의 `AppRouter`로.
- 앱 타겟은 `OTHER_LDFLAGS = -ObjC` 를 강제한다 (Firebase ObjC 카테고리가 dead-code-strip 되어 `unrecognized selector` 나는 것 방지).
- 새 모듈: `Tuist/ProjectDescriptionHelpers/Module.swift`의 `Module.framework(name:hasResources:isDynamic:dependencies:)` / `Module.unitTests(for:)` 헬퍼 사용 → `Project.swift`에 추가 → `tuist generate`.

### 런타임 흐름 (반드시 숙지)
1. `ChalNaApp`(`@main`) `init` 에서 **Firebase 설정 + TCA dependency override**:
   - `GoogleService-Info.plist`(번들: `ChalNa/Resources/`)가 있으면 `FirebaseApp.configure()` 후 `FirebaseAnalyticsTracker`, 없으면 `NoopAnalyticsTracker` 로 `prepareDependencies { $0.analyticsTracker = ... }`.
   - `WindowGroup { ContentView() }.modelContainer(for: Film.self)`. 새 `@Model` 추가 시 이 시그니처 갱신.
2. `ContentView` → `RootView`. `RootView`가 세 객체를 만든다: TCA `Store`(AppFeature), `AppRouter`, `EditSession`.
3. **네비게이션**: `NavigationStack(path: $store.scope(state: \.path, action: \.path))`. `AppFeature`의 `Path` enum(`mediaPicker`/`timeline`/`export`/`filmDetail`)이 스택 케이스. 루트는 `home`(Scope).
4. **전환 트리거(AppRouter 호환 레이어)**: Feature View 는 `@Environment(AppRouter.self)`로 받아 `router.push(.timeline)` / `router.pop()` 호출 → `RootView.wireRouterHandlers()`가 이를 `store.send(.routerPushedTimeline)` 등 TCA 액션으로 변환 → 리듀서가 `state.path.append(...)`. 즉 **Reducer 의 네비게이션 인텐트 액션은 보통 `.none` 을 반환하고 실제 push/pop 은 View+Router 가 처리**한다.
5. **편집 상태 전달**: 선택한 `[Clip]`·제목·회전(`rotations`)은 Route payload 나 TCA State 가 아니라 **`EditSession`(`@Environment(EditSession.self)`)에 실어** MediaPicker → Timeline → Export 로 흘려보낸다. (`session.replace(clips:title:)`, `session.cycleRotation()` 등)
6. **AppMode / devMock**: `App/AppMode.swift`의 `AppMode.current` 가 DEBUG + `CHALNA_APP_MODE=devMock` 일 때 `.devMock`. `RootView`가 MediaPicker 소스를 `.photoLibrary` ↔ `.devFixtures(BundledDevMediaSource())`로 분기.
7. 모든 push 화면은 `.toolbar(.hidden, for: .navigationBar)` + `.navigationBarBackButtonHidden(true)` + 커스텀 `.chalNaSwipeBack()`(좌측 엣지 스와이프) 패턴을 적용한다.

### 모델 / 영속화 경계
- **`Clip`** (`Models/Clip.swift`) — 편집 세션의 in-memory **value type(struct)**, SwiftData 아님. 필드: `id·kind·capturedAt·duration·preset·thumbnailData·videoURL·locationNote·displaySize`. `videoURL == nil` 이면 합성에서 스킵. `displaySize`는 `preferredTransform` 적용 후 표시 사이즈(출력 캔버스/정렬용).
- **`Film`** (`Models/Film.swift`) — `@Model`(SwiftData) 라이브러리 단위. mp4 는 `Documents/films/<id>.mp4` 로 복사하고 모델엔 **상대 경로(`movieFilename`)**만 둔다(앱 재설치 시 절대 경로가 바뀌므로 — `movieURL` computed 로 복원). 표지 썸네일은 `@Attribute(.externalStorage)`.
- **`FileStorage` 모듈의 `FilmStorage`** 가 파일 IO 담당: `importMovie(from:filmID:)`(temp → `films/<uuid>.mp4`, 상대경로 반환), `deleteMovie(filename:)`, `moviesDirectoryURL`.
- **`ThumbnailPreset`** — 12종 여행 톤 그라디언트 enum(`view()`로 SwiftUI 뷰). `Clip.thumbnailView()`(`Clip+Thumbnail.swift`)는 실사 썸네일이 있으면 그걸, 없으면 preset 그라디언트를 fallback 으로 그린다.
- **`SampleData`** — Preview/Test 용. `jejuTimeline`(8개 Clip), `groupedByDay()` 헬퍼 등.

## 서비스 레이어 & 의존성 주입
- **TCA `@Dependency` + `@DependencyClient` 패턴**. 각 서비스는 *클로저 묶음 struct*(Client)로 노출하고 `DependencyKey`의 `liveValue`/`testValue`(필요시 `previewValue`) 제공. **생성자 주입/서드파티 DI 프레임워크 사용 안 함**.
  - `CompositionClient` (`compositionClient`) — liveValue 가 `AVFoundationCompositionService` actor 를 래핑.
  - `PhotoLibraryClient` (`photoLibraryClient`) — 권한/PHAsset 조회/Live Photo 추출/저장 등 클로저 묶음. live 헬퍼 함수들이 구현.
  - `AnalyticsTrackerKey` (`analyticsTracker`) — 기본 live/test/preview 모두 `NoopAnalyticsTracker`, 실제 Firebase 주입은 `ChalNaApp.init`의 `prepareDependencies`에서.
- 무거운 구현은 **`actor`** (`AVFoundationCompositionService`, `BundledDevMediaSource`, `MockPhotoLibraryService`). 프로토콜(`...Servicing`)로 추상화.
- 진행률/스트리밍은 **`AsyncStream`** 으로 래핑 (예: `CompositionService`의 `export()`가 `AsyncStream<ExportEvent>` 반환 — `.progress/.completed/.failed`).
- Feature 에선 `@Dependency(\.compositionClient) var compositionClient` 처럼 주입받아 `.run { send in ... }` effect 안에서 호출.

### Analytics
- `AnalyticsTracker` 프로토콜: `log(_:)`, `setUserProperty(_:forName:)`. 구현은 `FirebaseAnalyticsTracker` / `NoopAnalyticsTracker`.
- 이벤트는 `AnalyticsEvent` enum 으로 타입 안전하게 정의 (`name`=Firebase snake_case, `parameters`=dict). 추가 이벤트는 여기 case 로.
- Feature 에서 `@Dependency(\.analyticsTracker)` 로 받아 `analytics.log(.exportStarted(clipCount:))` 형태로 호출.

## Photos 프레임워크 원칙
- `PHPickerViewController`로 선택 (권한 최소화). PhotoKit 접근은 `PhotosService` 모듈을 통해서만.
- **`PickedMediaLoader`** — PHPicker 결과(`NSItemProvider`/`PHPickerResult`)에서 직접 추출: Live Photo 는 `PHLivePhoto` → paired video, 일반 비디오는 `loadFileRepresentation` → temp 복사. 썸네일·촬영일·길이·displaySize 메타도 로드.
- `PHAsset` 재조회가 필요하면 `PHAsset.fetchAssets(withLocalIdentifiers:)`. Live Photo 비디오는 `PHAssetResource`의 `.pairedVideo`/`.fullSizePairedVideo` 우선.
- **`DevMediaSource`** (`BundledDevMediaSource` actor) — devMock 전용. 번들 `DevFixtures` mp4 를 고정 ID(`dev-jeju-sea` 등)로 제공.

## 비디오 합성 원칙
- `AVMutableComposition` + `AVMutableVideoComposition`. 모든 트랙 조작은 **`CompositionService` actor 내부에서만**.
- 익스포트는 `AVAssetExportSession` + `AsyncStream<ExportEvent>`로 진행률 폴링/래핑.
- 출력 영상 중앙 시간 라벨은 `CATextLayer`로 합성하며, **`UIAppFonts`에 등록된 KERISKEDU 패밀리**(`ChalNa/Resources/Fonts/KERISKEDU/`) 폰트를 PostScript 이름 매칭으로 사용(없으면 시스템 bold fallback).

## 에러 처리
- `throws` 사용, `Result` 타입은 지양(Swift 6).
- 도메인 에러는 **`LocalizedError` 채택 enum** (예: `ExportError`, `DevMediaError`). 사용자 표시 메시지는 `errorDescription`으로 분리.

## 코드 컨벤션
- 타입 추론이 명확하면 타입 생략, 공개 API 는 명시. `self.` 는 클로저/이니셜라이저 외 생략.
- **Spacing/padding 은 토큰 없이 리터럴 숫자**(`.padding(16)`, `HStack(spacing: 8)`). 색/타이포/라디우스/섀도우는 토큰 사용.
- 한국어 주석 OK, 식별자는 영어. 한 파일 = 한 타입 (긴밀히 결합된 small helper 는 예외).

## 디자인 시스템 (ChalNa 식별자 / Danawa DDS Mobile v2.0 값)

모든 UI 는 `Modules/DesignSystem/Sources/` 토큰·컴포넌트를 사용한다 (**spacing/padding 만 리터럴 숫자**). **리터럴 HEX·시스템 폰트 직접 호출 금지**. 새 컴포넌트 전에 기존 것 재사용.

### 파일 레이아웃
```
DesignSystem/Sources/
├─ Tokens/      ChalNaColor · ChalNaTypography · ChalNaRadius · ChalNaShadow
├─ Components/  ChalNaButton · ChalNaChip · ChalNaTextField · ChalNaBottomSheet
│               ClipThumbCard · LiveBadge · ChalNaHeaderActionButtonStyle
├─ Modifiers/   View+ChalNaScreen · +ChalNaTopBar · +ChalNaSwipeBack
│               +ChalNaHitTarget · +ScrollProgress
├─ Icons/       ChalNaIcon (Lucide 스타일 라인 아이콘 20종)
└─ Showcase/    DesignSystemShowcaseView
```

### Colors — `ChalNaColor` (Asset Catalog `Assets.xcassets/Colors/ChalNa*.colorset`)
| API | 톤 | 용도 |
|---|---|---|
| `.cream` | White `#FFFFFF` | Background |
| `.ivory` | Gray-50 `#F8F8F8` | Surface |
| `.coral` | **Purple-600 `#8B38E5`** | **Primary / CTA** |
| `.sage`  | Cyan `#02B8D3` | Success / Info accent |
| `.denim` | Blue-500 `#2070EB` | Link / Secondary |
| `.ink`   | Gray-900 `#1A1A1A` | Text Primary |
| `.taupe` | Gray-500 `#919191` | Text Sub |

- 스케일 enum: `ChalNaColor.Purple.p100…p900`(p600=coral=Primary), `.Blue.b50…b900`(b500=denim), `.Gray.g50…g900`(g50=ivory·g500=taupe·g900=ink).
- 상태: `.success #06B87F` · `.danger #E53B38`(Live/Error) · `.info #02B8D3`.
- `.Chip.{live,video,film}Background/Foreground` — LIVE=Red 톤, Video=Purple 톤, Film=Blue 톤.

### Typography — `ChalNaTypography` (시스템 폰트 + SF Mono)
- KR 본문/제목은 **시스템 폰트**: `.krBody(size, weight:)` · `.krSemibold(size)` · `.displayKR(size, weight:)` · `.title(size, weight:)`.
- Mono(스펙/숫자): `.mono(size, weight:)` / `.monoFallback(...)` = SF Mono.
- **Legacy stub**(빌드 호환용, 신규 사용 자제): `displayEN`/`serifFallback`/`hand`/`handFallback` 는 전부 `krBody`로 매핑됨 (과거 Fraunces/Caveat/BradleyHand 의존 제거).
- 스케일 `Size`: `tag(12)·caption(12)·small(14)·body2(15)·body(16)·bodyLg(18)·header(19)·h2(20)·big(22)·h1(24)·displayS(28)·displayL(32)`. (다나와 가이드: 11px 이하 컨텐츠 금지, 14px 이하 사용 제한)
- `Tracking`: `titleKR(-0.20)·bodyKR(-0.30)·priceKR(-0.40)`.
- tag label 은 `Text("...").tagLabel()`.

### Radius — `ChalNaRadius` (4px 단위)
`.film 4` · `.button 4` · `.card 8` · `.sheet 16` · `.pill 999`.

### Shadow — `ChalNaShadow` + `View.chalNaShadow(_:)`
`.sm`(black10, blur2) · `.md`(black20, blur6 — 탭바 표준) · `.lg`(2단 중첩).

### Core Components
| 컴포넌트 | 사용 예 |
|---|---|
| 버튼 | `Button{}.buttonStyle(.chalNa(.filled, size: .lg, fillWidth: true))` — variant `filled/outlined/standardFilled/standardOutlined/text`, size `xl/lg/md/sm`. 축약 `.chalNaFilled/.chalNaOutlined/.chalNaText` (구 alias `.chalNaCoral/.chalNaOutline` 호환) |
| 칩 | `ChalNaChip("LIVE", variant: .live, icon: .film)` |
| 입력 | `ChalNaTextField(...)` |
| 시트 | `ChalNaBottomSheet(...)` |
| 클립 카드 | `ClipThumbCard(...)` · `LiveBadge()` |
| 아이콘 | `ChalNaIcon(.play, size: 24)` — 20종(play/pause/plus/share/download/heart/calendar/film/chevronLeft/chevronRight/close/check/skipBack/skipForward/scissors/reorderLines/trash/music/move/rotate) |
| 화면 배경 | `someView.chalNaScreen()` — 배경 `ChalNaColor.cream` 풀블리드. (구버전 paperGrain/vignette 오버레이는 **제거됨**) |
| 상단바 | `.chalNaTopBar(...)` modifier |

### 금지 사항
- `Color(hex:)`/`Color(red:green:blue:)` **직접 호출 금지** — `ChalNaColor.*` 사용 (hex 이니셜라이저는 토큰 정의 내부 전용).
- `.font(.system(...))` 직접 호출 금지 — `ChalNaTypography.*` 경유.
- `.cornerRadius(15)` 같은 리터럴 금지 — `ChalNaRadius.*`.
- `UIColor`/`UIFont` 직접 참조 금지 (CompositionService 의 비디오 텍스트 오버레이는 불가피한 예외).

## 테스트
- 서비스/모델은 **Swift Testing**(`@Test`/`#expect`)으로 작성, `SampleData` 활용. actor/Client 는 프로토콜 + `testValue` 로 격리.
- 모델·서비스를 직접(예: `TimelineModel`, `AVFoundationCompositionService().export(...)`) 테스트하거나, 필요 시 TCA `TestStore` 사용 가능.
- UI 는 스냅샷 대신 `#Preview` 적극 활용 (각 뷰 상태별).

## 커밋 / PR
- 단계가 끝나면 커밋, 메시지 한국어 OK. Claude 가 커밋할 땐 변경 파일 요약을 한국어로.

> **참고**: 루트의 `AGENTS.md` 는 이 문서의 미러본(앞부분 Codex workflow 노트만 추가)이다. CLAUDE.md 를 고치면 AGENTS.md 도 함께 동기화한다.
