# 프롬프트 — 라벨 에디터 3개 개선 (키보드 accessory · 자동 폰트 축소 · 두 손가락 회전/크기)

> 이 문서는 Claude Code 에 그대로 붙여넣기 위한 작업 지시서다.
> 대상 브랜치: `feature/picturemove` · 대상 화면: `LabelEditorView`(문구 입력 / 위치·배경·크기 2스텝)

---

## 0. 먼저 읽을 것 (구현 전 필수)

건드릴 코드가 **프리뷰 ↔ 영상 합성 WYSIWYG 계약**에 걸려 있다. 아래 파일을 먼저 읽고, 각 값이 어디서
단일 출처(SSOT)로 유지되는지 파악한 다음 구현을 시작한다.

| 역할 | 파일 |
|---|---|
| 라벨 모델 · 박스 스타일 상수 | `Modules/Models/Sources/ClipLabel.swift` |
| 자동 시각/날짜 라벨 기하 (참고용, 수정 금지) | `Modules/Models/Sources/LabelLayout.swift` · `LabelText.swift` |
| 에디터 화면 (2스텝) | `Modules/TimelineFeature/Sources/LabelEditorView.swift` |
| 화면 렌더 (프리뷰·에디터 공용) | `Modules/TimelineFeature/Sources/Components/ClipLabelText.swift` |
| 배치 기하 (코너↔중심 변환·박스 실측) | `Modules/TimelineFeature/Sources/Components/LabelAnchorMath.swift` |
| 키보드 높이 관찰 | `Modules/TimelineFeature/Sources/Components/KeyboardObserver.swift` |
| 타임라인 프리뷰 소비자 | `Modules/TimelineFeature/Sources/Components/PreviewPanel.swift` (라벨 오버레이 부분) |
| 에디터 호출부 (fullScreenCover) | `Modules/TimelineFeature/Sources/TimelineView.swift` (약 86행) |
| 영상 합성 | `Modules/CompositionService/Sources/CompositionService.swift` — `makeCustomLabelLayers` · `customLabelOrigin` · `measureCustomText` · `overlayCustomUIFont` · `stampBounds` · `renderLabelOverlayImage` · `OverlayKey` |
| 세션 저장 | `Modules/AppCore/Sources/EditSession.swift` (`labels`) |
| 기존 테스트 | `Modules/CompositionService/Tests/CustomLabelLayoutTests.swift` · `Modules/TimelineFeature/Tests/LabelAnchorMathTests.swift` · `Modules/AppCore/Tests/ClipLabelTests.swift` · `ChalNa/UITests/LabelEditorUITests.swift` |

**핵심 사실 3개 (이걸 어기면 출력 영상과 화면이 어긋난다)**

1. 같은 텍스트 실측 코드가 지금 **3곳에 복제**돼 있다 — `LabelAnchorMath.textSize`,
   `ClipLabelText.measuredSize`, `CompositionService.measureCustomText`. 셋 다 `UIFont.systemFont(weight: .light)`
   + `ClipLabel.BoxStyle.letterSpacing` + `ceil` 로 동일하다. 한쪽만 고치면 컴파일·테스트가 **조용히 통과**한다.
2. `CompositionService` 는 `DesignSystem`·`TimelineFeature` 를 볼 수 없다. 합성과 프리뷰가 공유할 수 있는
   유일한 모듈은 **`Models`** 다 (`LabelText`·`LabelLayout` 이 이미 그 이유로 Models 에 있다).
3. 저장 모델 `ClipLabel.position` 은 **박스 중심**의 정규화 좌표(0…1)이고, 에디터는 내부적으로 **좌상단
   코너**(`anchorCorner`)를 단일 출처로 쓰며 커밋 시 중심을 역산한다.

---

## 1. 절대 지켜야 할 프로젝트 규약

