# 클립별 사용자 라벨 (Per-Clip Custom Label) — 설계 스펙

- 날짜: 2026-05-31
- 브랜치 기준: `feature/settings`
- 상태: 설계 확정(사용자 승인) → 구현 계획 단계로 전환

## 1. 목표 & 범위

타임라인의 **모든 클립**(Live Photo + 일반 비디오)에 사용자가 직접 텍스트 라벨을 적어 붙일 수 있게 한다.

- 클립을 탭 → **전체화면 라벨 에디터** 진입.
- 클립 이미지 위에서 라벨을 **자유 드래그**로 위치 지정(기본값 정중앙).
- **슬라이더로 글자 크기** 조절.
- **폰트 선택**: `MemomentKkukkukk`("꾸꾸") 또는 기본(시스템) 폰트.
- **스타일 선택**: `검정 글자(배경 없음)` 또는 `흰 글자 + 검정 배경`.
- export 시 각 클립의 라벨을 **그 클립 구간에만** 영상에 burn-in.
- 기존 **자동 시간/날짜 라벨(`LabelSettings`)과 공존**(둘 다 표시).

### 비범위 (v1 제외)
- 에디터에 자동 시간/날짜 라벨 미리보기(겹침 회피는 사용자가 드래그로 수동 처리).
- 라벨의 영구 저장(SwiftData) — 회전과 동일하게 편집 세션 동안만 유지하는 in-memory 상태.
- 멀티라인/줄바꿈, 텍스트 색상 커스터마이즈(검정/흰 두 스타일 외), 회전/기울임.

## 2. 기존 구조 (조사 확인됨)

- **편집 메타는 `Clip`(불변 struct)이 아니라 `EditSession`(@Observable)의 per-clip 딕셔너리에 저장**된다. 회전이 그 예: `rotations: [Clip.ID: ClipRotation]` + `rotation(for:)` + `cycleRotation(for:)`. 라벨도 동일 패턴을 따른다.
- **영상 텍스트 burn-in**은 `AVFoundationCompositionService.makeDateLabelAnimationTool`이 `AVVideoCompositionCoreAnimationTool` + `CATextLayer`로 처리. 각 클립의 `timeRange` 동안만 `CABasicAnimation(opacity)`로 표시. 좌표계는 **CoreAnimation(좌하단 원점, y-up)**.
- `buildComposition`은 클립별 `(timeRange, transform, capturedAt)`를 `layerInstructions`에 누적하고, `transform()`이 aspectFit + 가운데 정렬(레터박스)을 계산한다.
- **`MemomentKkukkukk.ttf`는 이미** `ChalNa/Resources/Fonts/MEMOMENT/`에 번들돼 있음. `UIAppFonts` 미등록 상태. 폰트 name table: family `MemomentKkukkukk`, PostScript `MemomentKkukkukkR-KSCpc-EUC-H`(한국어 폰트 EUC 인코딩) → 하드코딩 대신 **런타임 family 탐색**(KERISKEDU `keris()` 패턴) 사용.
- export 데이터 흐름: `ExportView.onAppear` → `store.send(.startExport(clips:rotations:))` → reducer가 `LabelSettings` 조립 → `compositionClient.export(clips, rotations, labelSettings)`.
- `ChalNaIcon`은 `.rotate`에서 SF Symbol(`Image(systemName:)`)을 escape-hatch로 사용 → 새 아이콘도 같은 방식으로 추가 가능.

## 3. 데이터 모델 — `Modules/Models/Sources/ClipLabel.swift` (신규)

```swift
import CoreGraphics

public struct ClipLabel: Equatable, Sendable {
    public var text: String              // 빈/공백이면 라벨 없음
    public var font: LabelFont           // .memoment | .system
    public var style: LabelTextStyle     // .plain | .boxed
    public var sizeFraction: CGFloat     // 클립 이미지 높이 대비 글자 크기 (clamp 0.04...0.25)
    public var position: CGPoint         // 클립 이미지 내 정규화 좌표; x,y ∈ 0...1, y는 위→아래(스크린 방향)

    public init(text: String = "", font: LabelFont = .memoment, style: LabelTextStyle = .plain,
                sizeFraction: CGFloat = 0.10, position: CGPoint = CGPoint(x: 0.5, y: 0.5)) { ... }

    public var isVisible: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    public static let `default` = ClipLabel()
}

public enum LabelFont: String, Sendable, CaseIterable, Codable {
    case memoment, system
    public var displayName: String { self == .memoment ? "꾸꾸" : "기본" }
}

public enum LabelTextStyle: String, Sendable, CaseIterable, Codable {
    case plain   // 검정 글자, 배경 없음
    case boxed   // 흰 글자 + 검정 라운드 배경
    public var displayName: String { self == .plain ? "검정 글자" : "흰 글자 + 검정 배경" }
}
```

