# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# ChalNa — iOS 앱

Live Photo와 동영상을 촬영일 순서로 이어붙여 Vlog를 만드는 iOS 앱.

> **네이밍**: Tuist 타겟·Xcode 프로젝트·번들 ID·디자인 시스템 brand prefix 모두 `ChalNa`(`ios.inho.ChalNa`, `ChalNaColor`, `ChalNaTypography`, `ChalNaButton` 등)로 통일. **디자인 토큰 값은 2026-07-28 다크 리디자인으로 전면 교체됐다** — 과거엔 식별자만 ChalNa, 값은 라이트 톤의 "Danawa DDS Mobile v2.0"였으나 지금은 값도 자체 다크 시맨틱 팔레트다 (근거: `docs/superpowers/specs/2026-07-28-app-redesign-design.md`). 디자인은 **다크 시네마틱**이며, 액센트(`.accent`)는 새로 발명한 색이 아니라 **앱 아이콘의 인디고(`brandDeep` `#462DE2`)에서 밝기를 올려 역산**한 것이다(아이콘 원색은 `bg` 대비 2.4:1 라 인터랙션에 못 쓴다 — 아래 Colors 참고). 앱은 **다크 전용**이며 `Project.swift` 의 `infoPlist` 에 박아넣은 `UIUserInterfaceStyle: "Dark"` 가 라이트 모드 전환을 막는다 — 아래 디자인 시스템 참고.

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
- **유닛 테스트 타겟은 8개** (`Project.swift`의 `Module.unitTests(for:)` 8회 호출): `AppCoreTests` · `ExportFeatureTests` · `CompositionServiceTests` · `PhotosServiceTests` · `TimelineFeatureTests` · `MediaPickerFeatureTests` · `SettingsFeatureTests` · `DesignSystemTests`. 케이스는 SwiftUI Preview 보조용 `SampleData`를 적극 활용한다.
- **Tuist 는 테스트 타겟을 위한 별도 스킴을 만들지 않는다.** `<Module>Tests` 타겟은 베이스 모듈(`<Module>`) 이 자동 생성하는 스킴에 Test 액션으로 붙는다. 즉 `-scheme DesignSystemTests` 는 존재하지 않고, `-scheme DesignSystem` · `-scheme SettingsFeature` · `-scheme TimelineFeature` 처럼 **베이스 모듈명**으로 실행해야 한다 (`-only-testing:` 의 대상은 타겟명 `<모듈>Tests` 그대로 맞다).
- **UI 테스트**는 별도로 `ChalNaUITests` 타겟(`ChalNa` 앱 타겟에 의존, `-scheme ChalNa`로 실행)에 있다 — `CropAdjustUITests` · `LabelEditorUITests`(키보드 도달성 + Dynamic Type 상한 2케이스) · `TimelineLayoutUITests`. 여기가 **XCTest 의 유일한 예외 대상**(devMock 시각 검증용, 아래 "기술 스택" 참고).

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
- **네비게이션은 TCA `StackState` 기반**. push 는 자식 Feature 의 `delegate` 액션을 `AppFeature`가 path 조작으로 해석, pop 은 자식 리듀서의 `@Dependency(\.dismiss)`. 화면 간 **편집 상태 공유**는 `EditSession`(`@Observable`, `@Dependency(\.editSession)` 겸용)이 담당한다 (아래 런타임 흐름 참고).
- ViewModel 류 단일 화면 상태는 TCA State 로 두되, 재생 컨트롤러처럼 명령형 상태는 `@Observable` 모델(예: `TimelineModel`, `ClipPlaybackController`)을 따로 둘 수 있다.

### 모듈 그래프 (Tuist 멀티 타겟, 의존 방향 위 → 아래)
앱은 얇은 셸이고 레이어/피처는 모듈로 쪼개져 있다. **`Modules/<Name>/Sources/`** 가 표준 위치, 리소스는 `Modules/<Name>/Resources/`, 테스트는 `Modules/<Name>/Tests/`.