- **Swift 6 / iOS 18 / SwiftUI 전용.** UIKit 은 불가피한 래핑만.
- **Swift Testing**(`import Testing`/`@Test`/`#expect`). XCTest 는 `ChalNaUITests` 타겟만 예외.
- **GCD 금지**(`DispatchQueue` 등) · **`ObservableObject`/`@Published` 금지**. `@Observable` + `async/await`.
- **spacing/padding 만 리터럴 숫자**, 색·타이포·라디우스·모션은 `ChalNaColor`/`ChalNaTypography`/`ChalNaRadius`/`ChalNaMotion` 토큰.
- **`scripts/design-lint.sh` 를 커밋 전에 실행하고 6개 규칙 전부 0건을 유지한다.**
  - 라벨 박스는 합성 픽셀과 일치해야 해서 `.font(.system(size:))` 를 직접 쓰는 **파일 단위 예외**가
    `ClipLabelText.swift`·`LabelEditorView.swift` 에 이미 걸려 있다. 색 리터럴은 `ClipLabelBoxPalette`
    (ClipLabelText.swift) 한곳에만 두고 다른 파일은 그 헬퍼를 호출한다.
  - **새 파일을 예외 목록에 추가하는 것은 최후 수단**이고, 그 파일에 실제 매치가 있을 때만 등록한다
    (매치 없는 "죽은 예외"는 나중에 들어올 진짜 위반을 영구히 가린다).
- 한국어 주석 OK, 식별자는 영어, 한 파일 = 한 타입.
- 사용자 노출 문자열은 한국어. `LocalizedStringKey` 는 카탈로그 항목이 없으면 한국어 키를 그대로 렌더링하므로,
  새 문자열을 추가하면 `-AppleLanguages "(en)"` 로 한 번은 실행해 확인한다.
- iOS 빌드·시뮬레이터 실행은 `ios-build-run` 서브에이전트에 위임한다.
- **devMock 픽스처는 시각 검증 채널이 아니다.** dev fixture 4개는 360×640(9:16)로 출력 캔버스와 종횡비가
  정확히 같아 크롭·배치 변화를 관측할 수 없다. UI 테스트는 **도달성·무크래시 스모크**로만 취급하고,
  실제 기하 가드는 유닛 테스트가 담당한다.

---

## 2. 작업 순서와 진행 방식

1. **구현 전에 3개 작업의 순서 · 각 단계의 검증 방법 · 깨질 것으로 예상되는 기존 테스트 목록을 먼저 제시**하고
   내 확인을 받는다.
2. 권장 순서는 **작업 1 → 작업 2 → 작업 3**이다. 작업 1은 다른 둘과 독립적이라 검증 루프가 가장 짧고,
   작업 2가 측정 SSOT 를 Models 로 정리해두면 작업 3의 회전 기하가 한 곳에서 끝난다.
3. 각 작업은 **실패하는 테스트를 먼저 쓴 뒤** 통과시킨다(TDD).
4. 작업 단위로 커밋한다. 커밋 메시지는 한국어, 변경 파일 요약 포함.
5. 각 작업이 끝나면 **테스트를 실제로 실행한 출력**과 함께 결과를 보고한다. 실행하지 않은 채 "통과"라고
   쓰지 않는다.

---

## 작업 1 — 키보드 위 `다음` 버튼 + 키보드 하강 시 자동 스텝 전환

### 요구사항
- 문구 입력 스텝(`Step.text`)의 `[다음]` 버튼을 **키보드 바로 위(keyboard accessory)** 에 띄운다.
- 사용자가 키보드를 내리면(리턴/바깥 탭 등) **자동으로 위치·배경·크기 스텝(`Step.style`)으로 넘어간다.**

### 결정된 정책
- `[다음]` 은 **키보드 accessory 로 이동**하고, `.text` 스텝의 `ChalNaNavBar` trailing 은 비운다
  (leading 의 `[닫기]` 는 유지). `.style` 스텝의 `[‹]`/`[저장]` 은 그대로.
- 버튼 문자열은 **`"다음"` 그대로 유지**한다 — `LabelEditorUITests` 가 `app.buttons["다음"]` 으로 찾는다.
- 자동 전환은 "키보드가 내려갔다"는 **사실 하나만** 트리거로 쓴다. 즉 `.text` 스텝에서 키보드 높이가
  0 이 되면 `.style` 로 넘어간다.

### 구현 지침
- SwiftUI `.toolbar { ToolbarItemGroup(placement: .keyboard) { ... } }` 를 우선 시도한다. 동작하지 않으면
  `UIViewRepresentable` 로 `inputAccessoryView` 를 붙이되, 그 경우 **왜 SwiftUI 경로가 안 됐는지 근거를 남긴다.**
