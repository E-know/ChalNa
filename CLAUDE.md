# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# ChalNa — iOS 앱

Live Photo와 동영상을 촬영일 순서로 이어붙여 Vlog를 만드는 iOS 앱.

> **네이밍**: Tuist 타겟·Xcode 프로젝트·번들 ID·디자인 시스템 brand prefix 모두 `ChalNa`(`ios.inho.ChalNa`, `ChalNaColor`, `ChalNaTypography`, `ChalNaButton` 등)로 통일. **디자인 토큰 값은 2026-07-28 다크 리디자인으로 전면 교체됐다** — 과거엔 식별자만 ChalNa, 값은 라이트 톤의 "Danawa DDS Mobile v2.0"였으나 지금은 값도 자체 다크 시맨틱 팔레트다. 디자인은 **다크 시네마틱**이며, 액센트(`.accent`)는 새로 발명한 색이 아니라 **앱 아이콘의 인디고(`brandDeep` `#462DE2`)에서 밝기를 올려 역산**한 것이다(아이콘 원색은 `bg` 대비 2.6:1 라 인터랙션에 못 쓴다 — 아래 Colors 참고). 앱은 **다크 전용**이며 `Project.swift` 의 `infoPlist` 에 박아넣은 `UIUserInterfaceStyle: "Dark"` 가 라이트 모드 전환을 막는다 — 아래 디자인 시스템 참고.

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

# 전체 테스트 — 반드시 ChalNa-Workspace 스킴이어야 한다.
# `-scheme ChalNa` 의 test 액션은 앱 타겟에 의존하는 ChalNaUITests 만 포함하고
# 8개 유닛 스위트는 들어있지 않다 — 그걸로 돌리면 유닛 테스트가 조용히 빠진다.
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa-Workspace \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# UI 테스트만
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
           -only-testing:ChalNaUITests test

# 단일 테스트 (Swift Testing 파일/케이스 단위). 테스트 타겟명은 `<모듈>Tests`.
xcodebuild ... test \
  -only-testing:TimelineFeatureTests/TimelinePlaybackTests/testCurrentClipEnded_AdvancesCurrentIndex
```

- **스킴이 두 개다**:
  - `ChalNa` — 실제 사진 라이브러리 사용(`AppMode.real`).
  - `ChalNa Dev` — `CHALNA_APP_MODE=devMock` 환경변수를 주입해 **번들 고정 fixture 미디어**(`BundledDevMediaSource`)로 동작. 사진 권한 없이 전체 플로우를 돌릴 때 사용 (DEBUG 빌드 한정).
- 단일 모듈만 빌드/포커스: `tuist generate <Module>` (예: `tuist generate DesignSystem`) — 나머지 타겟은 가능하면 바이너리로 링크된다. Tuist 4(현재 환경 4.195.12)에 `tuist focus` 서브커맨드는 없다.
- 의존성 그래프: `tuist graph`. 그래프 출력물·설계 문서를 두는 `docs/` 는 `.gitignore` 대상인 임시 디렉터리라 저장소에 없다 — 그래서 이 문서는 설계 문서 링크 대신 **코드를 근거로 인용한다**.
- iOS 빌드/시뮬레이터 실행은 위 `xcodebuild` 명령으로 직접 한다 (매번 fresh build → 설치/실행으로 시각 검증). 전용 `ios-build-run` 서브에이전트는 이 저장소에도 사용자 전역 설정에도 없다.
- **유닛 테스트 타겟은 8개** (`Project.swift`의 `Module.unitTests(for:)` 8회 호출): `AppCoreTests` · `ExportFeatureTests` · `CompositionServiceTests` · `PhotosServiceTests` · `TimelineFeatureTests` · `MediaPickerFeatureTests` · `SettingsFeatureTests` · `DesignSystemTests`. Preview 보조용 고정 데이터 `SampleData` 는 현재 TimelineFeature 테스트 2곳(`TimelinePlaybackTests`·`TimelineReorderTests`)만 쓴다 — 재사용할 수 있으면 쓰고, 나머지 타겟은 자체 픽스처를 만든다.
- **Tuist 는 테스트 타겟을 위한 별도 스킴을 만들지 않는다.** `<Module>Tests` 타겟은 베이스 모듈(`<Module>`) 이 자동 생성하는 스킴에 Test 액션으로 붙는다. 즉 `-scheme DesignSystemTests` 는 존재하지 않고, `-scheme DesignSystem` · `-scheme SettingsFeature` · `-scheme TimelineFeature` 처럼 **베이스 모듈명**으로 실행해야 한다 (`-only-testing:` 의 대상은 타겟명 `<모듈>Tests` 그대로 맞다).
- **UI 테스트**는 별도로 `ChalNaUITests` 타겟(`ChalNa` 앱 타겟에 의존, `-scheme ChalNa`로 실행)에 네 파일이 있다 — `CropAdjustUITests` · `HomeLibraryCoverUITests`(export → 라이브러리 저장 → 홈 노출의 유일한 엔드투엔드 검증이자 표지 스크린샷 소스) · `LabelEditorUITests`(4케이스 — 2스텝 플로우 컨트롤·키보드 도달성 1 · `testLabelEditor_DynamicTypeAccessibility5_CapsAtAccessibility1`("크기" 캡션 렌더 높이를 실측하는 Dynamic Type 상한 가드) 1 · 키보드 하강만으로 스타일 스텝에 도달하는지 1 · 두 손가락 핀치/회전 무크래시 스모크 1) · `TimelineLayoutUITests`. 여기가 **XCTest 의 유일한 예외 대상**이다(아래 "기술 스택" 참고) — 다만 devMock 픽스처를 쓰는 이유는 사진 권한 없이 화면에 도달하기 위해서일 뿐이고, **시각 검증 채널이 아니다**. `CropAdjustUITests`는 도달성·무크래시 스모크 테스트로만 취급하지만, `HomeLibraryCoverUITests`의 엔드투엔드 단언·`LabelEditorUITests`의 Dynamic Type 케이스·`TimelineLayoutUITests`의 오프스크린 기하 가드(하단 툴바 4개·재생 버튼에 `screen.contains(button.frame)`)는 실제로 값을 재는 가드다 — 근거와 실제 기하·라벨 가드의 위치는 아래 "검증 방법" 절 참고.

## 기술 스택 (엄수)
- **Swift 6.0+, iOS 18+** (`AVAssetExportSession` async API 등으로 deployment 18 고정).
- **SwiftUI 전용** (UIKit 은 불가피한 경우에만 `UIViewControllerRepresentable`/`UIViewRepresentable` 로 래핑 — `PHPickerViewController`, `AVPlayerViewController`, `UIActivityViewController`(공유), `UICollectionView` 기반 FilmStrip(`FilmStripCollectionView`), `AVPlayerLayer` 호스트(`PlayerLayerView`·`PreviewPlayerLayerView`), 핀치/팬 제스처(`PinchPanGesture`), edge swipe-back).
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
- ViewModel 류 단일 화면 상태는 TCA State 로 두되, 재생 컨트롤러처럼 명령형 상태는 `@Observable` 모델(예: `ClipPlaybackController`, `PreviewPlaybackController`, `KeyboardObserver`)을 따로 둘 수 있다. 구 `TimelineModel` 은 필드·메서드가 전부 `TimelineFeature` 리듀서로 옮겨져 삭제됐다.

### 모듈 그래프 (Tuist 멀티 타겟, 의존 방향 위 → 아래)
앱은 얇은 셸이고 레이어/피처는 모듈로 쪼개져 있다. **`Modules/<Name>/Sources/`** 가 표준 위치, 리소스는 `Modules/<Name>/Resources/`, 테스트는 `Modules/<Name>/Tests/`.

```
앱 셸     ChalNa  ── @main ChalNaApp · ContentView · App/{AppFeature(TCA root)·RootView·AppMode}
            │
Feature   HomeFeature · MediaPickerFeature · TimelineFeature · ExportFeature · FilmDetailFeature · SettingsFeature
(모두 @Reducer)   │  (Feature끼리 직접 import 금지)
            │