```
앱 셸     ChalNa  ── @main ChalNaApp · ContentView · App/{AppFeature(TCA root)·RootView·AppMode}
            │
Feature   HomeFeature · MediaPickerFeature · TimelineFeature · ExportFeature · FilmDetailFeature
(모두 @Reducer)   │  (Feature끼리 직접 import 금지)
            │
서비스/코어  AppCore(EditSession) · PhotosService · CompositionService · AnalyticsService
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
- **Feature → AppCore + 필요한 서비스 + Models + DesignSystem + TCA**. Feature 끼리는 절대 직접 import 안 한다 — 화면 전환은 자기 모듈의 `delegate` 액션으로 선언만 하고, 해석(매핑)은 앱 셸의 `AppFeature`가 한다.
- 앱 타겟은 `OTHER_LDFLAGS = -ObjC` 를 강제한다 (Firebase ObjC 카테고리가 dead-code-strip 되어 `unrecognized selector` 나는 것 방지).
- 새 모듈: `Tuist/ProjectDescriptionHelpers/Module.swift`의 `Module.framework(name:hasResources:isDynamic:dependencies:)` / `Module.unitTests(for:)` 헬퍼 사용 → `Project.swift`에 추가 → `tuist generate`.

### 런타임 흐름 (반드시 숙지)
1. `ChalNaApp`(`@main`) `init` 에서 **Firebase 설정 + TCA dependency override**:
   - `GoogleService-Info.plist`(번들: `ChalNa/Resources/`)가 있으면 `FirebaseApp.configure()` 후 `FirebaseAnalyticsTracker`, 없으면 `NoopAnalyticsTracker` 로 `prepareDependencies { $0.analyticsTracker = ... }`.
   - `WindowGroup { ContentView() }.modelContainer(for: Film.self)`. 새 `@Model` 추가 시 이 시그니처 갱신.
2. `ContentView` → `RootView`. `RootView`는 TCA `Store`(AppFeature)를 `@State`로 만들고, `EditSession` 은 `@Dependency(\.editSession)`(liveValue 싱글턴)에서 얻어 environment 로도 주입한다 — **Reducer 와 View 가 같은 인스턴스를 공유**.
3. **네비게이션**: `NavigationStack(path: $store.scope(state: \.path, action: \.path))`. `AppFeature`의 `Path` enum(`mediaPicker`/`timeline`/`export`/`filmDetail`/`settings`/...)이 스택 케이스. 루트는 `home`(Scope).
4. **전환 트리거(delegate 패턴)**: 자식 Feature 는 `Action.Delegate` enum 으로 네비게이션 인텐트를 선언하고(예: MediaPicker 의 `.selectionConfirmed(clips:title:)`), 리듀서가 비즈니스 로직 결과로 `.send(.delegate(...))` 를 방출 → `AppFeature`가 `case .path(.element(id:action:.mediaPicker(.delegate(...))))` 매칭으로 `state.path.append/removeAll` 수행. **pop 은 자식 리듀서가 `@Dependency(\.dismiss)` 로 직접** (`.run { _ in await dismiss() }`). View 는 `store.send(...)`만 하고 화면 전환을 모른다.
5. **편집 상태 전달**: 선택한 `[Clip]`·제목·회전(`rotations`)은 Route payload 나 TCA State 가 아니라 **`EditSession`에 실어** MediaPicker → Timeline → Export 로 흘려보낸다. View 는 `@Environment(EditSession.self)`, Reducer 는 `@Dependency(\.editSession)` 로 접근 (예: AppFeature 가 `selectionConfirmed` delegate 를 받으면 `editSession.replace(clips:title:)` 후 Timeline push).
6. **AppMode / devMock**: `App/AppMode.swift`의 `AppMode.current` 가 DEBUG + `CHALNA_APP_MODE=devMock` 일 때 `.devMock`. `AppFeature`가 MediaPicker push 시 소스를 `.photoLibrary` ↔ `.devFixtures(BundledDevMediaSource())`로 분기.
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
- **출력은 1080×1920(9:16 세로) 고정, 클립은 aspectFill 센터 크롭**이 기본(`ClipTransform.fill`, scale 하한 1.0 — 여백/블러 배경 없음). 배치 기하 SSOT 는 `ClipFraming`(Models)이고 프리뷰·조정 화면·export 가 공유한다(WYSIWYG). 사용자 크롭 조정(줌/이동)은 `EditSession.transforms`.
- `AVMutableComposition` + `AVMutableVideoComposition`. 모든 트랙 조작은 **`CompositionService` actor 내부에서만**.
- 익스포트는 `AVAssetExportSession` + `AsyncStream<ExportEvent>`로 진행률 폴링/래핑.
- 출력 영상 중앙 시간 라벨은 `CATextLayer`로 합성하며, **`UIAppFonts`에 등록된 KERISKEDU 패밀리**(`ChalNa/Resources/Fonts/KERISKEDU/`) 폰트를 PostScript 이름 매칭으로 사용(없으면 시스템 bold fallback).

## 에러 처리
- `throws` 사용, `Result` 타입은 지양(Swift 6).
- 도메인 에러는 **`LocalizedError` 채택 enum** (예: `ExportError`, `DevMediaError`). 사용자 표시 메시지는 `errorDescription`으로 분리.

## 코드 컨벤션
- 타입 추론이 명확하면 타입 생략, 공개 API 는 명시. `self.` 는 클로저/이니셜라이저 외 생략.
- **Spacing/padding 은 토큰 없이 리터럴 숫자**(`.padding(16)`, `HStack(spacing: 8)`). 색/타이포/라디우스/섀도우는 토큰 사용. 리듬은 `4/8/12/16/20/24`, **화면 좌우 여백은 20 으로 통일**(코드베이스 전체에서 `.padding(.horizontal, 20)` 이 다른 값들을 압도적으로 앞선다).
- 한국어 주석 OK, 식별자는 영어. 한 파일 = 한 타입 (긴밀히 결합된 small helper 는 예외).

## 디자인 시스템 (ChalNa 식별자 / 다크 전용 시맨틱 값)

모든 UI 는 `Modules/DesignSystem/Sources/` 토큰·컴포넌트를 사용한다 (**spacing/padding 만 리터럴 숫자**). **리터럴 HEX·시스템 폰트 직접 호출 금지**. 새 컴포넌트 전에 기존 것 재사용. 앱은 다크 전용이다 — 라이트 모드 분기를 만들지 않는다. 이 절의 금지 사항은 프로즈로만 끝나지 않고 `scripts/design-lint.sh` 가 정적 검사로 강제한다 (아래 "금지 사항" 참고).

### 파일 레이아웃
```
DesignSystem/Sources/
├─ Tokens/      ChalNaColor · ChalNaTypography · ChalNaRadius · ChalNaShadow · ChalNaMotion
├─ Components/  ChalNaButton · ChalNaBottomBar · ChalNaCanvas · ChalNaCard · ChalNaListRow(+Divider)
│               ChalNaNavBar · ChalNaNavAction · ChalNaTag · MediaThumb · ChalNaTextField
│               ChalNaTextArea · ChalNaSlider · ChalNaEmptyState · ChalNaNotice
│               ChalNaProgressBar · ChalNaToast · ChalNaBlockingOverlay  (17개)
├─ Modifiers/   View+ChalNaScreen · +ChalNaScrollHairline · +ChalNaSwipeBack
│               +ChalNaHitTarget · +ScrollProgress
├─ Icons/       ChalNaIcon (SF Symbols 24종 — 구 Lucide 커스텀 패스는 Task 5 에서 제거)
└─ Showcase/    DesignSystemShowcaseView
```

### Colors — `ChalNaColor` (다크 전용 시맨틱 토큰, `Modules/DesignSystem/Sources/Tokens/ChalNaColor.swift`)
| API | 값 | 용도 |
|---|---|---|
| `.bg` | `#0B0A10` | 화면 배경 (무채색이 아니라 옅은 인디고 캐스트) |
| `.surface` | `#16151D` | 카드 · 리스트 행 |
| `.surfaceRaised` | `#201F29` | 바텀시트 · 플로팅 툴바 |
| `.canvas` | `Color.black` | 영상 · 크롭 캔버스 (출력과 동일한 진짜 검정 — `bg` 와 밝기가 비슷해 '검은 섬'으로 뜨지 않음) |
| `.border` / `.borderStrong` | `#2C2A38` / `#3D3A4D` | 1px hairline / 입력 필드·강조 경계 |
| `.textPrimary` / `.textSecondary` | `#F5F4F7` / `#A3A0AE` | 본문(순백 아님 — 다크에서 순백은 헐레이션) / 보조 텍스트 |
| `.textTertiary` | `#6B6878` | **disabled 전용.** `bg` 대비 3.7:1 로 본문 기준(4.5:1) 미달 — 활성 텍스트에 쓰지 않는다 |
| `.accent` / `.accentFill` / `.accentPressed` | `#8B7BFF` / `#5B45E8` / `#A091FF` | 텍스트·아이콘·스트로크 액센트 / 면형 버튼 배경 / 눌림 톤 |
| `.onAccent` | `Color.white` | `accentFill` 위 라벨 |
| `.danger` / `.dangerPressed` | `#FF6B66` / `#FF8F8B` | 파괴적 액션·LIVE dot / 그 눌림 톤(없으면 파괴적 ghost 버튼이 눌리는 동안 보라로 바뀜) |
| `.success` | `#3DD9A0` | 성공 |
| `.brandDeep` | `#462DE2` | 앱 아이콘 색 그 자체. `bg` 대비 **2.4:1** — **인터랙션(버튼·텍스트)에 절대 쓰지 않는다.** Splash·브랜드 면 전용 |
| `.scrim` | `Color.black.opacity(0.6)` | 오버레이 |