- 키보드 하강 감지는 이미 있는 `KeyboardObserver`(`height`/`topY`)를 재사용한다. 새 관찰자를 만들지 않는다.
- 액세서리 바 스타일은 기존 토큰으로만 구성한다(`ChalNaColor.surfaceRaised`/`border`, `ChalNaTypography.*`).
  새 DesignSystem 컴포넌트를 만들 필요가 있다고 판단되면 먼저 물어본다.

### 함정 (반드시 처리)
1. **자동 전환의 이중 발화.** `goToStyle()` 이 `focused = false` 로 키보드를 내리므로, 키보드 하강을 그대로
   트리거로 쓰면 `[다음]` 탭 → 전환 → 키보드 하강 → 다시 전환 시도가 된다. `step == .text` 일 때만
   전환하는 가드가 필요하다.
2. **커밋/취소 시 오작동.** `onCommit`/`onCancel` 로 화면이 닫힐 때도 키보드가 내려간다. 화면이 사라지는
   중에 스텝을 바꾸지 않도록 한다.
3. **`[‹]` 로 문구 스텝에 되돌아왔을 때.** `goToText()` 가 `focused = true` 를 걸어 키보드가 다시 올라오는데,
   그 사이 한 프레임이라도 `height == 0` 으로 읽히면 즉시 `.style` 로 튕겨 나간다. 되돌아가기가 실제로
   동작하는지 확인한다.
4. **본문 레이아웃.** body 에 `.ignoresSafeArea(.keyboard, edges: .bottom)` 이 걸려 있고 하단 컨트롤은
   `.safeAreaInset(edge: .bottom)` 이다. accessory 추가로 캔버스가 줄어들거나 라벨 플로팅
   (`displayCornerY`, `keyboard.height > 0` 조건)이 깨지지 않아야 한다.
5. `backgroundTapped()` 의 현재 의미("`.text` 에서는 키보드만 내린다")가 바뀐다 — 그 함수의 doc 주석과
   `LabelEditorView` 헤더의 2스텝 플로우 설명을 함께 정정한다.

### 검증
- `ChalNa/UITests/LabelEditorUITests.swift` 의 `testLabelEditor_TwoStepFlow_ControlsReachable` 을 갱신한다:
  키보드가 올라온 상태에서 `다음` 이 `exists && isHittable`, 탭 후 슬라이더·배경 토글 도달.
- **새 UI 테스트 1개 추가** — 문구 입력 후 키보드를 내렸을 때(`[다음]` 을 누르지 않고) `.style` 스텝
  컨트롤(슬라이더)이 나타나는지. 도달성 assert 만 쓴다.
- `testLabelEditor_DynamicTypeAccessibility5_CapsAtAccessibility1` 이 `app.buttons["다음"]` 을 눌러
  스텝 2로 넘어가므로, 버튼 위치 변경 후에도 이 테스트가 통과해야 한다.

---

## 작업 2 — 문구가 길어지면 폰트 자동 축소 (사진 좌우 여백 안쪽으로)

### 요구사항
- 문구가 길어져도 라벨 박스의 leading/trailing 이 **사진(캔버스)의 leading/trailing 안쪽**에 머물도록
  폰트 크기를 자동으로 줄인다.

### 결정된 정책
- **좌우 여백 = 캔버스 폭의 4%** (양쪽 각각). `LabelLayout.paddingFraction`(0.04) 을 재사용한다 —
  자동 시각/날짜 라벨이 쓰는 값과 같아서 화면 전체에서 라벨 여백이 일관된다.
  1080 기준 가용폭 = `1080 × 0.92 ≈ 993.6px`.
- **판정 대상은 패딩 포함 박스 폭**(`paddedBoxSize`)이다. 배경 OFF 여도 패딩은 동일하게 유지되므로
  ON/OFF 에서 축소 결과가 같아야 한다.
- **`ClipLabel.sizeFraction` 은 사용자 의도로 그대로 저장하고 덮어쓰지 않는다.** 실제 렌더 폰트는
  `min(사용자 의도, 맞춤 크기)` 로 **파생**한다. 이유: 슬라이더 값이 제멋대로 튀지 않고, 문구를 짧게
  고치면 원래 크기로 복귀한다.
- **하한 8px.** 합성의 기존 `max(8, ...)` 과 정합을 맞춘다. 가용폭에 맞추기 위해 8px 아래로는 내리지 않고,
  그 경우엔 넘침을 허용한다(초장문 방어).
- **세로(높이) 맞춤은 이번 범위가 아니다.** 여전히 1줄(`lineLimit(1)`)이고 멀티라인을 도입하지 않는다.

