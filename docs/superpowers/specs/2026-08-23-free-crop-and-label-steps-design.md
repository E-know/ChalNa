# 크롭 제약 제거 + 라벨 2스텝 플로우 — 설계 문서

작성일: 2026-08-23
기준 커밋: `683375f` (feature/picturemove, 워킹트리 클린)

## 1. 배경과 요구

두 가지 편집 UX 변경 요구가 들어왔다. 둘은 서로 독립이지만 같은 편집 세션 경험에 속한다.

1. **크롭 제약 제거** — 사진 편집 시 9:16 출력 비율은 유지하되, 확대·축소·이동에 걸린 제약을 없앤다.
2. **라벨 입력 순서 변경** — `[문구 입력]` → `[위치 · 배경 ON/OFF · 크기 결정]` 2단계로 재구성한다.

### 1.1 확정된 결정 (사용자 선택)

| 항목 | 결정 |
|---|---|
| 크롭 제약 범위 | **완전 자유.** scale 하한·상한·offset clamp 전부 해제. 실용 안전 가드(0.1~10배, non-finite 방어)만 남긴다 |
| 여백 처리 | **검정** |
| 라벨 UI 구조 | **한 화면 2스텝.** 같은 `fullScreenCover` 안에서 하단 컨트롤만 스텝별로 교체 |
| 배경 OFF 스타일 | **흰 글자만.** 그림자·테두리 등 장식 없음 |
| 재편집 진입 | **항상 문구 스텝부터** |

## 2. 현재 구조 (조사 결과)

### 2.1 크롭 기하

`ClipFraming`(Models)이 프리뷰 · 조정 화면 · export 3경로의 **단일 진실원천(SSOT)** 이다.

```
ClipFraming.resolvedRect  소비자 3곳
  ├─ TimelineFeature/ClipAdjustView.swift:76      (조정 화면)
  ├─ TimelineFeature/LabelEditorView.swift:124    (라벨 에디터 캔버스)
  └─ TimelineFeature/Components/PreviewPanel.swift:53  (타임라인 프리뷰)

clamp 직접 호출
  ├─ TimelineFeature/ClipAdjustView.swift:183/226/249  (재클램프·러버밴드 한계·커밋)
  └─ CompositionService/CompositionService.swift:554/565 (export affine 산출)
```

제약을 `ClipFraming` 한 곳에서 걷어내면 세 경로가 자동으로 같이 풀린다.

### 2.2 여백이 이미 검정인 이유

`ChalNaVideoCompositor.startRequest`(`ChalNaVideoCompositor.swift:83-85`)가 이미 **불투명 검정 베이스
위에 전경을 합성**한다.

```swift
let base = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 1)).cropped(to: renderRect)
let foreground = placeYDown(src, instruction.foreground).cropped(to: renderRect)
var output = foreground.composited(over: base).cropped(to: renderRect)
```

원래는 "서브픽셀 경계 틈 대비"용이었으나, 전경이 캔버스를 못 덮게 되면 그대로 여백 배경이 된다.
따라서 **컴포지터 코드 수정은 0줄**이고 doc 주석만 정정한다. 프리뷰 쪽도 `ChalNaColor.canvas`
(= `Color.black`)라 WYSIWYG가 자동으로 맞는다.

### 2.3 박스 자막은 캔버스 고정이다

`makeCustomLabelLayers`는 `placedRect: CGRect(origin: .zero, size: renderSize)`로만 호출된다
(`CompositionService.swift:346`). 즉 `ClipLabel.position`은 **클립이 아니라 캔버스 기준**이다.
크롭이 자유로워져도 라벨 위치는 영향받지 않는다. (`placedRect` 파라미터는 과거의 일반화 잔재다.)

### 2.4 라벨 에디터 현재 상태 머신

`LabelEditorView`의 `Phase`: `.idle` ↔ `.editing` ↔ `.adjusting`. 탭=입력, 드래그=이동으로
두 모드가 한 화면에서 오간다. 크기 슬라이더는 항상 하단에 있고 `.editing` 중엔 키보드 위로 뜬다.