### 좌표 설계 (핵심 결정)
라벨 위치는 **출력 캔버스 전체가 아니라 "그 클립의 화면상 이미지 사각형(placedRect)" 기준 정규화**한다.

- 이유: (a) 에디터는 클립 썸네일만 있으면 됨(전체 `renderSize` 불필요), (b) 레터박스가 생겨도 라벨이 사진에 붙어 따라다님, (c) 에디터와 합성 결과가 WYSIWYG로 일치.
- `position`의 `y`는 **스크린 방향(위=0, 아래=1)**으로 저장(드래그/에디터와 직관 일치). 합성 시 CoreAnimation y-up으로 변환.
- 글자 크기 단위 = **클립 이미지 높이에 대한 비율(`sizeFraction`)**. 에디터: `fontPx = sizeFraction × 캔버스높이`. 합성: `fontPx = sizeFraction × placedRect.height`. → 사진 대비 글자 비율 보존(WYSIWYG).

## 4. EditSession 통합 — `Modules/AppCore/Sources/EditSession.swift`

회전과 대칭으로 추가:

```swift
public var labels: [Clip.ID: ClipLabel] = [:]

public func label(for id: Clip.ID) -> ClipLabel { labels[id] ?? .default }
public func setLabel(_ label: ClipLabel, for id: Clip.ID) { labels[id] = label }
```

- `init`에 `labels` 파라미터 추가(기본 `[:]`).
- `replace(clips:title:)`와 `clear()`에서 `labels = [:]`도 함께 리셋(회전과 동일).

## 5. 에디터 UI — `Modules/TimelineFeature/Sources/LabelEditorView.swift` (신규)

### 진입점
- `EditToolbar`에 **`라벨`** 항목 추가(순서: 회전 · **라벨** · 삭제 · 저장). `onLabel: () -> Void` 클로저 + 현재 클립에 라벨 있으면 coral dot 인디케이터(`labelActive`).
- `TimelineView`가 `@State private var isLabelEditorPresented`로 `.fullScreenCover` 제어. 탭 시 현재 클립 id 기억 → 에디터에 클립 + `session.label(for:)` 초기값 전달.
- **TCA Path/AppRouter는 수정하지 않음**(모달 에디터, back-stack 의미 없음 → 외과적 변경).

### 구성
- **상단바**: `✕`(취소) / `저장`. 저장 시 편집한 `ClipLabel`을 `session.setLabel(_:for:)` 커밋 후 닫기.
- **캔버스**: `clip.thumbnailView()`를 클립 표시 비율(회전 반영, 기존 `RotatableContent` 재사용 가능)대로 박스에 배치. 그 위에 라벨 `Text`를 오버레이.
  - 캔버스 박스 크기 = 클립의 display 비율(`clip.displaySize` 회전 반영, 없으면 썸네일 비율/기본값)로 결정 → 합성 `placedRect`와 동일 비율.
  - 라벨 `Text`는 `DragGesture`로 이동. 드래그 종료/중 위치를 캔버스 기준 정규화(0...1)로 환산하고 클램프하여 `position`에 반영.
  - 글자 크기 = `sizeFraction × 캔버스높이`. 폰트: `.memoment` → `ChalNaTypography.memoment(px)`, `.system` → `ChalNaTypography.krBody(px, weight:.semibold)`(또는 적정 weight). 스타일: `.plain` → 검정 글자, `.boxed` → 흰 글자 + 검정 라운드 배경(패딩).
- **컨트롤(하단)**:
  - 텍스트 입력 `TextField`(라벨 문구).
  - 폰트 토글(꾸꾸/기본).
  - 스타일 토글(검정 글자 / 흰 글자+검정 배경).
  - 크기 `Slider`(`sizeFraction`, 0.04...0.25).