### 구현 지침
- **새 SSOT 를 `Models` 에 둔다.** 예: `Modules/Models/Sources/ClipLabelMetrics.swift`
  (또는 `ClipLabel` 의 extension). 최소한 아래 셋을 이 한곳에서 제공한다.
  - 텍스트 실측 (`text`, `fontPx` → `CGSize`) — 지금 3곳에 복제된 그 로직
  - 패딩 포함 박스 실측
  - **맞춤 폰트 계산** (`text`, 캔버스 크기, 사용자 `sizeFraction` → 실제 fontPx)
- **기존 3곳의 복제 측정 코드를 이 SSOT 호출로 교체한다.** 교체하지 않으면 축소 규칙이 또 3곳에 복제된다.
  - `LabelAnchorMath.textSize` / `paddedBoxSize`
  - `ClipLabelText.measuredSize`
  - `CompositionService.measureCustomText` (+ `overlayCustomUIFont` 도 함께 옮길지 판단)
- 맞춤 계산은 **결정론적**이어야 한다 (합성·프리뷰·에디터가 같은 입력에 같은 fontPx 를 낸다).
  패딩·자간이 fontPx 비례라 대체로 선형이지만 `ceil` 반올림과 kern 때문에 완전 선형은 아니다 —
  1차 스케일 추정 후 만족할 때까지 좁히는 방식(이분 탐색 등)을 쓰고, 부동소수 반복으로 결과가 흔들리지
  않게 고정한다.
- 반영해야 하는 소비자 **3곳 전부**:
  - 합성 `makeCustomLabelLayers` (fontSize 산출)
  - 프리뷰/에디터 렌더 `ClipLabelText`
  - 에디터 배치 — `anchorCorner` 초기화(`reflow`), 드래그 clamp(`applyDrag`), 커밋 역산(`committedLabel`),
    슬라이더 베이크(`renderedSizeFraction` / `liveScale`)
- 에디터의 인라인 TextField(`inlineEditor`)도 같은 맞춤 폰트를 써야 한다 — 입력 중에 글자가 커졌다가
  `[다음]` 을 누르면 갑자기 작아지는 불연속이 생기면 안 된다.

### 함정
- `stampBounds`(오버레이 비트맵 크롭)는 레이어 frame 을 그대로 읽으므로 축소는 자동으로 따라간다.
  별도 조치가 필요 없다는 것을 테스트로 확인만 한다.
- 축소가 걸린 상태에서 `sizeFraction` 슬라이더를 움직이면 화면상 변화가 없을 수 있다(이미 상한). 그게
  의도된 동작이지만, 슬라이더가 "먹지 않는" 것처럼 보이는 게 문제라고 판단되면 나에게 물어본다 —
  임의로 슬라이더 범위를 동적으로 바꾸지 말 것.
- `AutoLabelsOverlay`(자동 시각/날짜)와 `LabelLayout` 은 **건드리지 않는다.** 상수만 재사용한다.

### 검증 (Swift Testing 신규)
- 긴 문구가 가용폭(캔버스 폭 × 0.92) 이내에 들어온다.
- 짧은 문구는 축소가 일어나지 않고 `sizeFraction` 그대로 렌더된다.
- 배경 ON/OFF 에서 축소 결과 fontPx 가 동일하다.
- 하한 8px 이 지켜진다(가용폭을 못 맞추더라도).
- **합성과 프리뷰가 같은 fontPx 를 산출한다** (같은 SSOT 함수를 부르는 계약 테스트 — 기존
  `PreviewExportContractTests` 패턴 참고).
- 축소가 걸려도 저장 `ClipLabel.sizeFraction` 은 변하지 않는다.
- 기존 테스트 영향 확인: `LabelAnchorMathTests`, `CustomLabelLayoutTests`,
  `AutoLabelsOverlayFidelityTests`, `PreviewExportContractTests`.

---

## 작업 3 — `.style` 스텝에서 두 손가락 드래그로 기울기(회전) + 크기 조절

### 요구사항
- 위치·배경·크기 스텝에서 **두 손가락 제스처로 라벨의 회전과 크기를 동시에** 조절할 수 있게 한다.