### 2.5 design-lint 예외 현황 (중요한 함정)

`scripts/design-lint.sh`의 흰색/검정 하드코딩 규칙 예외 목록:

| 규칙 | 예외 파일 |
|---|---|
| 4 흰색 | `DesignSystem/Sources/Tokens/`, `CompositionService.swift`, `ClipLabelText.swift`, `ChalNaTag.swift` |
| 5 검정 | `DesignSystem/Sources/Tokens/`, `CompositionService.swift`, `ClipLabelText.swift`, **`LabelEditorView.swift`** |

`LabelEditorView.swift`는 **흰색 규칙 예외에 없다** — 과거 죽은 예외로 제거됐다. 인라인 TextField에
흰 글자 리터럴을 넣으면 규칙 4가 깨진다. §4.3에서 이를 예외 추가 없이 해결한다.

## 3. 설계 — 크롭 제약 제거

### 3.1 `Models/ClipTransform.swift`

```
minScale  1.0 → 0.1
maxScale  4.0 → 10.0
+ var sanitized: ClipTransform
```

`sanitized`는 scale을 `[minScale, maxScale]`로 clamp하고 non-finite(NaN/Inf) scale·offset을
기본값으로 되돌린다. 이 두 상수는 이제 **UX 제약이 아니라 산술 안전 가드**이며, doc 주석에
그 의도를 명시한다.

`sanitized`를 새로 두는 이유는 실재하는 비대칭을 없애기 위해서다 — 현재
`CompositionService.transform`은 scale을 clamp하지만(`:554`) `ClipFraming.resolvedRect`는
**하지 않는다**. 지금은 `EditSession`에 들어가는 값이 이미 clamp돼 있어 우연히 일치하지만,
가드가 한 곳으로 모여야 두 경로가 구조적으로 같아진다. 두 경로 모두 `sanitized`를 경유한다.

### 3.2 `Models/ClipFraming.swift`

- `maxOffsetFraction(display:rotation:render:scale:)` **삭제**
- `clampedOffset(_:display:rotation:render:scale:)` **삭제**
- `resolvedRect`는 offset을 clamp 없이 반영. 진입부에서 `transform.sanitized`를 적용
- 타입 doc의 "클립이 항상 캔버스를 꽉 덮는다 / 사용자 scale(≥1)" 서술을 자유 프레이밍으로 정정

identity 함수로 남기지 않는다 — 아무것도 안 하는 clamp는 죽은 추상이고, 호출부를 읽는 사람에게
제약이 아직 있다고 잘못 알린다.

### 3.3 `CompositionService/CompositionService.swift`

`transform(...)`(`:529`)에서 `min(max(framing.scale, ...))` 인라인 clamp와
`ClipFraming.clampedOffset` 호출을 제거하고 `framing.sanitized`를 쓴다. affine 산식 자체는 불변.
`:551` / `:564` 의 clamp 근거 주석을 자유 프레이밍 서술로 교체.

### 3.4 `CompositionService/ChalNaVideoCompositor.swift`

코드 변경 없음. 타입 doc의 "전경이 캔버스를 항상 꽉 덮으므로 배경(블러) 레이어는 없다. 만일의
경계 틈은 검정 베이스가 받친다"를 "전경이 캔버스를 덮지 않을 수 있고, 드러나는 여백은 검정
베이스가 채운다"로 정정한다. §1의 결정이 이 주석에 의존하고 있으므로 반드시 고친다.

### 3.5 `TimelineFeature/ClipAdjustView.swift`

경계가 없으면 러버밴드가 저항할 대상이 없고, 스냅백할 목표도 없고, 한계 햅틱이 발화할 순간도 없다.
따라서 관련 코드를 전부 제거한다.

