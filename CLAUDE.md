# Moments — iOS 앱

Live Photo와 동영상을 촬영일 순서로 이어붙여 Vlog를 만드는 iOS 앱.

## 기술 스택 (엄수)
- **Swift 6.0+, iOS 17+**
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
- 피처 단위 폴더링:

```
Moments/
App/              # @main, AppRouter
DesignSystem/     # 컬러, 타이포, 컴포넌트
Features/
Home/
MediaPicker/
Timeline/
Export/
Services/
Photos/         # PhotoKit 래퍼 (actor)
Composition/    # AVFoundation 비디오 합성 엔진
Models/
Extensions/
```

- 서비스 레이어는 **프로토콜 + actor 구현체**로 작성 (테스트 용이성)
- 의존성 주입은 생성자 주입, 서드파티 DI 프레임워크 사용 금지

## 코드 컨벤션
- 타입 추론이 명확한 곳에서는 타입 생략, 공개 API는 명시
- `self.` 명시 (클로저/이니셜라이저 외에는 생략)
- 매직 넘버 금지, `DesignSystem/Tokens.swift`에 상수화
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

## 디자인 시스템 (Moments)

모든 UI 는 `OneSecMovie/Sources/DesignSystem/` 의 토큰/컴포넌트만 사용한다.
**리터럴 HEX·폰트명·매직 넘버 금지**. 새 컴포넌트를 만들기 전에 기존 것부터 재사용.

### 파일 레이아웃
```
OneSecMovie/Sources/DesignSystem/
├─ Tokens/       MomentsColor · Typography · Spacing · Radius · Shadow
├─ Effects/      PaperGrainOverlay · HandwrittenUnderline · Vignette
├─ Components/   MomentsButton · MomentsChip · PolaroidCard · MaskingTape
│                StampBadge · StickerRing · FilmStripBackground
│                ScallopDivider · PunchHole
├─ Icons/        MomentsIcon (Lucide 스타일 8종, 1.5pt stroke)
└─ Showcase/     DesignSystemShowcaseView (무드보드 검증용)
```

### Colors — `MomentsColor`
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
- Asset Catalog 기반 (`Assets.xcassets/Colors/Moments*.colorset`)

### Typography — `MomentsTypography`
- Display EN: `.serifFallback(size, italic:)` — Fraunces → 시스템 serif
- Display KR: `.displayKR(size)` — Pretendard 700, tracking `-0.02em`
- Body KR: `.krBody(size, weight:)` / `.krSemibold(size)`
- Hand: `.handFallback(size)` — Bradley Hand (메모·서명 전용)
- Mono: `.monoFallback(size, weight:)` — SF Mono (tag label)
- 스케일: `Size.tag(10) / caption(14) / body(16) / bodyLg(18) / h2(24) / h1(32) / displayS(48) / displayL(72)`
- tag label: `Text("...").tagLabel()` 확장으로 통일

### Spacing — `MomentsSpacing` (4pt base)
`xxs(4) · xs(8) · sm(12) · md(16) · lg(24) · xl(32) · xxl(48) · xxxl(64) · huge(96)`

### Radius — `MomentsRadius`
| API | 값 | 용도 |
|---|---|---|
| `.film`   | 4  | Polaroid |
| `.button` | 12 | 버튼 |
| `.card`   | 16 | 카드 |
| `.sheet`  | 20 | 모달 / 시트 |
| `.pill`   | 999 | 칩 |

### Shadow — `MomentsShadow` + `View.momentsShadow(_:)`
`.sm` chip/pill · `.md` card/polaroid · `.lg` modal/sheet · `.polaroid` 전용 3단 중첩

### Core Components API
| 컴포넌트 | 사용 예시 |
|---|---|
| 버튼 | `Button { } .buttonStyle(.momentsCoral / .momentsOutline / .momentsText)` |
| 칩 | `MomentsChip("LIVE", variant: .live, icon: .film)` |
| 폴라로이드 | `PolaroidCard(rotation: .left, caption:, meta:, topTape:) { image }` |
| 아이콘 | `MomentsIcon(.play, size: 24)` — 8종: play/pause/plus/share/download/heart/calendar/film |
| 테이프 | `MaskingTape(width:, height:, tint: .coral / .sage / .ivory)` |
| 스탬프 | `StampBadge("Draft · v0.1", angle: -8)` |
| 필름스트립 | `FilmStripBackground { /* 어두운 배경 + sprocket dot */ }` |
| 구분선 | `ScallopDivider()` |
| 그레인 | `.paperGrain(opacity: 0.35)` · `.momentsVignette(0.08)` |

### 무드 원칙 (디자인 결정시 체크)
1. 편집하지 않은 듯, 편집한 것 — 자동화 뒤의 손맛.
2. 화면은 필름 한 컷, 여백은 빛.
3. 한글 먼저 읽히게, 영문은 노래처럼.
4. 파스텔은 밝지만, 흐리지 않게.

**모든 최상위 화면 배경은 `MomentsColor.cream`**,
최상위에 `.paperGrain()` 오버레이 적용 (per-screen).

### 금지 사항
- `Color(hex: 0x...)` / `Color(red:green:blue:)` 직접 호출 금지
- `.font(.system(size: 16))` 금지 — 반드시 `MomentsTypography.*` 경유
- `.padding(17)` 같은 비-4pt 값 금지 — `MomentsSpacing.md` 사용
- `.cornerRadius(15)` 금지 — `MomentsRadius.*` 사용
- `UIColor` / `UIFont` 직접 참조 금지 (단 `PaperGrainOverlay` 내부 예외)

## 테스트
- 서비스 레이어는 프로토콜 기반 mock으로 Swift Testing 작성
- UI는 스냅샷 테스트 대신 Preview 적극 활용
- `#Preview` 매크로로 각 뷰의 상태별 프리뷰 작성

## 커밋 / PR
- 각 단계가 끝나면 커밋, 커밋 메시지는 한국어 OK
- Claude Code가 커밋할 때는 반드시 변경 파일 요약을 한국어로 작성