- 스페이싱/패딩은 리터럴 숫자, 색/타이포/라디우스는 토큰 사용(프로젝트 규칙).

## 6. 영상 합성(burn-in) — `Modules/CompositionService/Sources/CompositionService.swift`

### 시그니처/스레딩
- 프로토콜 `CompositionServicing.export`와 actor `export`/`run`/`buildComposition`에 `clipLabels: [Clip.ID: ClipLabel]` 파라미터 추가. 기존 편의 오버로드(`export(clips:)` 등)는 `clipLabels: [:]` 기본으로 유지(하위 호환).
- `layerInstructions` 누적 튜플을 `(timeRange, transform, capturedAt, clipID, placedRect)`로 확장.
  - `placedRect`: 기존 `transform()`의 fit-scale·center 계산을 재사용하는 **순수 헬퍼** `placedRect(naturalSize:preferredTransform:rotation:renderSize:) -> CGRect`로 산출. (가운데 정렬이라 y-up/y-down 무관)
  - 중복 계산 최소화를 위해 `transform()`와 공유하는 내부 fit 계산 헬퍼를 추출하거나, `placedRect`를 별도 순수 함수로 두고 `buildComposition`에서 호출.

### 커스텀 라벨 렌더링
- `makeDateLabelAnimationTool`에 `entries`(확장된 튜플)와 `clipLabels`를 넘김. 기존 시간/날짜 라벨을 그린 **뒤**, 각 entry의 `clipID`로 `clipLabels[id]`를 조회해 `isVisible`이면 커스텀 레이어 추가.
- **위치**: 순수 헬퍼
  ```swift
  static func customLabelOrigin(placedRect: CGRect, position: CGPoint, textSize: CGSize, renderSize: CGSize) -> CGPoint
  ```
  - 라벨 중심(top-down) = `placedRect.origin + (position.x, position.y) * placedRect.size`.
  - y-up 변환: `centerY_up = renderSize.height - centerY_topdown`.
  - 좌하단 origin = `(centerX - textSize.w/2, centerY_up - textSize.h/2)`.
- **폰트**: `overlayCustomUIFont(font: LabelFont, size:) -> UIFont`.
  - `.memoment` → "MemomentKkukkukk" family 런타임 탐색(첫 호출 1회 진단 print, KERISKEDU 패턴), 실패 시 시스템.
  - `.system` → `.systemFont(ofSize:weight:.semibold)`.
- **스타일**:
  - `.plain`: 검정 글자(`UIColor.black`), 배경/그림자 없음.
  - `.boxed`: 흰 글자 + 검정 라운드 배경 레이어(텍스트 + 패딩 크기). 배경 레이어와 텍스트 레이어 모두 동일 `timeRange` opacity 애니메이션 적용.
- 글자 크기: `fontPx = clamp(sizeFraction) × placedRect.height`.
- 표시 조건 가드: `hasContent && (labelSettings.* || clipLabels에 visible 라벨 존재)`일 때 `animationTool` 생성.

## 7. 폰트 등록 — `Project.swift`

```swift
"UIAppFonts": [
    "KERISKEDU_Line.otf",
    "MemomentKkukkukk.ttf",   // 추가
],
```
- ttf는 이미 `ChalNa/Resources/Fonts/MEMOMENT/`에 있고 `buildableFolders: ["ChalNa/Resources", ...]`로 번들됨.
- 변경 후 **`tuist generate`** 필수.

## 8. Export 배선 (회전과 동일하게 `clipLabels` 추가)

- `Modules/CompositionService/Sources/CompositionClient.swift`:
  `export: @Sendable ([Clip], [Clip.ID: ClipRotation], LabelSettings, [Clip.ID: ClipLabel]) -> AsyncStream<ExportEvent>`. liveValue/closure에 인자 추가.
- `Modules/ExportFeature/Sources/ExportFeature.swift`:
  - `Action.startExport(clips:rotations:clipLabels:)`, `Action.retryTapped(clips:rotations:clipLabels:)`에 `clipLabels` 추가.
  - reducer에서 `compositionClient.export(clips, rotations, labelSettings, clipLabels)` 호출.
- `Modules/ExportFeature/Sources/ExportView.swift`:
  - `.onAppear`/retry/failed 재시도에서 `clipLabels: session.labels` 전달.

## 9. DesignSystem 소품