| 제거 | 근거 |
|---|---|
| `@State raw` + `@State working` 2중 상태 → `@State live` 하나 | 러버밴드가 없으니 표시값 = 원시값 |
| `resolvedRectUnclamped(transform:)` | `ClipFraming.resolvedRect`와 완전 동일해진다 |
| `@State atEdge` + rigid 햅틱 | 한계가 없다 |
| `rotate()`의 회전 후 offset 재클램프 | clamp가 없으니 스테일 offset 개념이 없다 |
| `Self.snapBack` 스프링 애니메이션 (제스처 종료 경로) | 스냅백 대상이 없다. **리셋 애니메이션에는 계속 쓴다** |

유지:
- 3분할 그리드(제스처 중 표시)
- 더블탭 · `[초기화]` 버튼 → 센터 크롭 리셋 (스프링 애니메이션 포함)
- `[회전]` 버튼 + light 햅틱
- 커밋 시점: 제스처 종료(`onEnded`)에 `session.setTransform`. 제스처 중 매 프레임 `EditSession`을
  건드리지 않는 기존 패턴 유지

힌트 문구를 "드래그로 옮기고 핀치로 크기를 바꿔요. 더블탭 = 초기화"로 교체한다
(기존 문구가 "확대"만 말하는데 이제 축소도 된다).

### 3.6 고아 제거

`Models/RubberBand.swift`의 유일 소비자가 `ClipAdjustView`였다. 이 변경이 만든 고아이므로
`Modules/Models/Sources/RubberBand.swift`와 `Modules/CompositionService/Tests/RubberBandTests.swift`
(7케이스)를 삭제한다.

## 4. 설계 — 라벨 2스텝 플로우

### 4.1 `Models/ClipLabel.swift`

```swift
public var hasBackground: Bool

public init(
    text: String = "",
    sizeFraction: CGFloat = 0.10,
    position: CGPoint = CGPoint(x: 0.5, y: 0.5),
    hasBackground: Bool = true      // 기본 ON = 기존 외형 유지
)
```

기본값이 있어 기존 호출부(`SampleData`, 테스트, `EditSession`)는 전부 그대로 컴파일된다.

### 4.2 패딩은 ON/OFF 동일하게 유지한다

배경을 지울 때 패딩까지 지우면 `LabelAnchorMath.paddedBoxSize`가 바뀌고, `position`(박스 중심)
역산값이 달라져 **토글을 켜고 끌 때마다 라벨이 움직인다.** 투명 여백으로 남기면 토글이 위치를
전혀 건드리지 않는다. 합성 쪽도 동일 — `bgLayer`만 빼고 `textLayer.frame`은 그대로 둔다.

### 4.3 렌더 분기 — 2곳뿐

| | `hasBackground == true` | `false` |
|---|---|---|
| 프리뷰 `BoxSubtitleStyle` | 흰 배경 + 검정 테두리 | 배경·테두리 없음 |
| 프리뷰 글자색 | 검정 (placeholder 0.5 알파) | 흰색 (placeholder 0.5 알파) |
| 합성 `makeCustomLabelLayers` | `[bgLayer, textLayer]`, `UIColor.black` | `[textLayer]`, `UIColor.white` |

**design-lint 처리.** §2.5의 함정을 예외 추가 없이 해결한다:

- `BoxSubtitleStyle`에 `hasBackground: Bool`를 추가하고, 글자색 결정을 `ClipLabelText.swift`
  (이미 흰색·검정 양쪽 예외에 등록됨)의 헬퍼로 뽑는다:
  ```swift
  // ClipLabelText.swift
  enum ClipLabelBoxPalette {
      static func foreground(hasBackground: Bool, placeholder: Bool) -> Color
  }
  ```
- `LabelEditorView`의 인라인 TextField는 이 헬퍼를 호출한다. 결과로 **LabelEditorView에는
  흰색도 검정도 리터럴이 남지 않으므로**, 규칙 5(검정) 예외 목록에서 이 파일을 **제거**한다.
  CLAUDE.md의 "파일 단위 예외는 실제 매치가 있을 때만 등록한다 — 죽은 예외는 그 파일에 새로
  들어오는 진짜 위반을 영구히 가린다" 규칙 그대로다.