- 대비 근거: `docs/superpowers/specs/2026-07-28-app-redesign-design.md` §4.1. 정확한 hex 는 위 표보다 `ChalNaColor.swift` 를 단일 출처로 본다.
- 대비 규칙은 프로즈로 끝나지 않는다 — `DesignSystemTests/ChalNaColorContrastTests` 가 강제한다. 값을 바꾸면 이 테스트가 잡는다.
- 과거의 `Purple/Blue/Gray` 수치 스케일과 `.cream/.ivory/.coral/.sage/.denim/.ink/.taupe`, `.Chip.*` 는 Task 26 에서 전부 삭제됐다 — 화면은 역할 이름(시맨틱 토큰)만 쓴다.

### Typography — `ChalNaTypography` (표준 iOS 텍스트 스타일 기반 역할 토큰)
- **6개 역할 토큰**이 표준 텍스트 스타일에 그대로 대응해서, 별도 스케일링 코드 없이 Dynamic Type 을 따른다: `.display`(28pt bold, `.title`) · `.title`(22pt semibold, `.title2`) · `.headline`(17pt semibold, `.headline`) · `.body`(16pt, `.callout`) · `.label`(13pt medium, `.footnote`) · `.caption`(12pt, `.caption`).
- `.mono(_:weight:)` — SF Mono. 타임코드·퍼센트 등 순수 숫자 전용. **한글에 쓰지 않는다**(한글 글리프가 없어 폴백되며 자간이 어긋남).
- `.keris(_:weight:)` — Splash 브랜드 라벨과 영상 오버레이 미리보기 전용. 합성 영상(`CATextLayer`)의 `UIFont` 측정값과 **픽셀 단위로 일치**해야 해서 여기만 Dynamic Type 없이 pt 를 직접 받는다 — 지울 대상이 아니라 존재 이유가 있는 토큰이다(아래 "비디오 합성 원칙" 참고).
- `Tracking`: `.title(-0.20)` · `.body(-0.30)`.
- **최소 12pt.** 8pt·11pt 는 금지(6개 역할 중 가장 작은 `.caption` 이 12pt).
- 과거의 12단계 `Size` 스케일(`tag(12)…displayL(32)`)과 legacy stub(`displayEN`/`serifFallback`/`hand`/`handFallback`)은 Task 26 에서 전부 삭제됐다.
- 앱 전역 Dynamic Type 상한은 `RootView` 의 `.dynamicTypeSize(...DynamicTypeSize.accessibility1)` — 단 **`.sheet`/`.fullScreenCover` 경계를 넘지 않는다.** 아래 "접근성" 참고.