서비스/코어  AppCore(EditSession · AppLanguageStore · ExportQuota) · PhotosService · CompositionService · AnalyticsService
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
- **Feature → (필요하면) AppCore + 필요한 서비스 + Models + DesignSystem + TCA**. 6개 Feature 에 항상 붙는 엣지는 DesignSystem·TCA 뿐이고 나머지는 전부 "필요한" 쪽이다 — 예를 들어 **`SettingsFeature` 는 Models 에 의존하지 않고**(유일 소비자였던 `LabelSettings`/`LabelPosition`/`LabelKind` 가 라벨 설정 화면과 함께 삭제됐다), **`MediaPickerFeature`·`FilmDetailFeature` 는 AppCore 에 의존하지 않는다**(편집 세션을 만지지 않으므로). 안 쓰는 엣지를 `Project.swift` 에 남기면 `tuist graph` 가 계속 그리고, 그 모듈이 다시 새어 들어와도 아무도 모른다. Feature 끼리는 절대 직접 import 안 한다 — 화면 전환은 자기 모듈의 `delegate` 액션으로 선언만 하고, 해석(매핑)은 앱 셸의 `AppFeature`가 한다.
- 앱 타겟은 `OTHER_LDFLAGS = -ObjC` 를 강제한다 (Firebase ObjC 카테고리가 dead-code-strip 되어 `unrecognized selector` 나는 것 방지).
- 새 모듈: `Tuist/ProjectDescriptionHelpers/Module.swift`의 `Module.framework(name:hasResources:isDynamic:dependencies:)` / `Module.unitTests(for:)` 헬퍼 사용 → `Project.swift`에 추가 → `tuist generate`.

### 런타임 흐름 (반드시 숙지)
1. `ChalNaApp`(`@main`) `init` 에서 **Firebase 설정 + TCA dependency override + 저장 언어 적용(`AppLanguageStore.applyStoredLanguageAtLaunch()`, 첫 페인트 전) + 구 설정 키 정리(`RemovedSettingsCleanup.run()`)**:
   - `GoogleService-Info.plist`(번들: `ChalNa/Resources/`)가 있으면 `FirebaseApp.configure()` 후 `FirebaseAnalyticsTracker`, 없으면 `NoopAnalyticsTracker` 로 `prepareDependencies { $0.analyticsTracker = ... }`.
   - `WindowGroup { ContentView() }.modelContainer(for: Film.self)`. 새 `@Model` 추가 시 이 시그니처 갱신.
2. `ContentView` → `RootView`. `RootView`는 TCA `Store`(AppFeature)를 `@State`로 만들고, `EditSession` 은 `@Dependency(\.editSession)`(liveValue 싱글턴)에서 얻어 environment 로도 주입한다 — **Reducer 와 View 가 같은 인스턴스를 공유**.
3. **네비게이션**: `NavigationStack(path: $store.scope(state: \.path, action: \.path))`. `AppFeature`의 `Path` enum(`mediaPicker`/`timeline`/`export`/`filmDetail`/`settings`/...)이 스택 케이스. 루트는 `home`(Scope).
4. **전환 트리거(delegate 패턴)**: 자식 Feature 는 `Action.Delegate` enum 으로 네비게이션 인텐트를 선언하고(예: MediaPicker 의 `.selectionConfirmed(clips:title:)`), 리듀서가 비즈니스 로직 결과로 `.send(.delegate(...))` 를 방출 → `AppFeature`가 `case .path(.element(id:action:.mediaPicker(.delegate(...))))` 매칭으로 `state.path.append/removeAll` 수행. **pop 은 자식 리듀서가 `@Dependency(\.dismiss)` 로 직접** (`.run { _ in await dismiss() }`). View 는 `store.send(...)`만 하고 화면 전환을 모른다.
5. **편집 상태 전달**: 선택한 `[Clip]`·제목·회전(`rotations`)·박스 자막(`labels`)·크롭 변환(`transforms`)은 Route payload 나 TCA State 가 아니라 **`EditSession`에 실어** MediaPicker → Timeline → Export 로 흘려보낸다. View 는 `@Environment(EditSession.self)`, Reducer 는 `@Dependency(\.editSession)` 로 접근 (예: AppFeature 가 `selectionConfirmed` delegate 를 받으면 `editSession.replace(clips:title:)` 후 Timeline push).
6. **AppMode / devMock**: `App/AppMode.swift`의 `AppMode.current` 가 DEBUG + `CHALNA_APP_MODE=devMock` 일 때 `.devMock`. `AppFeature`가 MediaPicker push 시 소스를 `.photoLibrary` ↔ `.devFixtures(BundledDevMediaSource())`로 분기.
7. 모든 push 화면은 `.toolbar(.hidden, for: .navigationBar)` + `.navigationBarBackButtonHidden(true)` + 커스텀 `.chalNaSwipeBack()`(좌측 엣지 스와이프) 패턴을 적용한다.

### 모델 / 영속화 경계
- **`Clip`** (`Models/Clip.swift`) — 편집 세션의 in-memory **value type(struct)**, SwiftData 아님. 필드: `id·kind·capturedAt·duration·preset·thumbnailData·videoURL·locationNote·displaySize`. `videoURL == nil` 이면 합성에서 스킵. `displaySize`는 `preferredTransform` 적용 후 표시 사이즈(출력 캔버스/정렬용).
- **`Film`** (`Models/Film.swift`) — `@Model`(SwiftData) 라이브러리 단위. mp4 는 `Documents/films/<id>.mp4` 로 복사하고 모델엔 **상대 경로(`movieFilename`)**만 둔다(앱 재설치 시 절대 경로가 바뀌므로 — `movieURL` computed 로 복원). 표지 썸네일은 `@Attribute(.externalStorage)` 이고, 내용은 첫 클립 원본이 아니라 **합성 결과 mp4 의 첫 프레임**이다 — 생성·검증 SSOT 가 `FilmCover`(Models): export 저장 시 `ExportView` 가 `firstFrameJPEG(fromMovieAt:)`(상한 720×1280 JPEG)를 부르고, 9:16 을 벗어난 구 표지는 `needsRegeneration(thumbnailData:)`(tolerance 0.05)로 판별해 `HomeView` 가 지연 재생성한다.
- **`FileStorage` 모듈의 `FilmStorage`** 가 파일 IO 담당: `importMovie(from:filmID:)`(temp → `films/<uuid>.mp4`, 상대경로 반환), `deleteMovie(filename:)`, `moviesDirectoryURL`.
- **`ThumbnailPreset`** — 12종 여행 톤 그라디언트 enum(`view()`로 SwiftUI 뷰). `Clip.thumbnailView()`(`Clip+Thumbnail.swift`)는 실사 썸네일이 있으면 그걸, 없으면 preset 그라디언트를 fallback 으로 그린다.
- **`SampleData`** — Preview/Test 용. `jejuTimeline`(8개 Clip), `groupedByDay()` 헬퍼 등.

## 서비스 레이어 & 의존성 주입
- **TCA `@Dependency` + `@DependencyClient` 패턴**. 각 서비스는 *클로저 묶음 struct*(Client)로 노출하고 `DependencyKey`의 `liveValue`/`testValue`(필요시 `previewValue`) 제공. **생성자 주입/서드파티 DI 프레임워크 사용 안 함**.
  - `CompositionClient` (`compositionClient`) — liveValue 가 `AVFoundationCompositionService` actor 를 래핑.
  - `PhotoLibraryClient` (`photoLibraryClient`) — 권한/PHAsset 조회/Live Photo 추출/저장 등 클로저 묶음. live 헬퍼 함수들이 구현.
  - `AnalyticsTrackerKey` (`analyticsTracker`) — 기본 live/test/preview 모두 `NoopAnalyticsTracker`, 실제 Firebase 주입은 `ChalNaApp.init`의 `prepareDependencies`에서.
  - `ExportQuotaClient` (`exportQuotaClient`, AppCore) — `reserveExport`/`redeem`. liveValue 가 UserDefaults 기반 `ExportQuotaUserDefaults` 를 래핑. `ExportFeature` 가 소비.
  - `FeedbackClient` (`feedbackClient`, SettingsFeature) — `send(FeedbackReport)`. liveValue 가 텔레그램 봇 `sendMessage` POST. 실패는 `FeedbackError`(LocalizedError). **봇 토큰이 소스에 하드코딩돼 있다**(백엔드가 없어 수용한 트레이드오프) — 새 비밀값을 같은 방식으로 늘리지 않는다.