- 결과적으로 라벨 박스 스타일 상수가 `ClipLabelText.swift` 한 파일로 더 모인다 —
  기존 `ClipLabel.BoxStyle`(Models, 기하 비율) + `ClipLabelBoxPalette`(색) 구도.

### 4.4 `TimelineFeature/LabelEditorView.swift` — 상태 머신 재구성

`Phase { idle, editing, adjusting }` 3개 → `Step { text, style }` 2개 + `@State isDragging: Bool`.

| | 스텝 1 `.text` | 스텝 2 `.style` |
|---|---|---|
| NavBar | `[×] 라벨 [다음]` | `[‹] 라벨 [저장]` |
| 라벨 | 인라인 `TextField`, 가시영역(상단바~키보드) 높이 정중앙으로 플로팅 | `ClipLabelText`, 드래그로 자유 배치, 선택 프레임 상시 표시 |
| 하단 컨트롤 | 없음 (키보드가 차지) | 배경 토글 + 크기 슬라이더 |
| 배경(라벨 외) 탭 | 키보드만 내림 — 스텝 유지 | 동작 없음 |
| 라벨 탭 | TextField 재포커스 (SwiftUI 기본) | → 스텝 1 복귀 |
| 정렬 가이드 | — | `isDragging` 중에만 |

전이:
- 진입 → 항상 `.text` + `focused = true` (기존 라벨 재편집 포함). 포커스는 지금과 같은 훅
  (`reflow` 최초 확정 시점)에서 건다
- `[다음]` → `.style`, `focused = false`
- `[‹]` → `.text`, `focused = true`
- `.style`에서 라벨 탭 → `.text`, `focused = true`
  (탭과 드래그가 같은 요소에 걸리므로 기존 `DragGesture(minimumDistance: 16)`을 유지해
  구분한다 — 현재 코드가 이미 이 값으로 탭/드래그를 가르고 있다)
- `[저장]` → `onCommit(committedLabel())`
- `[×]` → `onCancel()`

제거되는 것:
- `.editing`에서 드래그로 `.adjusting`으로 넘어가는 전이 (스텝이 분리됐으므로 불필요)
- `onChange(of: focused) { → .idle }` (포커스 상실이 스텝을 바꾸면 안 된다)
- `endAdjusting()` / `startEditing()` 헬퍼는 스텝 전이로 흡수

유지되는 것 (건드리지 않는다):
- `displayCornerY`의 가시영역 중앙 플로팅 계산 — 조건만 `step == .text`로 바꾼다
- `renderedSizeFraction` 베이크 + `scaleEffect` 라이브 스케일 (슬라이더 끊김 방지)
- `reflow(from:to:)` 박스 변경 시 정규화 center 보존
- `committedLabel()` 코너→중심 역산
- 중심 스냅(eps 0.02) + 정렬 가이드
- 캔버스를 `LabelBoxGeometry.fittedBox`로 미리 재서 상단 정렬하는 기존 구조

**배경 토글 UI**: 스텝 2 하단 `safeAreaInset`에 `ChalNaListRow.toggle`을 쓰지 않는다 — 그 컴포넌트는
리스트 행 배경·구분선을 함께 들고 오므로 툴바 문맥에 안 맞는다. `Text("배경")` +
`Toggle("", isOn:).labelsHidden()`을 기존 "크기" 슬라이더와 같은 `VStack` 리듬으로 배치한다.

**빈 문구 처리**: `[다음]`은 항상 활성. 스텝 2에서 `[저장]` 시 문구가 비어 있으면 기존
`ClipLabel.isVisible == false` 규칙대로 라벨 없음으로 저장된다. 이것이 라벨을 지우는 유일한
경로이므로 `[다음]`을 비활성화하면 삭제가 불가능해진다.

### 4.5 `CompositionService/CompositionService.swift`