### 결정된 정책
- **핀치 확대/축소는 라벨 중심을 고정한다** (`ClipLabel.position` 불변).
  - 현재 명세는 "좌상단 코너 고정 · 우하 확장"(`LabelAnchorMath` 헤더,
    `LabelAnchorMathTests.testSizeGrows_TopLeadingCornerFixed_ExpandsRightAndDown`)이다.
    **핀치와 크기 슬라이더를 모두 중심 고정으로 통일**하고, 그 기존 테스트와 관련 doc 주석
    (`LabelAnchorMath` 헤더 · `LabelEditorView` 헤더 · `ClipLabel.hasBackground` doc)을 정정한다.
  - 부수 효과를 정정 문서에 반영할 것: 배경 ON/OFF 토글 시 라벨이 안 움직이는 이유가 지금은
    "코너 고정 + 패딩 동일" 인데, 중심 고정으로 바뀌면 패딩이 달라져도 중심이 유지되므로 근거가 바뀐다.
    **패딩을 ON/OFF 동일하게 유지하는 것 자체는 합성 정합상 그대로 둔다.**
- **회전은 −180°…180° 자유 회전 + 0° 스냅(±3°).** 기존 위치 드래그의 중심 스냅(`eps 0.02`)과 같은 패턴이다.
- **회전은 출력 영상에 반영한다** (WYSIWYG). 프리뷰 전용이 아니다.
- **자동 축소(작업 2)는 회전 전(unrotated) 박스 폭 기준으로 계산한다.** 회전된 바운딩 박스가 캔버스를
  넘는 것은 허용한다 — 사용자가 의도적으로 기울인 결과이고, 회전할 때마다 폰트가 흔들리는 것이 더 나쁘다.
- 크기 슬라이더는 **유지**한다(미세 조정용). 핀치와 슬라이더는 같은 `sizeFraction` 을 공유하고 서로 동기화된다.

### 구현 지침
- **모델**: `ClipLabel` 에 회전 필드 추가(예: `rotationRadians: CGFloat = 0`). 단위·부호 규약을 doc 주석에
  명시한다(시계방향 +). `Hashable` 이므로 `OverlayKey` 오버레이 캐시 키에 자동 반영된다 — 이걸 확인만 한다.
  `init` 기본값을 주어 기존 호출부가 깨지지 않게 한다.
- **제스처**: iOS 18 이므로 `MagnifyGesture` / `RotateGesture` (구 `MagnificationGesture`/`RotationGesture` 아님).
  `MagnifyGesture().simultaneously(with: RotateGesture())` 형태로 동시 인식하고, 기존
  `DragGesture(minimumDistance: 16)`(위치)·`onTapGesture`(문구 스텝 복귀)와 충돌하지 않게 우선순위를 정한다.
  제스처 종료 시 `renderedSizeFraction` 베이크(선명 재렌더) 로직을 슬라이더와 동일하게 적용한다.
- **합성**(`makeCustomLabelLayers`): 배경 레이어와 텍스트 레이어를 **컨테이너 `CALayer` 하나에 담고 컨테이너를
  회전**시키는 방식을 권장한다(두 레이어를 각각 회전시키는 것보다 어긋날 여지가 적다).
- **프리뷰**: 회전을 `ClipLabelText` 내부에 넣어 에디터와 `PreviewPanel` 이 자동으로 같은 규칙을 쓰게 한다
  (호출부마다 `.rotationEffect` 를 붙이면 또 복제가 된다).

### 함정 (전부 명시적으로 처리하고 결과를 보고할 것)
1. **`layer.frame` 대입 순서.** 비항등 `transform` 이 걸린 상태에서 `frame` 을 대입하면 동작이 정의되지 않는다.
   frame 을 먼저 세팅하고 transform 을 나중에 넣는다.
2. **`stampBounds` 가 회전된 바운딩 박스를 포함해야 한다.** 오버레이 비트맵은 라벨이 덮는 사각형만
   렌더하므로, 회전 후 커진 영역을 반영하지 않으면 **라벨 모서리가 잘린다.** `layer.frame` 이 transform 을
   반영하는지에 의존하지 말고 회전 바운딩 박스를 명시적으로 계산한다.
3. **`isGeometryFlipped = true` 와 회전 부호.** 오버레이 부모 레이어는 `isGeometryFlipped = true` 다.
   여기에 회전이 겹치면 **시계/반시계가 뒤집힐 수 있다.** 프리뷰(`rotationEffect`, 시계방향 +)와 합성의
   부호가 실제로 일치하는지 테스트로 잠근다.
