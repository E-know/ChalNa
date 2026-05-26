# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# ChalNa — iOS 앱

Live Photo와 동영상을 촬영일 순서로 이어붙여 Vlog를 만드는 iOS 앱.

> **네이밍**: Tuist 타겟·Xcode 프로젝트·번들 ID·디자인 시스템 brand prefix 모두 `ChalNa`(`ios.inho.ChalNa`, `ChalNaColor`, `ChalNaTypography`, `ChalNaButton` 등)로 통일되어 있다.

## 빌드 / 실행 / 테스트

이 프로젝트는 **Tuist** 기반이라 `.xcodeproj`는 생성물이다. 클론 직후 또는 `Project.swift` / `Tuist/Package.swift` 수정 후에는 반드시 재생성한다.

```bash
# Xcode 프로젝트 생성/갱신 (필수, 첫 셋업·의존성 변경 후)
tuist generate

# 워크스페이스 열기
open ChalNa.xcworkspace

# CLI 빌드 (시뮬레이터)
xcodebuild -workspace ChalNa.xcworkspace \
           -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           build

# 전체 테스트
xcodebuild -workspace ChalNa.xcworkspace \
           -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           test

# 단일 테스트만 (Swift Testing 파일/케이스 단위)
xcodebuild ... test \
  -only-testing:ChalNaTests/TimelinePlaybackTests/testAdvancePlayheadSimulated_UpdatesCurrentIndex
```

iOS 빌드/시뮬레이터 실행 작업은 가능하면 `ios-build-run` 서브에이전트에 위임한다 (매번 fresh build → 시뮬레이터 설치/실행으로 시각 검증).

> Tests 폴더의 케이스는 SwiftUI Preview 보조용 `SampleData`를 적극 활용한다. 새 서비스는 프로토콜 기반으로 만들고 `@Test`(Swift Testing)로 작성한다 — XCTest 금지(UI 테스트 제외).

## 기술 스택 (엄수)
- **Swift 6.0+, iOS 18+** (`AVAssetExportSession.states(updateInterval:)` 사용으로 deployment 18 고정)
- **SwiftUI 전용** (UIKit은 `PHPickerViewController`, `AVPlayerViewController` 
  같은 불가피한 경우에만 `UIViewControllerRepresentable`로 래핑)
- **Swift Concurrency 전용**: `async/await`, `actor`, `Task`, `AsyncStream`
  - **GCD(`DispatchQueue`, `DispatchGroup` 등) 사용 금지**
  - 콜백 기반 API는 `withCheckedContinuation` / `withCheckedThrowingContinuation`으로 
    반드시 async 래핑
- **Observation 프레임워크** (`@Observable`) 사용, `ObservableObject`/`@Published` 금지
- **Swift Testing** (`import Testing`) 사용, XCTest 금지 (단 UI 테스트 제외)

## 아키텍처
- **MV 패턴** (Model + View), ViewModel은 `@Observable` 클래스로
- **Tuist 멀티 타겟** — 앱은 얇은 셸이고 레이어/피처는 staticFramework 모듈로 쪼개져 있다.

### 모듈 그래프 (의존 방향: 위 → 아래)

```
              ┌──────────────────────────┐
              │  ChalNa (앱 셸)          │  @main · ContentView · RootView
              └────┬─────────────────────┘
                   │
   ┌──────┬────────┼─────────┬──────────────┐
   ▼      ▼        ▼         ▼              ▼
HomeFt MediaPickerFt TimelineFt ExportFt   AppCore (Router · Session)
   │      │         │         │              │
   └──────┴────┬────┴────┬────┘              │
              ▼         ▼                    │
        DesignSystem  CompositionService     │
              │         │                    │
              └─────────┴────── Models ──────┘
                                    │
                              (Film · Clip · ClipRotation ·
                               ThumbnailPreset · SampleData)
```

- **`Modules/<Name>/Sources/`** 가 모든 모듈의 표준 위치. 리소스는 `Modules/<Name>/Resources/`.
- **앱 셸**(`ChalNa/Sources/`) 에는 `ChalNaApp.swift`, `ContentView.swift`, `App/RootView.swift` 만 잔류 — Feature dispatch 책임만.
- 새 모듈을 만들 때는 `Tuist/ProjectDescriptionHelpers/Module.swift` 의 `Module.framework(name:hasResources:dependencies:)` 헬퍼 사용. `Project.swift` 에 추가 후 `tuist generate`.
- 단일 모듈만 빌드하려면 `tuist focus <Module>` (예: `tuist focus DesignSystem`).
- 의존성 그래프 재확인: `tuist graph` → `docs/architecture-graph.png`.