### Radius — `ChalNaRadius`
`.xxs 2`(10×6pt 급 초소형 인디케이터 전용 — `.xs` 이상은 이 크기에서 캡슐이 되어버린다) · `.xs 6`(태그·작은 썸네일) · `.sm 10`(버튼·입력 필드) · `.md 14`(카드·프리뷰 캔버스) · `.lg 20`(바텀시트·플로팅 툴바) · `.pill 999`(칩·토글).
- 과거 4px 단위 스케일(`.film 4`·`.button 4`·`.card 8`·`.sheet 16`, `.card` 포함)은 Task 26 에서 삭제됐다.

### Motion — `ChalNaMotion`
`.fast`(easeOut 0.15s — 선택·눌림·표시/숨김 같은 상태 토글) · `.standard`(easeInOut 0.24s — 레이아웃 이동·페이드) · `.spring`(response 0.35 / damping 0.85 — 크롭 러버밴드 스냅백, 오버슛 없는 기존 검증값 유지).

### Shadow — `ChalNaShadow` + `View.chalNaShadow(_:)`
다크에서는 그림자가 거의 안 보여서 깊이는 `bg → surface → surfaceRaised` 3단 밝기 + 1px hairline 으로 표현하고, 그림자는 **`.floating` 하나만** 남았다(`Color.black.opacity(0.5)`, radius 24, y 8). 원래 플로팅 툴바(`EditToolbar`) 전용이었지만 지금은 `ChalNaToast`·`ChalNaBlockingOverlay` 도 같이 쓴다.