- 무거운 구현은 **`actor`** (`AVFoundationCompositionService: CompositionServicing`, `BundledDevMediaSource: DevMediaSourcing`). 프로토콜로 추상화한다. `MockPhotoLibraryService`(+`PhotoLibraryServicing`)는 PhotoKit 통합 전 스텁으로 현재 참조가 0건인 죽은 코드다 — 새 코드가 여기 기대지 않게 한다.
- 진행률/스트리밍은 **`AsyncStream`** 으로 래핑 (예: `CompositionService`의 `export()`가 `AsyncStream<ExportEvent>` 반환 — `.progress/.completed/.failed`).
- Feature 에선 `@Dependency(\.compositionClient) var compositionClient` 처럼 주입받아 `.run { send in ... }` effect 안에서 호출.

### Analytics
- `AnalyticsTracker` 프로토콜: `log(_:)`, `setUserProperty(_:forName:)`. 구현은 `FirebaseAnalyticsTracker` / `NoopAnalyticsTracker`.
- 이벤트는 `AnalyticsEvent` enum 으로 타입 안전하게 정의 (`name`=Firebase snake_case, `parameters`=dict). 추가 이벤트는 여기 case 로.
- Feature 에서 `@Dependency(\.analyticsTracker)` 로 받아 `analytics.log(.exportStarted(clipCount:))` 형태로 호출.

## Photos 프레임워크 원칙
- `PHPickerViewController`로 선택 (권한 최소화). 라이브러리 조회·추출·저장 같은 PhotoKit 접근은 `PhotosService`(`PhotoLibraryClient`)를 통해서만 한다 — 예외는 `MediaPickerFeature` 가 State 기본값으로 직접 읽는 `PHPhotoLibrary.authorizationStatus(for: .readWrite)` 와 `PHAuthorizationStatus` 타입 노출 한 곳뿐이다.
- **`PickedMediaLoader`** — PHPicker 결과(`NSItemProvider`/`PHPickerResult`)에서 직접 추출: Live Photo 는 `PHLivePhoto` → paired video, 일반 비디오는 `loadFileRepresentation` → temp 복사. 썸네일·촬영일·길이·displaySize 메타도 로드.
- `PHAsset` 재조회가 필요하면 `PHAsset.fetchAssets(withLocalIdentifiers:)`. Live Photo 비디오는 `PHAssetResource`의 `.pairedVideo`/`.fullSizePairedVideo` 우선.
- **`DevMediaSourcing`** (`BundledDevMediaSource` actor, `PhotosService/Sources/DevMediaSource.swift`) — devMock 전용. 번들 `DevFixtures` mp4 4개를 고정 ID(`dev-jeju-sea` 등, 파일명이 곧 asset ID)로 제공. 실패는 `DevMediaError`(LocalizedError).

## 비디오 합성 원칙
- **출력은 1080×1920(9:16 세로) 고정.** 기본 프레이밍은 aspectFill 센터 크롭(`ClipTransform.fill`)이지만 **사용자 확대·축소·이동에 제약이 없다** — scale < 1 로 줄이거나 캔버스 밖으로 밀어낼 수 있고, 드러나는 여백은 **검정**이다(합성은 `ChalNaVideoCompositor` 의 불투명 검정 베이스, 프리뷰는 `ChalNaColor.canvas`). `ClipTransform.minScale`/`maxScale`(0.1 / 10)은 UX 한계가 아니라 **산술 안전 가드**이며 적용 지점은 `ClipTransform.sanitized` 하나다 — 프리뷰(`ClipFraming.resolvedRect`)와 export(`AVFoundationCompositionService.transform`)가 둘 다 이걸 경유한다(예전엔 export 만 clamp 하는 비대칭이 있었다). 과거의 `ClipFraming.clampedOffset`/`maxOffsetFraction` 은 삭제됐다 — identity 로 남기지 않은 이유는 아무것도 안 하는 clamp 가 호출부 독자에게 제약이 아직 있다고 잘못 알리기 때문이다. 배치 기하 SSOT 는 여전히 `ClipFraming`(Models)이고 프리뷰·조정 화면·export 가 공유한다(WYSIWYG). 사용자 크롭 조정은 `EditSession.transforms`.
- `AVMutableComposition` + `AVMutableVideoComposition`. 모든 트랙 조작은 **`CompositionService` actor 내부에서만**.
- 익스포트는 `AVAssetExportSession` + `AsyncStream<ExportEvent>`로 진행률 폴링/래핑.
- 출력 영상의 자동 시간/날짜 라벨은 `CATextLayer`로 합성하며 **시스템 기본 폰트 bold** 를 쓴다. 번들 커스텀 폰트는 없다(구 KERISKEDU 는 제거됨 — `UIAppFonts` 키 자체가 사라졌다).
- **자동 시각/날짜 라벨에는 사용자 설정이 없다.** 항상 표시되고, 위치·크기·불투명도 전부 `LabelLayout`(Models)이 갖는 고정값이다 — 합성과 프리뷰(`AutoLabelsOverlay`)가 이 하나를 공유해 WYSIWYG 를 맞춘다.
  - 위치: **우측 하단 고정**. 시각(`timeFontFraction 0.045`, 1080 기준 ≈49px)이 위, 날짜(`dateFontFraction 0.030`, ≈32px)가 아래로 쌓이고 둘 다 우측 정렬(`stackGapFraction 0.010`, 여백 `paddingFraction 0.04`).
  - 불투명도: `LabelLayout.opacity` = **0.75** 로 시각·날짜 공통.
  - 9구역 위치 체계(`LabelPosition`)·`LabelSettings`/`LabelKind` 모델·[설정 → 라벨] 화면 전체가 삭제됐다. 그래서 `CompositionServicing.export` 에는 `labelSettings` 파라미터가 없다 — 라벨을 끌 방법이 없으므로, 합성 픽셀 테스트는 샘플 지점이 라벨 박스를 피하는 것으로 격리한다. **그 회피는 주석의 손계산이 아니라 `LabelText.stampRect` 계산으로 검증한다**(`expectClearOfAutoLabelStamp`) — 예전엔 세 파일에 좌표를 손으로 적어둬서, 라벨 기하를 바꾸면 "컴포지터가 틀렸다"는 엉뚱한 메시지로 실패했다.
  - 설정 화면에 남은 항목은 **언어 · 문의·신고** 2개다.