- `Modules/DesignSystem/Sources/Icons/ChalNaIcon.swift`: `ChalNaIconKind`에 `.textLabel` 추가, `.rotate`처럼 `Image(systemName: "textformat")` 렌더(LucideShape 분기에서 제외).
- `Modules/DesignSystem/Sources/Tokens/ChalNaTypography.swift`: `memoment(_ size:weight:) -> Font` + `memomentFontName` 런타임 탐색(`keris()`와 동일 패턴, family에 "Memoment" 포함 검색).

## 10. 테스트 (Swift Testing)

- `Modules/Models/Tests/ClipLabelTests.swift`: 기본값, `isVisible`(빈/공백/내용), enum displayName.
- `AppCoreTests`(기존 타겟): `EditSession.label(for:)`/`setLabel`/`replace`·`clear` 리셋.
- `Modules/CompositionService/Tests/CustomLabelLayoutTests.swift`: `placedRect(...)`와 `customLabelOrigin(...)` 순수 함수 좌표 검증(기존 `LabelStackTests`/`CompositionTransformTests` 스타일, 알려진 입력→기대 좌표).

## 11. 변경/신규 파일 요약

**신규**
- `Modules/Models/Sources/ClipLabel.swift`
- `Modules/TimelineFeature/Sources/LabelEditorView.swift`
- `Modules/Models/Tests/ClipLabelTests.swift`
- `Modules/CompositionService/Tests/CustomLabelLayoutTests.swift`

**변경**
- `Modules/AppCore/Sources/EditSession.swift`
- `Modules/CompositionService/Sources/CompositionClient.swift`
- `Modules/CompositionService/Sources/CompositionService.swift`
- `Modules/ExportFeature/Sources/ExportFeature.swift`
- `Modules/ExportFeature/Sources/ExportView.swift`
- `Modules/TimelineFeature/Sources/TimelineView.swift`
- `Modules/TimelineFeature/Sources/Components/EditToolbar.swift`
- `Modules/DesignSystem/Sources/Icons/ChalNaIcon.swift`
- `Modules/DesignSystem/Sources/Tokens/ChalNaTypography.swift`
- `Project.swift` (+ `tuist generate`)
- 기존 `AppCoreTests`에 EditSession 라벨 케이스 추가

## 12. 기본값

폰트 `꾸꾸(memoment)`, 스타일 `검정 글자(plain)`, 크기 `0.10`, 위치 정중앙 `(0.5, 0.5)`.

## 13. 검증 기준 (성공 조건)

1. `tuist generate` 후 `ChalNa`/`ChalNa Dev` 두 스킴 빌드 성공.
2. 신규/변경 단위 테스트 통과(`ClipLabelTests`, `CustomLabelLayoutTests`, EditSession 라벨 케이스).
3. `ChalNa Dev`(devMock)에서: 클립 탭 → 에디터 진입 → 텍스트 입력·폰트/스타일 전환·크기 슬라이더·드래그 위치 이동 → 저장 → 타임라인 복귀 후 라벨 인디케이터 표시.
4. 실제 export 결과 mp4에서 각 클립 구간에 라벨이 **에디터에서 본 위치/크기/스타일대로** burn-in 되고, 자동 시간/날짜 라벨과 공존.
5. Memoment 폰트가 영상에 적용됨(매칭 실패 시 시스템 폰트로 graceful fallback, 크래시 없음).

## 14. 리스크/주의

- **`.plain`(검정 글자) 가독성**: 어두운 사진 위에선 잘 안 보일 수 있음 — 요청대로 배경/그림자 없이 충실히 구현(인지된 트레이드오프).
- **Memoment PostScript 이름이 EUC 인코딩**(`...-KSCpc-EUC-H`) — 하드코딩 금지, family 런타임 탐색 + fallback으로 안전 처리. 첫 호출 진단 print로 실제 등록명 확인.
- **에디터 미리보기 ↔ 합성 폰트 렌더 경로 차이**(SwiftUI Text vs CATextLayer): 동일 family + 동일 비율 크기로 근사 WYSIWYG. 완전 픽셀 일치는 보장 아님.
- **렌더 비율 가정**: 에디터 캔버스 비율 = 합성 `placedRect` 비율이어야 위치가 일치 → 캔버스를 클립 display 비율(회전 반영)로 강제.