### Core Components
| 컴포넌트 | 사용 예 |
|---|---|
| 버튼 | `Button{}.buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true, destructive: false))` — variant `primary/secondary/ghost`, size `lg(52)/md(44)/sm(36)`, `destructive: Bool` 하나로 파괴적 색(danger)까지 컴포넌트가 결정. 축약 `.chalNaPrimary/.chalNaSecondary/.chalNaGhost` |
| 헤더 | `ChalNaNavBar(title: "설정", leading: .back { }, trailing: .text("저장") { }, showsDivider: true)` — 좌우 슬롯 **최소** 56pt. `ChalNaNavAction` 팩토리는 `.back/.close/.icon(_:accessibilityLabel:action:)/.text(_:action:)` 뿐이라 **글리프 크기(20pt)를 호출처가 못 바꾼다** |
| 캔버스 | `ChalNaCanvas(aspect: 9/16) { box in ... } overlay: { box in ... }` — Timeline 프리뷰·ClipAdjust·LabelEditor 가 공유하는 WYSIWYG aspect-fit 박스(기하 SSOT `ChalNaCanvasGeometry.fittedBox`). **내부에서 이미 fit 하므로 바깥에서 `.aspectRatio` 로 다시 감싸지 않는다**(무한 높이 컨테이너에서 오동작) |
| 카드 / 리스트 | `ChalNaCard(padding:showsBorder:) { ... }` · `ChalNaListRow.navigate/.toggle/.toggleVerbatim/.slider/.check(...)`(팩토리로만 생성, `private init`) + `ChalNaListDivider()` |
| 태그 / 썸네일 | `ChalNaTag("LIVE", variant: .live, icon: .film)`(구 `ChalNaChip` 대체) · `MediaThumb(state:size:aspect:) { ... }`(구 `ClipThumbCard`/`LiveBadge` 대체, 6개 상태) |
| 상태 표시 | `ChalNaEmptyState(icon:title:message:actionTitle:action:)` · `ChalNaNotice(icon:title:message:)` · `ChalNaProgressBar(progress:tint:height:)` · `view.chalNaToast(message:onDismiss:)`(모디파이어, 내부 `ChalNaToast` 는 직접 안 씀) · `ChalNaBlockingOverlay(...)` — 뒤 세 개는 `ChalNaShadow.floating` 을 공유 |
| 입력 | `ChalNaTextField(...)` · `ChalNaTextArea(placeholder:minHeight:text:)` · `ChalNaSlider(...)` |
| 하단바 / 화면 | `ChalNaBottomBar { ... }`(`safeAreaInset(edge: .bottom)` 에 넣어 쓴다) · `someView.chalNaScreen()`(배경 `ChalNaColor.bg` 풀블리드) · `.chalNaScrollHairline(progress:)`(구 `chalNaHeaderBar`·`+ChalNaTopBar` 대체 — 헤더 hairline 만 남고 배경 페이드는 제거됨) |
| 아이콘 | `ChalNaIcon(.play, size: 20, weight: .semibold)` — 24종, 내부 구현이 **SF Symbols 로 통일**(Task 5, 구 Lucide 커스텀 패스 제거). `@ScaledMetric(relativeTo: .body)` 로 `size` 를 스케일해서 옆 텍스트·Dynamic Type 을 그대로 따라간다 |