4. **컨텍스트를 translate 하지 말 것.** `renderLabelOverlayImage` 는 서브렉트를 만들 때 컨텍스트를 옮기지
   않고 레이어 frame 을 평행이동한다 — `isGeometryFlipped` 의 기준이 컨텍스트를 따라가면서 결과가 완전히
   빈 이미지가 되기 때문이다(실측). 이 규칙을 유지한다.
5. **회전 0 일 때 기존 기하와 픽셀 단위로 동일해야 한다** (회귀 없음).

### 검증
- Swift Testing:
  - `rotation == 0` 이면 기존 레이어 기하와 동일(회귀 가드).
  - 회전 시 배경 박스와 텍스트의 중심이 일치한다.
  - `stampBounds` 가 회전된 박스를 포함한다(잘림 없음).
  - 프리뷰와 합성의 회전 각도·부호가 일치한다(계약 테스트).
  - `ClipLabel` 기본값 `rotation == 0`, 동등성에 참여.
- **실제 export 프레임 픽셀 샘플링**으로 회전된 라벨이 잘리지 않는지 확인한다
  (`CompositionServiceTests/CompositorRenderTests` 의 기존 패턴을 따른다).
- UI 테스트는 도달성·무크래시 스모크만 추가한다(`pinch`/`rotate` 후 크래시 없이 컨트롤 도달). devMock 은
  시각 검증 채널이 아니므로 기하 단언을 걸지 않는다.

---

## 3. 최종 검증 (완료 보고 전 필수)

```bash
tuist generate

# 유닛 테스트 8개 스위트 (devMock UI 테스트 제외)
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa-Workspace \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           -skip-testing:ChalNaUITests test

# UI 테스트
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           -only-testing:ChalNaUITests test

# 디자인 토큰 정적 검사 — 6개 규칙 전부 0건이어야 한다
./scripts/design-lint.sh
```

- 기준선은 **8개 스위트 166 케이스 전부 그린**(2026-08-24, iPhone 17 Pro)이다. 최종 케이스 수와 증감 내역을
  보고한다.
- 시뮬레이터에서 실제로 실행해 **문구 스텝 → 키보드 내림 → 자동 전환 → 두 손가락 회전/확대 → 저장 →
  타임라인 프리뷰 → export** 까지 한 번 통과시킨다. 빌드·실행은 `ios-build-run` 에이전트에 위임한다.
- `CLAUDE.md` 의 관련 서술(라벨 2스텝 플로우 · 패딩 대칭 근거 · 박스 자막 스타일 · 테스트 케이스 수)을
  변경 내용에 맞게 갱신한다. **틀린 인과를 남기지 말 것** — 이 저장소의 문서는 "왜 그렇게 됐는지"를
  근거로 유지한다.

---

## 4. 하지 말 것 (스코프 밖)

- 자동 시각/날짜 라벨(`LabelLayout`·`LabelText`·`AutoLabelsOverlay`)의 **기하·불투명도·위치 변경 금지.**
  상수 재사용만 허용.
- 삭제된 [설정 → 라벨] 화면·`LabelSettings`/`LabelPosition`/`LabelKind` 부활 금지.
- `ClipTransform`·`ClipFraming`(크롭 기하) 변경 금지.
- 멀티라인 자막 도입 금지 (여전히 1줄).
- 새 디자인 토큰·새 DesignSystem 컴포넌트 발명 금지 — 기존 것을 재사용한다. 정말 필요하면 먼저 물어본다.
- 요청과 무관한 인접 코드 리팩터링·주석 정리·포맷 변경 금지. 내 변경이 만든 orphan(안 쓰이는 import/함수)만
  정리한다.

---

## 5. 막히면 물어볼 것

아래는 임의로 결정하지 말고 물어본다.

- 자동 축소가 걸려 크기 슬라이더가 "안 먹는 것처럼" 보이는 UX 를 바꿔야 한다고 판단될 때.
- 핀치를 중심 고정으로 통일하면서 기존 테스트/문서 정정 범위가 라벨 밖으로 번질 때.
- 회전 반영을 위해 `ClipLabel` 외의 저장 구조(`EditSession`·`Film` 등)를 바꿔야 할 때.
- `.sheet`/`.fullScreenCover` 를 새로 추가해야 할 때 (Dynamic Type 상한을 그 안에서 다시 걸어야 한다).