- **사용자 박스 자막(`ClipLabel`)의 스타일은 `hasBackground` 로 갈린다** — `true`(기본) = 흰 배경 + 검정 글씨 + 검정 테두리, `false` = 배경·테두리 없는 흰 글씨(장식 없음). **패딩은 ON/OFF 항상 동일하게 유지한다.** 근거는 두 개다. ① **합성**(`customLabelOrigin`)은 `textSize`(패딩 제외)만으로 중심을 정하고 `makeCustomLabelLayers` 가 패딩을 대칭으로 더하므로, 패딩과 무관하게 박스 중심 = 텍스트 중심이 항상 성립한다(`CustomLabelLayoutTests.customLabelLayers_ToggleKeepsTextFrame` 이 `textLayer.frame` 동일성으로 잠근다). ② **자동 축소의 판정 대상이 패딩 포함 박스 폭**이라, 패딩이 갈리면 ON/OFF 에서 축소 결과 폰트가 갈린다. **에디터 쪽 근거는 사라졌다** — 예전엔 좌상단 `anchorCorner` 가 `@State` 단일 출처여서 "코너가 고정된 채 패딩이 달라지면 중심이 옮겨간다"가 실제 위험이었지만, 지금 `LabelEditorView` 는 **정규화 중심 `anchorCenter`** 를 배치 단일 출처로 쓰므로 패딩이 달라져도 라벨이 움직이지 않는다(저장 좌표계와 같아 커밋 역산도 없다).
  - **문구가 길면 폰트가 자동 축소된다.** 라벨 박스(패딩 포함)의 좌우가 캔버스 폭의 **92%**(양쪽 각각 4%, `LabelLayout.paddingFraction` 재사용) 안에 머물도록 줄인다. 하한은 **8px**이고, 거기서도 넘치면 넘침을 허용한다(초장문 방어). **`ClipLabel.sizeFraction` 은 사용자 의도로 그대로 저장하고 덮어쓰지 않는다** — 실제 렌더 폰트는 `renderedSizeFraction`/`fontPx(canvasHeight:)` 로 파생되므로, 문구를 짧게 고치면 원래 크기로 복귀한다. 세로 맞춤은 없다(자막은 1줄).
  - **폰트·실측·축소 SSOT 는 `Models.ClipLabelMetrics` 하나다.** 판정은 출력과 같은 기준 캔버스(1080×1920)에서 하고 **비율**을 돌려주므로 프리뷰(작은 박스)와 합성이 근사치가 아니라 **정확히 같은 비율**을 쓴다. 예전엔 같은 실측 코드가 `LabelAnchorMath.textSize`·`ClipLabelText.measuredSize`·`CompositionService.measureCustomText` **3곳에 복제**돼 있어 한쪽만 고쳐도 컴파일·테스트가 조용히 통과했다.
  - **기울기(`ClipLabel.rotationRadians`)는 출력 영상에 반영된다** — 시계방향 +, −180°…180° 자유 회전, 0° 스냅 ±3°(`rotationSnapRadians`). 부호 규약은 `previewRotation`(SwiftUI)·`layerRotationTransform`(CALayer) **두 파생값에만** 둔다: 오버레이 부모 레이어가 `isGeometryFlipped = true` 라 호출처마다 부호를 손으로 맞추면 두 경로가 조용히 어긋난다. 실측 결과 `CGAffineTransform(rotationAngle: +θ)` 가 시계방향으로 보여 SwiftUI 와 부호가 일치했다(반전 불필요) — 이 방향은 `ClipLabelRotationTests` 가 오버레이 비트맵 픽셀 **차분**으로 잠근다(절대 기울기를 재면 우측 하단 자동 라벨이 편향을 만든다). **자동 축소는 회전 전(unrotated) 박스 폭 기준**이고, `ClipLabelMetrics.fittedSizeFraction` 이 회전을 인자로 받지 않아 구조적으로 그렇다 — 회전된 바운딩이 캔버스를 넘는 것은 허용한다(회전할 때마다 폰트가 흔들리는 것이 더 나쁘다).
  - 합성에서 회전은 **컨테이너 레이어 없이** 배경·텍스트 두 레이어에 **같은 아핀**을 건다. `bgLayer` 중심 = `origin + textSize/2` = `textLayer` 중심 이 항등식으로 성립하고 CALayer 변환이 자기 `anchorPoint`(기본 중심) 기준이라 컨테이너와 결과가 같기 때문이다(`ClipLabelRotationTests.rotatedBackgroundAndTextShareCenter` 가 잠근다). **`frame` 을 모두 세팅한 뒤 마지막에** transform 을 건다 — 비항등 transform 이 걸린 레이어에 `frame` 을 대입하는 것은 동작이 정의되지 않는다.
  - 라벨 편집은 **`[문구 입력] → [위치·배경·크기]` 2스텝**이다(`LabelEditorView` 의 `Step.text`/`.style`) — 진입은 기존 라벨 재편집이어도 항상 문구 스텝부터이고, 문구를 비운 채 저장하는 것이 라벨을 지우는 유일한 경로다. 문구 스텝의 `[다음]` 은 상단바가 아니라 **키보드 바로 위**에 있고, `[다음]` 을 누르지 않고 **키보드를 내려도** 자동으로 스타일 스텝으로 넘어간다(트리거는 "키보드 높이가 0" 하나뿐 — 이중 발화·종료 중 전환·초기 프레임 세 가지를 가드한다). `ToolbarItemGroup(placement: .keyboard)` 는 이 화면(`NavigationStack` 없는 `fullScreenCover` 콘텐츠)에서 **아무것도 렌더하지 않는다**(커버 루트·포커스 TextField 양쪽에 붙여 실측: XCUITest 요소 덤프가 `toolbars=0`) — 그래서 `KeyboardObserver.height` 로 직접 올리는 SwiftUI 바를 쓴다. UIKit `inputAccessoryView` 로 내려가지 않은 덕에 바 스타일도 토큰으로 잡힌다.
  - 크기 조절(슬라이더·두 손가락 핀치)과 회전은 **라벨 중심을 고정**한다. 예전 명세는 "좌상단 코너 고정 · 우하 확장"이었는데, 핀치 도입과 함께 중심 고정으로 통일했다 — 배치 단일 출처가 정규화 중심이라 이 성질이 계산이 아니라 구조로 보장된다. 크기 슬라이더와 핀치는 같은 `sizeFraction` 을 공유해 서로 동기화된다.
- **라벨 오버레이 비트맵은 캔버스 전체가 아니라 라벨이 덮는 사각형만** 렌더한다(`stampBounds`). 1080×1920 RGBA 는 장당 ≈8MB 인데 `videoComposition.instructions` 가 클립별 오버레이를 **전부 선반영**해 export 내내 붙들고 있어서, 캔버스 전체로 만들면 30클립 vlog 가 ≈240MB 를 동시 유지한다. 코너 스탬프만 있으면 이 박스는 ≈200×121(≈97KB)다. 같은 "시각+날짜+자막" 조합은 `OverlayKey` 캐시로 그림 하나를 공유한다.
  - **서브렉트를 만들 땐 컨텍스트를 translate 하지 말 것.** `isGeometryFlipped` 의 뒤집기 기준이 그리기 컨텍스트를 따라가면서 결과가 완전히 빈 이미지가 된다(실측). 대신 레이어를 서브렉트 기준으로 평행이동한다 — **`frame` 대입이 아니라 `position` 이동**이다(회전이 걸린 레이어에 `frame` 대입은 동작이 정의되지 않는다. `position` 이동은 transform 과 무관하게 정의돼 있고 항등 변환에서는 `frame` 평행이동과 결과가 같다).
  - **크롭 박스는 `layer.frame` 을 읽지 않고 y-up 사각형 배열을 받는다**(`stampBounds(yUpRects:renderSize:)`). 박스 자막은 회전이 걸릴 수 있고, 비항등 transform 이 걸린 레이어의 `frame` 이 바운딩을 어떻게 반영하는지에 의존하면 **회전된 라벨 모서리가 잘린다** — 그래서 `customLabelStampRect` 가 회전 바운딩을 직접 계산한다. 잘림 없음은 `CompositorLabelTests.testCompositor_RotatedLabel_AreaPreserved_NotClipped` 가 실제 export 프레임의 흰 픽셀 **면적 보존**으로 확인한다(45° 회전은 축 정렬 영역을 벗어나므로 좁은 사각형으로 재면 잘림이 없어도 수가 줄어든다).
- 프리뷰와 합성이 **같은 폰트·같은 문자열**이어야 WYSIWYG 가 맞는다. 그래서 로케일 해석·시각/날짜 포매터·폰트·실측이 전부 **`LabelText`(Models)** 한 곳에 있고, 합성(`CompositionService`)과 프리뷰(`AutoLabelsOverlay`)가 같은 함수를 부른다. 예전엔 이 넷이 두 모듈에 바이트 단위로 복제돼 있었고 동기화 수단이 주석뿐이라, 한쪽만 고쳐도 컴파일·테스트가 조용히 통과했다. DesignSystem 은 최하단 모듈이라 CompositionService 가 볼 수 없으므로 **Models 가 유일하게 가능한 공유 지점**이다(`LabelLayout` 기하가 이미 거기 있는 것과 같은 이유).

## 에러 처리
- `throws` 사용, `Result` 타입은 지양(Swift 6).
- 도메인 에러는 **`LocalizedError` 채택 enum** (예: `ExportError`, `DevMediaError`). 사용자 표시 메시지는 `errorDescription`으로 분리.