**Task 26 에서 삭제된 컴포넌트/토큰**(문서·코드 어디서도 새로 참조하지 않는다): `ChalNaChip` · `ClipThumbCard`/`ClipThumbState` · `ChalNaNavigationBar` · `ChalNaHeaderActionButtonStyle` · `View+ChalNaTopBar`. `ChalNaBottomSheet` 는 그보다 앞선 Task 12 에서 이미 삭제됐다.

### 금지 사항 — `scripts/design-lint.sh` 가 5개 규칙으로 정적 검사한다
- `Color(hex:)`/`Color(red:green:blue:)` **직접 호출 금지** — `ChalNaColor.*` 사용 (hex 이니셜라이저는 토큰 정의 내부 전용).
- `.font(.system(...))` 직접 호출 금지 — `ChalNaTypography.*` 경유. (`ChalNaIcon.swift` 만 예외 — 글리프 크기 지정 때문.)
- `.cornerRadius(15)` 같은 리터럴 금지(콜론형·UIKit 대입형·베어 모디파이어 전부 포함) — `ChalNaRadius.*`.
- `Color.white`/`.white` 하드코딩 금지 — `ChalNaColor.textPrimary` 또는 `.onAccent` 사용.
- `UIColor(named:)` 금지 — 번들 조회가 조용히 실패한다(과거에 검은 띠 버그를 만들었다). UIKit 에서 색이 필요하면 `UIColor(ChalNaColor.bg)` 처럼 SwiftUI `Color` 를 감싼다.
- `UIFont` 직접 참조 금지 — `ChalNaTypography.kerisUIFont` 경유(CompositionService 의 비디오 텍스트 오버레이는 불가피한 예외).
- **`scripts/design-lint.sh` 가 위 5종을 정적 검사한다. 커밋 전에 실행한다.**