### 레이어 규칙
- **DesignSystem 은 어떤 모듈에도 의존하지 않는다** (가장 아래)
- **Models**: 현재 ThumbnailPreset 의 `Color(hex:)` 때문에 DesignSystem 의존 (향후 정리 예정)
- **Services (Composition · Photos)**: Models 만 의존
- **AppCore**: Models 만 의존, Feature 모름
- **Feature 끼리 직접 import 금지** — 화면 전환은 AppCore 의 `AppRouter`/`EditSession` 으로
- 서비스 레이어는 **프로토콜 + actor 구현체** (테스트 용이성)
- 의존성 주입은 생성자 주입, 서드파티 DI 프레임워크 금지

### 런타임 흐름 (반드시 숙지)
- `ChalNaApp`(`@main`) → `RootView` → `NavigationStack(path: router.path)`
- `RootView`가 두 개의 `@Observable`을 **환경값**으로 한 번만 주입한다:
  - `AppRouter` — `enum Route { mediaPicker | timeline | export }` 스택. Home은 루트라 push하지 않음.
  - `EditSession` — `title` + `[Clip]`. 화면 간 편집 상태 전달은 **Route payload가 아니라 이 EditSession에 실어 흘려보낸다**.
- 화면 호출: `@Environment(AppRouter.self)`, `@Environment(EditSession.self)`로 받아서 `router.push(.timeline)` 등으로 진행. 새 화면 추가 시 `Route` enum과 `RootView.destination(for:)` switch에 케이스를 더한다.
- 모든 push 화면은 기본 네비게이션 바를 숨기고(`toolbar(.hidden)`), `.chalNaSwipeBack()` 커스텀 스와이프로 뒤로가기를 제공한다.

### 모델 / 영속화 경계
- **`Clip`** (`Modules/Models/Sources/Clip.swift`) — 편집 세션의 in-memory value type. SwiftData 모델 아님.
- **`Film`** (`Modules/Models/Sources/Film.swift`) — `@Model`(SwiftData) 라이브러리 단위. mp4 자체는 `Documents/films/<id>.mp4`로 복사하고 모델에는 **상대 경로(`movieFilename`)**만 둔다 (앱 재설치 시 절대 경로가 바뀌므로). 썸네일은 `@Attribute(.externalStorage)`. 파일 청소는 `FilmStorage` 헬퍼 사용 (현재 Models 안에 잔류, 향후 Services 산하로 이동 검토).
- `ChalNaApp`은 `WindowGroup`에 `.modelContainer(for: Film.self)`만 부착한다. 새 `@Model` 추가 시 여기 시그니처도 갱신.

## 코드 컨벤션
- 타입 추론이 명확한 곳에서는 타입 생략, 공개 API는 명시
- `self.` 명시 (클로저/이니셜라이저 외에는 생략)
- Spacing/padding 은 토큰 없이 리터럴 숫자(`.padding(16)`)로 직접 기입한다. 색/타이포/라디우스/섀도우 는 여전히 토큰 사용.
- 한국어 주석 OK, 식별자는 영어
- 한 파일 = 한 타입 원칙, 단 긴밀하게 결합된 small helper는 예외

## Photos 프레임워크 원칙
- `PHPickerViewController`로 선택 (권한 최소화 관점)
- 선택 결과에서 `PHAsset`이 필요하면 `PHAsset.fetchAssets(withLocalIdentifiers:)`로 재조회
- Live Photo의 비디오 추출은 `PHAssetResourceManager.requestData` 또는 
  `PHImageManager.requestLivePhoto` → `PHLivePhotoRequestOptions`로
- 모든 PhotoKit 접근은 `PhotoLibraryService` actor를 통해서만

## 비디오 합성 원칙
- `AVMutableComposition` + `AVMutableVideoComposition` 사용
- 익스포트는 `AVAssetExportSession.export(to:as:)` async API 사용 (iOS 18+) 
  또는 `AsyncStream`으로 진행률 래핑
- 모든 트랙 조작은 `CompositionService` actor 내부에서만

## 에러 처리
- `throws` 사용, `Result` 타입은 Swift 6에서 지양
- 도메인별 에러 enum: `PhotoError`, `CompositionError`, `ExportError`
- 사용자 표시용 메시지는 `LocalizedError.errorDescription`으로 분리

## 디자인 시스템 (ChalNa)

모든 UI 는 `Modules/DesignSystem/Sources/` 의 토큰/컴포넌트를 사용한다 (단, **spacing/padding 은 토큰 없이 리터럴 숫자로 직접 기입**). **리터럴 HEX·폰트명 금지**. 새 컴포넌트를 만들기 전에 기존 것부터 재사용.

### 파일 레이아웃
```
Modules/DesignSystem/Sources/
├─ Tokens/       ChalNaColor · Typography · Radius · Shadow
├─ Effects/      PaperGrainOverlay · HandwrittenUnderline · Vignette
├─ Components/   ChalNaButton · ChalNaChip · PolaroidCard · MaskingTape
│                StampBadge · StickerRing · FilmStripBackground
│                ScallopDivider · PunchHole
├─ Icons/        ChalNaIcon (Lucide 스타일 8종, 1.5pt stroke)
└─ Showcase/     DesignSystemShowcaseView (무드보드 검증용)
```