## 코드 컨벤션
- 타입 추론이 명확하면 타입 생략, 공개 API 는 명시. `self.` 는 클로저/이니셜라이저 외 생략.
- **Spacing/padding 은 토큰 없이 리터럴 숫자**(`.padding(16)`, `HStack(spacing: 8)`). 색/타이포/라디우스/섀도우는 토큰 사용. 리듬은 `4/8/12/16/20/24`(padding 은 이 리듬이 우세 — 실측 20:34 · 12:20 · 16:14 · 24:12. 다만 컴포넌트 내부 `spacing:` 에는 6·10 도 흔하다 — 8:28 · 12:18 · 10:15 · 6:13), **화면 좌우 여백은 20 으로 통일**(코드베이스 전체에서 `.padding(.horizontal, 20)` 이 다른 값들을 압도적으로 앞선다).
- 한국어 주석 OK, 식별자는 영어. 한 파일 = 한 타입 (긴밀히 결합된 small helper 는 예외).

## 디자인 시스템 (ChalNa 식별자 / 다크 전용 시맨틱 값)

모든 UI 는 `Modules/DesignSystem/Sources/` 토큰·컴포넌트를 사용한다 (**spacing/padding 만 리터럴 숫자**). **리터럴 HEX·시스템 폰트 직접 호출 금지**. 새 컴포넌트 전에 기존 것 재사용. 앱은 다크 전용이다 — 라이트 모드 분기를 만들지 않는다. 이 절의 금지 사항은 프로즈로만 끝나지 않고 `scripts/design-lint.sh` 가 정적 검사로 강제한다 (아래 "금지 사항" 참고).

### 파일 레이아웃
```
DesignSystem/Sources/
├─ BundleAccessor.swift  (`Bundle.module` 접근자 — 디렉터리 없이 루트에 있고 소비자 0건)
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
| `.textTertiary` | `#6B6878` | **disabled 전용.** `bg` 대비 3.6:1 로 본문 기준(4.5:1) 미달 — 활성 텍스트에 쓰지 않는다 |
| `.accent` / `.accentFill` / `.accentPressed` | `#8B7BFF` / `#5B45E8` / `#A091FF` | 텍스트·아이콘·스트로크 액센트 / 면형 버튼 배경 / 눌림 톤 |
| `.onAccent` | `Color.white` | `accentFill` 위 라벨 |
| `.danger` / `.dangerPressed` | `#FF6B66` / `#FF8F8B` | 파괴적 액션·LIVE dot / 그 눌림 톤(없으면 파괴적 ghost 버튼이 눌리는 동안 보라로 바뀜) |
| `.brandDeep` | `#462DE2` | 앱 아이콘 색 그 자체. `bg` 대비 **2.6:1** — **인터랙션(버튼·텍스트)에 절대 쓰지 않는다.** Splash·브랜드 면 전용 |
| `.scrim` | `Color.black.opacity(0.6)` | 오버레이 |
| `.onMedia` / `.onMediaDark` | `Color.white` / `Color.black` | 사용자 미디어 위에 올라가는 마크(밝은 가이드선·라벨 / 어두운 외곽선). 아래 픽셀이 사진·영상이라 배경 밝기를 가정할 수 없어 고정이다 |

- 정확한 hex 는 위 표보다 `ChalNaColor.swift` 를 단일 출처로 본다.
- 대비 규칙은 프로즈로 끝나지 않는다 — `DesignSystemTests/ChalNaColorContrastTests` 가 강제한다. 값을 바꾸면 이 테스트가 잡는다.
- 과거의 `Purple/Blue/Gray` 수치 스케일과 `.cream/.ivory/.coral/.sage/.denim/.ink/.taupe`, `.Chip.*` 는 Task 26 에서 전부 삭제됐다 — 화면은 역할 이름(시맨틱 토큰)만 쓴다.