**5개 규칙 전부 현재 0건**이지만 전부가 순수 코드 정리의 결과는 아니다 — 규칙 1(`.font(.system(`)의 0 은 코드 정리 + 아래 "다크 토큰 적용 예외"의 **정당한 파일 예외 2건**(`ClipLabelText.swift`·`LabelEditorView.swift`) 덕분이고, 나머지 4개 규칙의 0 은 코드 정리만의 결과다. 스크립트는 주석 인식(comment-aware)이라 주석 전용 줄은 제외하지만 코드 뒤 trailing 주석은 계속 검사한다 — 반대로 위반 줄 전체를 주석으로 감싸면(그 시점엔 죽은 코드) 스킵되는 건 알려진 한계다. 예외 목록의 근거는 문서가 아니라 스크립트 자체(`scripts/design-lint.sh:40-85`)를 단일 출처로 본다.

### 다크 토큰 적용 예외 (근거 있는 리터럴)
`design-lint.sh` 의 하드코딩 관련 규칙들(`Color(hex:)`·흰색 하드코딩, 라벨 박스 파일 2건은 `.font(.system(` 도)이 파일 단위로 예외 처리하는 대상이다. 셋 다 "토큰 규율 위반"이 아니라 "토큰으로 표현할 수 없는 것"이라 예외다:
- **라벨 박스 픽셀 일치** — `ClipLabel.swift`(Models) · `ClipLabelText.swift`·`LabelEditorView.swift`(TimelineFeature). 화면 라벨이 합성(`CATextLayer`)의 `UIFont` 측정값과 픽셀 단위로 일치해야 해서, Dynamic Type 에 따라 스케일되는 역할 토큰을 쓸 수 없다(위 "비디오 합성 원칙" 참고).
- **다크 위 반투명 오버레이** — `ChalNaTag.swift`(필 배경 `Color.white.opacity(0.08~0.10)`) · `MediaThumb.swift`(고스트 슬롯 그라디언트). 토큰으로 표현할 수 없는 합성 연산이다.
- **콘텐츠 그라디언트** — `ThumbnailPreset.swift`(12종 여행 톤 그라디언트) · `ColorHex.swift`(그 hex 헬퍼). 둘 다 Models. UI 크롬이 아니라 콘텐츠이므로 다크 팔레트 규율 밖이다.

### 접근성 — Dynamic Type 상한
`RootView` 의 전역 상한(`.dynamicTypeSize(...DynamicTypeSize.accessibility1)`)은 **`.sheet`/`.fullScreenCover` 경계를 넘어 전달되지 않는다** — SwiftUI 환경값이 프레젠테이션 경계에서 다시 시작되기 때문이다(Task 25 실측: 기본 16.0pt에서 상한 미적용 시 AX1 27.5pt를 지나 AX5 53.0pt까지 커짐, 상한 적용 후 34pt 미만). 개발 언어·기본 텍스트 크기로 테스트하면 이 누락은 전혀 보이지 않는다.

**그래서 `.sheet`/`.fullScreenCover` 로 뜨는 화면마다 그 안에서 상한을 다시 걸어야 한다.** 현재 7곳 전부 걸려 있다: `MediaPickerView`(포토 피커 시트·프리뷰 시트, 2곳) · `ExportView` · `TimelineView`(LabelEditor fullScreenCover) · `FilmDetailView`(재생 fullScreenCover·공유 시트, 2곳) · `SupportView`. **새 `.sheet`/`.fullScreenCover` 를 추가할 때마다 반드시 같은 상한을 붙인다** — 잊으면 조용히 새는 버그가 된다.

## 테스트
- 서비스/모델은 **Swift Testing**(`@Test`/`#expect`)으로 작성, `SampleData` 활용. actor/Client 는 프로토콜 + `testValue` 로 격리.
- 모델·서비스를 직접(예: `TimelineModel`, `AVFoundationCompositionService().export(...)`) 테스트하거나, 필요 시 TCA `TestStore` 사용 가능.
- UI 는 스냅샷 대신 `#Preview` 적극 활용 (각 뷰 상태별).
- 2026-07-30 기준 8개 유닛 스위트 전부 그린(SE·17 Pro 양쪽 확인): `DesignSystem` 22 · `TimelineFeature` 18 · `SettingsFeature` 28 · `MediaPickerFeature` 2 · `ExportFeature` 2 · `CompositionService` 51 · `AppCore` 24 · `PhotosService` 4. 이후 태스크가 이 수치를 크게 벗어나면 회귀를 의심한다.