`makeCustomLabelLayers`:
- `foregroundColor`를 `label.hasBackground ? UIColor.black : UIColor.white`로
- 반환을 `label.hasBackground ? [bgLayer, textLayer] : [textLayer]`로 (배경 OFF면 `bgLayer` 미생성)
- 테스트 접근을 위해 `private static` → `static`(internal). `@testable import CompositionService`로
  도달한다. 같은 파일의 `customLabelOrigin`이 이미 `public`인 것과 같은 이유(테스트 가드).

## 5. 테스트 계획

### 5.1 수정·삭제

| 파일 | 변경 |
|---|---|
| `CompositionService/Tests/RubberBandTests.swift` | **삭제** (7케이스, §3.6) |
| `CompositionService/Tests/ClipFramingTests.swift` | clamp/maxOffsetFraction 7케이스 삭제, `testResolvedRect_R90_WithOffset_ShiftsWithinLimit` 기대 갱신 |
| `CompositionService/Tests/CompositionTransformTests.swift` | `testTransform_OffsetBeyondLimit_ClampsToLimit` · `testTransform_UserScaleBelowMin_ClampsToFill` 2개를 자유 동작 기대로 수정 |
| `CompositionService/Tests/PreviewExportContractTests.swift` | `testContract_Landscape_R0_OffsetClamps` · `testContract_Portrait_R90_ScaleAndOffsetClamps` 2개를 자유 offset 계약으로 수정. **프리뷰↔export 좌표 일치 검증이라는 이 파일의 목적은 그대로 유지** |
| `ChalNa/UITests/CropAdjustUITests.swift` | `testAdjustFlow_CenterCrop_RubberBand_Reset` → 러버밴드 assert를 자유 이동·축소 assert로 교체 |
| `ChalNa/UITests/LabelEditorUITests.swift` | 2스텝 플로우로 갱신 (아래 5.3) |

### 5.2 신규

**크롭 (`ClipFramingTests`)**
- `resolvedRect`가 offset을 clamp 없이 반영 — 전경이 캔버스 밖으로 나간다
- `scale < 1`이면 전경 사각형이 캔버스보다 작다 (여백 존재)
- `sanitized`: scale 0.05 → 0.1, 100 → 10, NaN/Inf offset → 기본값

**크롭 픽셀 (`CompositorLabelTests` 계열)**
- `scale 0.5`로 축소한 클립을 컴포지터에 통과시키면 캔버스 코너 픽셀이 검정 (여백 = 검정 확인)

**라벨 (`AppCore/Tests/ClipLabelTests.swift`)**
- `hasBackground` 기본값 `true`
- `hasBackground`만 다른 두 `ClipLabel`이 서로 다르다 (`Hashable` 반영)

**라벨 합성 (`CustomLabelLayoutTests`)**
- `hasBackground == true` → 레이어 2개, 텍스트 `UIColor.black`
- `hasBackground == false` → 레이어 1개, 텍스트 `UIColor.white`
- ON/OFF에서 `textLayer.frame`이 동일 (§4.2 — 토글이 위치를 안 움직인다)

**라벨 픽셀 (`CompositorLabelTests`)**
- 배경 OFF 라벨의 글자 주변 픽셀이 흰 박스가 아니라 원본 전경 그대로

### 5.3 UI 테스트 — `LabelEditorUITests`

기존 파일의 클래스 doc에 담긴 계측 정정 기록(`print`가 UI 테스트에서 무효라는 사실,
키보드 알림 실측값)은 **보존한다** — 다음 사람이 같은 함정에 빠지는 걸 막는 유일한 기록이다.

- 스텝 1: 진입 시 `TextField` 존재 + 키보드 ↑ + `[다음]`·`[×]` 도달 가능
- `[다음]` 탭 → 스텝 2: 크기 슬라이더 + 배경 토글 + `[저장]`·`[‹]` 도달 가능, 키보드 ↓
- `[‹]` 탭 → 스텝 1 복귀 + 키보드 ↑
- Dynamic Type 상한 케이스는 유지 (스텝 2 컨트롤 기준으로 갱신)