### Typography — `ChalNaTypography` (표준 iOS 텍스트 스타일 기반 역할 토큰)
- **6개 역할 토큰**이 표준 텍스트 스타일에 그대로 대응해서, 별도 스케일링 코드 없이 Dynamic Type 을 따른다: `.display`(28pt bold, `.title`) · `.title`(22pt semibold, `.title2`) · `.headline`(17pt semibold, `.headline`) · `.body`(16pt, `.callout`) · `.label`(13pt medium, `.footnote`) · `.caption`(12pt, `.caption`).
- **앱은 시스템 기본 폰트(SF Pro) 하나만 쓴다.** 번들 커스텀 폰트(구 `.keris` / KERISKEDU)도, 다른 `design`(구 `.mono` = SF Mono)도 없다. 숫자 폭이 흔들리면 안 되는 곳은 **폰트를 바꾸지 말고** 같은 폰트의 tabular figure(`Text.monospacedDigit()`)를 붙인다 — 실제로 값이 바뀌는 숫자 6곳(`ChalNaListRow` 슬라이더 %, `ChalNaBlockingOverlay` 진행률, `ExportView` 진행률 %, `ExportView` metaLine 의 `%02d:%02d`, `PreviewPanel` 타임코드 2개)에 붙어 있다.
- **역할 토큰은 굵기를 자체적으로 고정한다.** 구 `mono(_:weight:)` 처럼 굵기를 인자로 받던 토큰에서 역할 토큰으로 갈아탈 땐 `.fontWeight()` 로 굵기를 따로 복원해야 한다 — 안 하면 굵기가 조용히 바뀌고 유닛 테스트로는 안 잡힌다(실제로 PR #38 에서 4곳이 그렇게 얇아졌다).
- `.fixed(_:)` — 기본 폰트를 **pt 로 직접** 받는 유일한 토큰(Dynamic Type 비적용). 이제 **Splash 브랜드 라벨 전용**이다(+ Showcase 견본). 아이콘과 크기 비율이 고정이라 스케일되면 안 되기 때문. **굵기 인자를 받지 않는다** — 구 `fixed(_:weight:)`/`fixedUIFont(_:)` 짝은 UIKit 쪽만 `.bold` 하드코딩이라 비-bold 호출 시 bold 메트릭으로 잰 레이아웃에 다른 글리프를 그리는 어긋남이 조용히 생겼다. 영상 라벨 폰트는 `Models.LabelText` 로 옮겼고 `fixedUIFont` 는 삭제됐다.
- `Tracking`: `.title(-0.20)` 하나뿐이다(`ChalNaNavBar` 타이틀 · `ChalNaButton` 라벨이 쓴다). 구 `.body(-0.30)` 은 없다.
- **최소 12pt.** 8pt·11pt 는 금지(6개 역할 중 가장 작은 `.caption` 이 12pt).
- 과거의 12단계 `Size` 스케일(`tag(12)…displayL(32)`)과 legacy stub(`displayEN`/`serifFallback`/`hand`/`handFallback`)은 Task 26 에서 전부 삭제됐다.
- 앱 전역 Dynamic Type 상한은 `RootView` 의 `.dynamicTypeSize(...DynamicTypeSize.accessibility1)` — 단 **`.sheet`/`.fullScreenCover` 경계를 넘지 않는다.** 아래 "접근성" 참고.

### Radius — `ChalNaRadius`
`.xxs 2`(10×6pt 급 초소형 인디케이터용으로 정의돼 있지만 **현재 소비자 0건** — `.xs` 이상은 이 크기에서 캡슐이 되어버려서 남겨둔 토큰) · `.xs 6`(태그·작은 썸네일) · `.sm 10`(버튼·입력 필드) · `.md 14`(카드·프리뷰 캔버스) · `.lg 20`(바텀시트·플로팅 툴바). **`pill` 토큰은 없다** — 완전한 캡슐이 필요한 태그·토스트·진행률 바는 SwiftUI `Capsule()` 을 직접 쓴다.
- 과거 4px 단위 스케일(`.film 4`·`.button 4`·`.card 8`·`.sheet 16`, `.card` 포함)은 Task 26 에서 삭제됐다.

### Motion — `ChalNaMotion`
`.fast`(easeOut 0.15s — 선택·눌림·표시/숨김 같은 상태 토글) · `.standard`(easeInOut 0.24s — 레이아웃 이동·페이드) · `.spring`(response 0.35 / damping 0.85 — 크롭 리셋(`ClipAdjustView.resetToCenterCrop`)의 센터 크롭 스냅백, 오버슛 없는 기존 검증값 유지. 러버밴드는 이 브랜치에서 삭제됐고 현재 유일한 소비자다).

### Shadow — `ChalNaShadow` + `View.chalNaShadow(_:)`
다크에서는 그림자가 거의 안 보여서 깊이는 `bg → surface → surfaceRaised` 3단 밝기 + 1px hairline 으로 표현하고, 그림자는 **`.floating` 하나만** 남았다(`Color.black.opacity(0.5)`, radius 24, y 8). 원래 플로팅 툴바(`EditToolbar`) 전용이었지만 지금은 `ChalNaToast`·`ChalNaBlockingOverlay` 도 같이 쓴다.

### Core Components
| 컴포넌트 | 사용 예 |
|---|---|
| 버튼 | `Button{}.buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true, destructive: false))` — variant `primary/secondary/ghost`, size `lg(52)/md(44)/sm(36)`, `destructive: Bool` 하나로 파괴적 색(danger)까지 컴포넌트가 결정. 축약 `.chalNaPrimary/.chalNaSecondary/.chalNaGhost` |
| 헤더 | `ChalNaNavBar(title: "설정", leading: .back { }, trailing: .text("저장") { }, showsDivider: true)` — 좌우 슬롯 **최소** 56pt. `ChalNaNavAction` 팩토리는 `.back/.close/.icon(_:accessibilityLabel:action:)/.text(_:action:)` 와 빈 슬롯용 `.empty`(NavBar 좌우 기본값) 뿐이라 **글리프 크기(20pt)를 호출처가 못 바꾼다** |
| 캔버스 | `ChalNaCanvas(aspect: 9/16) { box in ... } overlay: { box in ... }` — Timeline 프리뷰(`PreviewPanel`)·ClipAdjust·LabelEditor·Export 커버(`ExportView`) 네 곳이 공유하는 WYSIWYG aspect-fit 박스(기하 SSOT `ChalNaCanvasGeometry.fittedBox`). **내부에서 이미 fit 하므로 바깥에서 `.aspectRatio` 로 다시 감싸지 않는다**(무한 높이 컨테이너에서 오동작) |
| 카드 / 리스트 | `ChalNaCard(padding:showsBorder:) { ... }` · `ChalNaListRow.navigate/.toggle/.slider/.check(...)`(팩토리로만 생성, `private init`) + `ChalNaListDivider()`. `.toggleVerbatim` 은 유일 소비자였던 라벨 설정 화면과 함께 삭제됐다 — `.check(verbatimTitle:)` 만 verbatim 변형으로 남는다 |
| 태그 / 썸네일 | `ChalNaTag("LIVE", variant: .live, icon: .film)`(구 `ChalNaChip` 대체) · `MediaThumb(state:size:aspect:) { ... }`(구 `ClipThumbCard`/`LiveBadge` 대체, 6개 상태) |
| 상태 표시 | `ChalNaEmptyState(icon:title:message:actionTitle:action:)` · `ChalNaNotice(icon:title:message:)` · `ChalNaProgressBar(progress:tint:height:)` · `view.chalNaToast(message:onDismiss:)`(모디파이어 — 화면은 내부 `ChalNaToast` 를 직접 쓰지 않는다. 유일한 직접 호출은 Showcase 견본) · `ChalNaBlockingOverlay(...)` — 뒤 세 개는 `ChalNaShadow.floating` 을 공유 |
| 입력 | `ChalNaTextField(...)` · `ChalNaTextArea(placeholder:minHeight:text:)` · `ChalNaSlider(...)` |
| 하단바 / 화면 | `ChalNaBottomBar { ... }`(`safeAreaInset(edge: .bottom)` 에 넣어 쓴다) · `someView.chalNaScreen()`(배경 `ChalNaColor.bg` 풀블리드) · `.chalNaScrollHairline(progress:)`(구 `chalNaHeaderBar`·`+ChalNaTopBar` 대체 — 헤더 hairline 만 남고 배경 페이드는 제거됨) |
| 아이콘 | `ChalNaIcon(.play, size: 20, weight: .semibold)` — 24종, 내부 구현이 **SF Symbols 로 통일**(Task 5, 구 Lucide 커스텀 패스 제거). `@ScaledMetric(relativeTo: .body)` 로 `size` 를 스케일해서 옆 텍스트·Dynamic Type 을 그대로 따라간다 |

**Task 26 에서 삭제된 컴포넌트/토큰**(문서·코드 어디서도 새로 참조하지 않는다): `ChalNaChip` · `ClipThumbCard`/`ClipThumbState` · `ChalNaNavigationBar` · `ChalNaHeaderActionButtonStyle` · `View+ChalNaTopBar`. `ChalNaBottomSheet` 는 그보다 앞선 Task 12 에서 이미 삭제됐다.

### 금지 사항 — `scripts/design-lint.sh` 가 6개 규칙으로 정적 검사한다
- `Color(hex:)`/`Color(red:green:blue:)` **직접 호출 금지** — `ChalNaColor.*` 사용 (hex 이니셜라이저는 토큰 정의 내부 전용).
- `.font(.system(...))` 직접 호출 금지 — `ChalNaTypography.*` 경유. (예외는 세 파일 — 글리프 크기를 지정하는 `ChalNaIcon.swift`, 합성 픽셀과 맞춰야 하는 라벨 박스 `ClipLabelText.swift`·`LabelEditorView.swift`. 아래 "다크 토큰 적용 예외" 참고.)
- `.cornerRadius(15)` 같은 리터럴 금지(콜론형·UIKit 대입형·베어 모디파이어 전부 포함) — `ChalNaRadius.*`.
- `Color.white`/`.white` 하드코딩 금지 — `ChalNaColor.textPrimary` 또는 `.onAccent` 사용.
- `Color.black`/`.black` 하드코딩 금지 — `ChalNaColor.canvas`/`.scrim`/`.onMediaDark` 등 역할 토큰 사용. 흰색 규칙의 대칭 규칙: 값이 검정인 토큰(`canvas` 등)을 역할과 무관하게 범용 검정으로 갖다 쓰는 것도 이 규칙을 우회하진 못한다 — grep 은 토큰 이름이 아니라 최종 리터럴 값을 보지 않으므로, 하드코딩 자체가 없어야 규칙을 통과한다.
- `UIColor(named:)` 금지 — 번들 조회가 조용히 실패한다(과거에 검은 띠 버그를 만들었다). UIKit 에서 색이 필요하면 `UIColor(ChalNaColor.bg)` 처럼 SwiftUI `Color` 를 감싼다.
- `UIFont` 직접 참조 금지 — 자동 시각/날짜 라벨은 `Models.LabelText.uiFont(px:)`, **박스 자막**은 `Models.ClipLabelMetrics.uiFont(px:)`(시스템 light) 경유다. 둘 다 합성·프리뷰가 공유하는 SSOT 이고, 이 통합으로 `CompositionService` 의 `UIFont` 직접 참조(구 `overlayCustomUIFont`)는 사라졌다 — 이제 예외가 없다. 이 규칙은 프로즈일 뿐 `design-lint.sh` 의 6개 규칙에는 들어 있지 않다.
- **`scripts/design-lint.sh` 가 위 6종을 정적 검사한다. 커밋 전에 실행한다.**

**6개 규칙 전부 현재 0건**이지만 전부가 순수 코드 정리의 결과는 아니다 — 규칙 1(`.font(.system(`)의 0 은 코드 정리 + 아래 "다크 토큰 적용 예외"의 **정당한 파일 예외 2건**(`ClipLabelText.swift`·`LabelEditorView.swift`) 덕분이고, 나머지 규칙의 0 은 대부분 코드 정리만의 결과다. 스크립트는 주석 인식(comment-aware)이라 주석 전용 줄은 제외하지만 코드 뒤 trailing 주석은 계속 검사한다 — 반대로 위반 줄 전체를 주석으로 감싸면(그 시점엔 죽은 코드) 스킵되는 건 알려진 한계다. 예외 목록의 근거는 문서가 아니라 스크립트 자체(`scripts/design-lint.sh`)를 단일 출처로 본다. **파일 단위 예외는 그 파일에 실제 매치가 있을 때만 등록한다** — 매치가 없는 예외(죽은 예외)는 그 파일에 새로 들어오는 진짜 위반을 영구히 가리는 눈가림용 구멍이 된다(과거 `LabelEditorView.swift`·`ClipLabel.swift`·`ThumbnailPreset.swift`가 흰색 규칙에 죽은 예외로 남아 있다가 제거된 사례). 다만 현재 스크립트에도 죽은 예외가 3개 남아 있다 — 규칙 1 의 `DesignSystem/Sources/Tokens/`, 규칙 2 의 `Models/Sources/ColorHex.swift`, 규칙 3 의 `ChalNaIcon.swift`(규칙 3 은 저장소 전체 매치가 0). 이 규칙들을 손댈 때 같이 정리한다.

### 다크 토큰 적용 예외 (근거 있는 리터럴)
`design-lint.sh` 의 하드코딩 관련 규칙들(`Color(hex:)`·흰색/검정 하드코딩, 라벨 박스 파일 2건은 `.font(.system(` 도)이 파일 단위로 예외 처리하는 대상이다:
- **라벨 박스 픽셀 일치** — `ClipLabelText.swift`(TimelineFeature). 화면 라벨이 합성(`CATextLayer`)의 `UIFont` 측정값·색과 픽셀 단위로 일치해야 해서, Dynamic Type 에 따라 스케일되는 역할 토큰을 쓸 수 없다. **박스 자막의 색 리터럴은 이 파일의 `ClipLabelBoxPalette` 한곳에만 둔다** — `LabelEditorView.swift` 는 이 헬퍼를 호출하므로 색 리터럴이 없고, 그래서 규칙 5(검정) 예외에서 **제거됐다**(폰트 규칙 1 예외는 `.font(.system(size: fontPx, ...))` 때문에 유지된다). 매치 없는 예외는 그 파일에 새로 들어오는 진짜 위반을 영구히 가린다.
- **미디어 위 마크의 컴포넌트 고유 상수** — `ChalNaTag.swift`(필 배경/보더 `Color.white.opacity(0.08~0.10)`). LIVE/VIDEO 배지처럼 미디어 위에도, 카드·진행률 바처럼 UI 크롬 위에도 동일하게 올라가는 범용 컴포넌트라 "미디어 위 마크"(`onMedia`) 역할로 좁혀 쓸 수 없고, `scrim`(0.6, 어둡게 덮는 용도)과도 강도·목적이 다르다. **주의**: 과거 이 예외를 "토큰으로 표현할 수 없는 합성 연산"이라 적었으나 틀렸다 — 같은 팔레트의 `ChalNaColor.scrim = Color.black.opacity(0.6)`(`Tokens/ChalNaColor.swift`) 자체가 반투명 오버레이도 토큰으로 표현 가능하다는 반증이다. 실제 이유는 이 상수가 ChalNaTag 하나만 쓰는 단일 소비자 값이라 아직 전용 토큰으로 승격되지 않았을 뿐이라는 것.
- **콘텐츠 그라디언트** — `ThumbnailPreset.swift`(12종 여행 톤 그라디언트, `Color(hex:` 40건). Models 이고 UI 크롬이 아니라 콘텐츠이므로 다크 팔레트 규율 밖이라 `Color(hex:)` 규칙의 예외다. 같은 규칙에 등록된 `ColorHex.swift`(그 hex 헬퍼)는 이니셜라이저 *정의* 만 있어 매치 0건인 죽은 예외다 — 정리 대상.

`MediaThumb.swift` 는 과거 흰색 규칙에 예외로 있었으나, 실제 매치는 프로덕션 코드(고스트 슬롯 그라디언트)가 아니라 `#Preview` 데코 샘플 색이었다 — 문서 근거 자체가 틀렸던 죽은 예외라 Preview 색을 바꿔 매치를 없애고 예외를 뗐다.

### 접근성 — Dynamic Type 상한
`RootView` 의 전역 상한(`.dynamicTypeSize(...DynamicTypeSize.accessibility1)`)은 **`.sheet`/`.fullScreenCover` 경계를 넘어 전달되지 않는다** — SwiftUI 환경값이 프레젠테이션 경계에서 다시 시작되기 때문이다(Task 25 실측: 기본 16.0pt에서 상한 미적용 시 AX1 27.5pt를 지나 AX5 53.0pt까지 커짐, 상한 적용 후 34pt 미만). 개발 언어·기본 텍스트 크기로 테스트하면 이 누락은 전혀 보이지 않는다.

**그래서 `.sheet`/`.fullScreenCover` 로 뜨는 화면마다 그 안에서 상한을 다시 걸어야 한다.** 현재 7곳 전부 걸려 있다: `MediaPickerView`(포토 피커 시트·프리뷰 시트, 2곳) · `ExportView` · `TimelineView`(LabelEditor fullScreenCover) · `FilmDetailView`(재생 시트·공유 시트, 2곳) · `SupportView`. **새 `.sheet`/`.fullScreenCover` 를 추가할 때마다 반드시 같은 상한을 붙인다** — 잊으면 조용히 새는 버그가 된다.

> **상한은 프레젠테이션 *콘텐츠* 에 걸어야 한다 — 띄우는 쪽 뷰에 걸면 안 된다.** 즉
> `.sheet { Foo().dynamicTypeSize(...) }` 이지 `.sheet { Foo() }.dynamicTypeSize(...)` 가 아니다.
> 후자는 컴파일도 되고 경고도 없지만 경계를 넘지 못하므로 아무 효과가 없다 — 이 규칙에서
> 실수하기 가장 쉬운 지점이고, 기본 텍스트 크기 테스트로는 구별되지 않는다.
>
> `UIActivityViewController`·`PHPickerViewController`·`ShareLink` 처럼 프로세스 밖에서 뜨는
> 시스템 UI 는 상한 대상이 아니다(걸어도 무효). `.alert`·`.confirmationDialog` 도 제외 —
> 상한을 걸 수 없고 시스템이 자체 스크롤을 제공한다.

## 테스트
- 서비스/모델은 **Swift Testing**(`@Test`/`#expect`)으로 작성, `SampleData` 활용. actor/Client 는 프로토콜 + `testValue` 로 격리.
- 모델·서비스를 직접(예: `ClipFraming.resolvedRect`, `AVFoundationCompositionService().export(clips:)`) 테스트하거나, 필요 시 TCA `TestStore` 사용 가능(현재 5개 테스트 파일이 쓴다).
- UI 는 스냅샷 대신 `#Preview` 적극 활용 (각 뷰 상태별).
- 2026-08-25 기준 8개 유닛 스위트 전부 그린(17 Pro, 총 **187** 케이스): `DesignSystem` 22 · `TimelineFeature` 26 · `SettingsFeature` 13 · `MediaPickerFeature` 2 · `ExportFeature` 7 · `CompositionService` 81 · `AppCore` 32 · `PhotosService` 4. UI 테스트(`ChalNaUITests`)는 별도 7 케이스. 이후 태스크가 이 수치를 크게 벗어나면 회귀를 의심한다.
  - **직전 기재값 166 은 1 만큼 틀렸다** — `TimelineFeature` 는 25 가 아니라 **26** 이었다(`ClipLabelBoxPaletteTests` 가 4 가 아니라 5 케이스). 실제 기준선은 167 이었고, 아래 증감은 그 167 을 기준으로 센 것이다. 수치를 옮겨 적을 때는 실행 출력을 세어 맞춘다.
  - 167 → 187(**+20**), 전부 라벨 개선 3건에서 나왔다: `CompositionService` +17(`ClipLabelMetricsTests` 10 신규 · `ClipLabelRotationTests` 6 신규 · `CompositorLabelTests` +1 회전 잘림 픽셀 가드), `AppCore` +3(`ClipLabelTests` 에 회전 기본값·동등성·clamp). `TimelineFeature` 는 26 그대로인데 내부적으로 1건 교체가 있었다 — `LabelAnchorMathTests.testSizeGrows_TopLeadingCornerFixed_ExpandsRightAndDown`(코너 고정)을 `testSizeGrows_CenterFixed_ExpandsEvenly`(중심 고정)로 바꿨다. 그 테스트는 순수 함수만 보므로 정책이 바뀌어도 **통과했지만**, 에디터 정책과 정반대를 설명하고 있었다.
  - 라벨 설정 삭제로 SettingsFeature 는 **28→13** 으로 줄었다(삭제분: `LabelPositionFeatureTests` 2 · `LabelPositionTests` 7 · `LabelSettingsFeatureTests` 5 · `labelMenuTapEmitsDelegate` 1 = 15). 한때 이 문단이 "직전 기재값 28 은 스테일이고 실제로는 26→13" 이라고 적었는데 **28 이 맞았다** — 세어보면 13+15=28 이다.
  - PR #38 리뷰 후속으로 10 케이스가 늘었다: `AppCore/RemovedSettingsCleanupTests` 3 · `CompositionService/LabelTextTests` 5(대신 change-detector 였던 `fontFractionsAreCornerStampSized` 1 삭제) · `TimelineFeature/AutoLabelsOverlayFidelityTests` 3.

## 검증 방법 (시뮬레이터 / UI 테스트 노하우)
다크 리디자인 사이클에서 실제로 시간을 잡아먹은 함정들이다. 다음 사람이 또 반복하지 않도록 적어둔다.

- **`simctl` 은 탭·타이핑을 못 한다.** 화면 조작이 필요한 검증은 XCUITest 로만 가능하다(합성 터치·키보드 둘 다 있음). 버튼 없이 특정 화면을 스크린샷하려면 `ContentView` 의 `AppMode.isShowcase` 분기를 그 화면에 맞춰 임시로 바꾸고 `SIMCTL_CHILD_CHALNA_APP_MODE=showcase xcrun simctl launch <device> ios.inho.ChalNa` 로 실행한 뒤 되돌린다.
- **`simctl launch` 에 환경변수를 넘길 땐 `SIMCTL_CHILD_` 접두사가 필요하다.** `--CHALNA_APP_MODE devMock` 같은 인자는 조용히 무시된다(`AppMode` 가 `ProcessInfo.processInfo.environment` 를 읽으므로). XCUITest 에선 `app.launchEnvironment["CHALNA_APP_MODE"] = "devMock"` 을 쓴다.
- **`xcrun simctl ui <device> content-size` 는 이 앱엔 적용되지 않는다** — 강제한 xxxLarge 스크린샷이 기본값과 바이트 단위로 동일하게 나온 적이 있다(재부팅 후에도). 코드에서 `.environment(\.dynamicTypeSize, ...)` 로 강제해야 한다.
- **`print()` 는 UI 테스트 중 `xcodebuild` stdout 도 unified log 도 타지 않는다** — 매 렌더링마다 찍는 무조건 print 로 확인해도 매치 0건이었다. 대신 앱 컨테이너에 파일로 쓰고 호스트에서 `xcrun simctl get_app_container <device> ios.inho.ChalNa data` 로 읽는다. (Task 25 는 이 채널의 침묵을 "증거 없음"으로 잘못 해석해 결론을 철회한 적이 있다 — 침묵을 증거로 쓰지 않는다.)
- **`LocalizedStringKey` 에 카탈로그 항목이 없으면 한국어 키를 그대로 렌더링한다** — 개발 언어(한국어)로 테스트하면 안 보인다. `-AppleLanguages "(en)"` 로 한 번은 꼭 실행한다.
- **Xcode `#Preview` 캔버스에서 점(pt) 측정을 하지 않는다**(~0.583 pt/px 스케일 차이 관측) — 시뮬레이터에 설치 후 스크린샷하고, 표시 좌표 → 원본 좌표 환산을 거쳐서 계산한다.
- **`.aspectRatio(.fit)` 는 높이 제안이 무한(예: `ScrollView` 내부)이면 무한 높이로부터 너비를 유도해 오동작한다** — 높이가 유한한 컨테이너에선 상한으로만 작동해 무해하다. `ChalNaCanvas` 는 내부에서 이미 fit 하므로 바깥에서 다시 `aspectRatio` 로 감쌀 필요가 없다 — 유일한 예외는 `ExportView` 의 커버로, 높이 예산이 이미 유한한 자리에서 폭 상한(`.frame(maxWidth: 300)` + `.aspectRatio(9/16, .fit)`)을 걸기 위해 의도적으로 겹쳐 쓴 것이고 근거가 그 파일 주석에 있다. 높이 무제약 컨텍스트(`ScrollView` 등)로 이 조합을 복사하지 말 것.
- **devMock(`BundledDevMediaSource`) fixture 는 시각 검증 채널로 쓰지 않는다** — 실제 미디어(사진 라이브러리)와 차이가 커서, 여기서 관찰한 결과로 시각·기하 결론을 내리면 안 된다(사용자 지시). dev fixture 4개(`Modules/PhotosService/Resources/DevFixtures/*.mp4`)는 전부 `mdls`/`AVAssetTrack.naturalSize` 로 교차 확인한 **360×640 세로(9:16)** 라 1080×1920 캔버스와 **종횡비가 정확히 일치**한다(`fillScale = max(1080/360, 1920/640) = 3.0`) — 종횡비가 다양하게 섞이는 실제 사진 라이브러리와 여기가 가장 크게 갈리는 지점이다. 한때 이 불릿에는 `CropAdjustUITests` 스크린샷 체크포인트가 두 번의 독립 실행 모두 바이트 단위로 동일했다는 실측과 그 인과(옛 `maxOffsetFraction` 이 양축 모두 0 · 옛 핀치 클램프 `min(max(scale, 1.0), 4.0)`)가 적혀 있었지만, **그 두 제약은 자유 크롭 전환으로 삭제됐으므로 지금 코드에서는 재현되지 않는다** — 축소와 캔버스 밖 이동이 실제로 화면에 나타난다. 당시 기록은 `ChalNaUITests/CropAdjustUITests` 클래스 doc 에 과거형으로 남겨뒀다. 그래도 결론은 그대로다 — **devMock 은 시각 검증 채널이 아니므로**(위 사용자 지시), 이 UI 테스트는 도달성(reachability)·무크래시 스모크 테스트로만 취급한다. 실제 크롭·라벨 기하 가드는 유닛 테스트가 담당한다: `CompositionServiceTests/ClipFramingTests`(offset 이 clamp 없이 반영되는지, 축소가 전경을 캔버스보다 작게 만드는지), `CompositionServiceTests/CompositorRenderTests.testCompositor_ScaleBelowFill_LeavesBlackMargin`(실제 export 프레임을 픽셀 샘플링해 축소 여백이 검정인지 확인), `CompositionServiceTests/CustomLabelLayoutTests` + `CompositorLabelTests`(라벨 배경 ON/OFF 분기). 이 때문에 유닛 테스트 실행 명령에는 `-skip-testing:ChalNaUITests` 가 필요하다 — `ChalNa-Workspace` 스킴의 test 액션은 이를 지정하지 않으면 이 devMock UI 테스트까지 함께 돌린다.
- **이 저장소의 interactive shell(zsh)에서 `grep` 은 oh-my-zsh alias(`grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox,.venv,venv}`)로 감싸져 있다** — 실체는 `/usr/bin/grep`(BSD grep, GNU 호환)이라 `-E` 확장 정규식은 정상 동작한다(`ugrep` 은 설치돼 있지 않다 — 한때 이 불릿이 `ugrep -G` 재정의라고 적었으나 `whence -v grep`·`which ugrep` 실측으로 틀렸음이 확인됐다). 실제 함정은 zsh 가 인용하지 않은 `--include=*.swift` 를 글로브로 해석해 `no matches found` 로 명령 전체를 중단시키는 것이니, 글로브를 닮은 인자는 반드시 인용한다. alias 의 `--exclude-dir`(`.git` 등)·`--color` 를 배제해야 할 때만 `command grep` 을 쓴다.

## 커밋 / PR
- 단계가 끝나면 커밋, 메시지 한국어 OK. Claude 가 커밋할 땐 변경 파일 요약을 한국어로.

> **참고**: 루트의 `AGENTS.md` 는 커밋 `062e8bb`(dark-redesign 사이클 시작 전, 2026-07-09)에서 "agent skill·임시 문서 등 불필요 파일 제거"의 일부로 **삭제됐다** — 이 브랜치에는 존재하지 않는다. 과거엔 이 문서의 미러본(앞부분 Codex workflow 노트만 추가)이었다. `main` 브랜치는 그 삭제 커밋을 포함하지 않는 별도 이력이라 아직 파일이 남아 있다.