## 검증 방법 (시뮬레이터 / UI 테스트 노하우)
다크 리디자인 사이클에서 실제로 시간을 잡아먹은 함정들이다. 다음 사람이 또 반복하지 않도록 적어둔다.

- **`simctl` 은 탭·타이핑을 못 한다.** 화면 조작이 필요한 검증은 XCUITest 로만 가능하다(합성 터치·키보드 둘 다 있음). 버튼 없이 특정 화면을 스크린샷하려면 `ContentView` 의 `AppMode.isShowcase` 분기를 그 화면에 맞춰 임시로 바꾸고 `SIMCTL_CHILD_CHALNA_APP_MODE=showcase xcrun simctl launch <device> ios.inho.ChalNa` 로 실행한 뒤 되돌린다.
- **`simctl launch` 에 환경변수를 넘길 땐 `SIMCTL_CHILD_` 접두사가 필요하다.** `--CHALNA_APP_MODE devMock` 같은 인자는 조용히 무시된다(`AppMode` 가 `ProcessInfo.processInfo.environment` 를 읽으므로). XCUITest 에선 `app.launchEnvironment["CHALNA_APP_MODE"] = "devMock"` 을 쓴다.
- **`xcrun simctl ui <device> content-size` 는 이 앱엔 적용되지 않는다** — 강제한 xxxLarge 스크린샷이 기본값과 바이트 단위로 동일하게 나온 적이 있다(재부팅 후에도). 코드에서 `.environment(\.dynamicTypeSize, ...)` 로 강제해야 한다.
- **`print()` 는 UI 테스트 중 `xcodebuild` stdout 도 unified log 도 타지 않는다** — 매 렌더링마다 찍는 무조건 print 로 확인해도 매치 0건이었다. 대신 앱 컨테이너에 파일로 쓰고 호스트에서 `xcrun simctl get_app_container <device> ios.inho.ChalNa data` 로 읽는다. (Task 25 는 이 채널의 침묵을 "증거 없음"으로 잘못 해석해 결론을 철회한 적이 있다 — 침묵을 증거로 쓰지 않는다.)
- **`LocalizedStringKey` 에 카탈로그 항목이 없으면 한국어 키를 그대로 렌더링한다** — 개발 언어(한국어)로 테스트하면 안 보인다. `-AppleLanguages "(en)"` 로 한 번은 꼭 실행한다.
- **`RenderPreview` 캔버스에서 점(pt) 측정을 하지 않는다**(~0.583 pt/px 스케일 차이 관측) — 시뮬레이터에 설치 후 스크린샷하고, 표시 좌표 → 원본 좌표 환산을 거쳐서 계산한다.
- **`.aspectRatio(.fit)` 는 높이 제안이 무한(예: `ScrollView` 내부)이면 무한 높이로부터 너비를 유도해 오동작한다** — 높이가 유한한 컨테이너에선 상한으로만 작동해 무해하다. `ChalNaCanvas` 는 내부에서 이미 fit 하므로 절대 바깥에서 다시 `aspectRatio` 로 감싸지 않는다.

## 커밋 / PR
- 단계가 끝나면 커밋, 메시지 한국어 OK. Claude 가 커밋할 땐 변경 파일 요약을 한국어로.

> **참고**: 루트의 `AGENTS.md` 는 커밋 `062e8bb`(dark-redesign 사이클 시작 전, 2026-07-09)에서 "agent skill·임시 문서 등 불필요 파일 제거"의 일부로 **삭제됐다** — 이 브랜치에는 존재하지 않는다. 과거엔 이 문서의 미러본(앞부분 Codex workflow 노트만 추가)이었다. `main` 브랜치는 그 삭제 커밋을 포함하지 않는 별도 이력이라 아직 파일이 남아 있다.