### 5.4 회귀 기준선

2026-08-23 기준 8스위트 160케이스가 그린이다. 이 변경 후 예상:
`CompositionService` 64 → 대략 57~59 (RubberBand −7, ClipFraming 순감, 신규 픽셀·라벨 케이스 +),
`AppCore` 27 → 29. **정확한 수치는 실행 후 실측해 CLAUDE.md에 기록한다** — 예측값을 문서에
박지 않는다.

전체 실행은 반드시 `ChalNa-Workspace` 스킴이다 (`-scheme ChalNa`는 유닛 8스위트를 조용히 빠뜨린다).

## 6. 문서 갱신 (CLAUDE.md)

| 위치 | 갱신 |
|---|---|
| 비디오 합성 원칙 | "클립은 aspectFill 센터 크롭이 기본(`ClipTransform.fill`, scale 하한 1.0 — 여백/블러 배경 없음)" → 기본값은 센터 크롭이되 사용자가 자유롭게 축소·이동할 수 있고 드러나는 여백은 검정임을 서술 |
| 비디오 합성 원칙 | 박스 자막 스타일이 "흰 배경 + 검정 글씨 + 검정 테두리 고정"이 아니라 `hasBackground`로 갈린다는 것 |
| 금지 사항 / 다크 토큰 적용 예외 | 규칙 5(검정) 예외에서 `LabelEditorView.swift` 제거, 이유(색 결정이 `ClipLabelText.swift`로 이동) |
| 테스트 | 8스위트 케이스 수 실측값 갱신 |
| DesignSystem 컴포넌트 표 | 변경 없음 (새 컴포넌트 없음) |

## 7. 범위 밖 (명시적으로 하지 않는 것)

- **자동 시각/날짜 라벨**(`LabelLayout`·`AutoLabelsOverlay`)은 손대지 않는다. 이 요구의 "라벨"은
  사용자 박스 자막(`ClipLabel`)이다. 자동 라벨은 설정이 없는 게 확정된 설계다
- 블러/흰색 등 다른 여백 배경 옵션 — 검정으로 확정됐고, 컴포지터에 배경 레이어를 되살리지 않는다
- 배경 OFF 시 그림자·외곽선 — "장식 없음"으로 확정. `BoxStyle`에 새 상수를 추가하지 않는다
- 라벨을 별도 TCA 라우트로 분리 — 현재 `fullScreenCover` + 로컬 `@State` 구조를 유지한다
- 크롭 화면의 회전 기능 자체 — 그대로 둔다 (회전 후 재클램프만 사라진다)
- `ClipLabel` 다중 라벨화, 폰트·색 선택 — 요구에 없다

## 8. 위험과 완화

| 위험 | 완화 |
|---|---|
| 프리뷰와 export가 어긋난다 | `ClipFraming` SSOT를 계속 유일 경로로 유지. `PreviewExportContractTests`가 두 경로 좌표 일치를 계속 검증한다 |
| 라벨 토글이 위치를 흔든다 | §4.2 패딩 유지 + `textLayer.frame` 동일성 테스트로 고정 |
| design-lint 규칙 4가 조용히 깨진다 | §4.3에서 흰색 리터럴을 이미 예외인 파일에 두고, 죽은 예외가 된 규칙 5 항목을 제거. 커밋 전 `scripts/design-lint.sh` 실행 |
| 스텝 1 진입 시 포커스가 안 잡힌다 | 기존 `reflow` 최초 확정 훅을 재사용(현재 빈 라벨에서 동작이 검증된 경로). UI 테스트가 키보드 ↑를 assert |
| 사용자가 사진을 화면 밖으로 완전히 밀어내 검은 화면이 된다 | 사용자가 "완전 자유"를 명시적으로 선택했다. 더블탭·`[초기화]`가 복구 경로다 |