### Colors — `ChalNaColor`
| API | HEX | 용도 |
|---|---|---|
| `.cream` | `#FBF6EE` | Background |
| `.ivory` | `#F2E9D8` | Surface |
| `.coral` | `#E8A598` | **Primary / CTA** |
| `.sage`  | `#A8B89E` | Secondary |
| `.denim` | `#7A92A8` | Info / Link |
| `.ink`   | `#3D2E24` | Text Primary |
| `.taupe` | `#8B7968` | Text Sub |
| `.Chip.{live,video,film}Background/Foreground` | — | 칩 전용 파생색 |

- 사용 비율 **60 / 30 / 10 = cream / ivory / coral**
- Asset Catalog 기반 (`Assets.xcassets/Colors/ChalNa*.colorset`)

### Typography — `ChalNaTypography`
- Display EN: `.serifFallback(size, italic:)` — Fraunces → 시스템 serif
- Display KR: `.displayKR(size)` — Pretendard 700, tracking `-0.02em`
- Body KR: `.krBody(size, weight:)` / `.krSemibold(size)`
- Hand: `.handFallback(size)` — Bradley Hand (메모·서명 전용)
- Mono: `.monoFallback(size, weight:)` — SF Mono (tag label)
- 스케일: `Size.tag(10) / caption(14) / body(16) / bodyLg(18) / h2(24) / h1(32) / displayS(48) / displayL(72)`
- tag label: `Text("...").tagLabel()` 확장으로 통일

### Spacing / Padding
- 토큰 없이 **리터럴 숫자로 직접 기입**한다 (`.padding(16)`, `HStack(spacing: 8)` 등).
- 권장 스케일 (참고): `4 · 8 · 12 · 16 · 24 · 32 · 48 · 64 · 96` (4pt base). 강제는 아님.
- HIG 최소 터치 영역은 `44`pt 를 직접 사용한다.

### Radius — `ChalNaRadius`
| API | 값 | 용도 |
|---|---|---|
| `.film`   | 4  | Polaroid |
| `.button` | 12 | 버튼 |
| `.card`   | 16 | 카드 |
| `.sheet`  | 20 | 모달 / 시트 |
| `.pill`   | 999 | 칩 |

### Shadow — `ChalNaShadow` + `View.chalNaShadow(_:)`
`.sm` chip/pill · `.md` card/polaroid · `.lg` modal/sheet · `.polaroid` 전용 3단 중첩

### Core Components API
| 컴포넌트 | 사용 예시 |
|---|---|
| 버튼 | `Button { } .buttonStyle(.chalNaCoral / .chalNaOutline / .chalNaText)` |
| 칩 | `ChalNaChip("LIVE", variant: .live, icon: .film)` |
| 폴라로이드 | `PolaroidCard(rotation: .left, caption:, meta:, topTape:) { image }` |
| 아이콘 | `ChalNaIcon(.play, size: 24)` — 8종: play/pause/plus/share/download/heart/calendar/film |
| 테이프 | `MaskingTape(width:, height:, tint: .coral / .sage / .ivory)` |
| 스탬프 | `StampBadge("Draft · v0.1", angle: -8)` |
| 필름스트립 | `FilmStripBackground { /* 어두운 배경 + sprocket dot */ }` |
| 구분선 | `ScallopDivider()` |
| 그레인 | `.paperGrain(opacity: 0.35)` · `.chalNaVignette(0.08)` |

### 무드 원칙 (디자인 결정시 체크)
1. 편집하지 않은 듯, 편집한 것 — 자동화 뒤의 손맛.
2. 화면은 필름 한 컷, 여백은 빛.
3. 한글 먼저 읽히게, 영문은 노래처럼.
4. 파스텔은 밝지만, 흐리지 않게.

**모든 최상위 화면 배경은 `ChalNaColor.cream`**,
최상위에 `.paperGrain()` 오버레이 적용 (per-screen).

### 금지 사항
- `Color(hex: 0x...)` / `Color(red:green:blue:)` 직접 호출 금지
- `.font(.system(size: 16))` 금지 — 반드시 `ChalNaTypography.*` 경유
- `.cornerRadius(15)` 금지 — `ChalNaRadius.*` 사용
- `UIColor` / `UIFont` 직접 참조 금지 (단 `PaperGrainOverlay` 내부 예외)

## 테스트
- 서비스 레이어는 프로토콜 기반 mock으로 Swift Testing 작성
- UI는 스냅샷 테스트 대신 Preview 적극 활용
- `#Preview` 매크로로 각 뷰의 상태별 프리뷰 작성

## 커밋 / PR
- 각 단계가 끝나면 커밋, 커밋 메시지는 한국어 OK
- Claude Code가 커밋할 때는 반드시 변경 파일 요약을 한국어로 작성