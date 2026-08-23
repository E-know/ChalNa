# 크롭 제약 제거 + 라벨 2스텝 플로우 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 사진 크롭의 확대·축소·이동 제약을 제거하고(9:16 출력 비율은 유지, 여백은 검정), 라벨 편집을 `[문구 입력] → [위치·배경·크기]` 2스텝으로 재구성한다.

**Architecture:** 크롭 기하는 `ClipFraming`(Models) 하나가 프리뷰·조정 화면·export 3경로의 SSOT라, 여기서 clamp를 걷어내면 세 경로가 같이 풀린다. `ChalNaVideoCompositor`는 이미 검정 베이스 위에 전경을 합성하므로 여백 처리에 코드 변경이 없다. 라벨은 `ClipLabel`에 `hasBackground`를 추가하고 프리뷰(`ClipLabelText`)·합성(`makeCustomLabelLayers`) 두 렌더 경로를 분기하며, `LabelEditorView`의 3-phase 상태 머신을 2-step으로 줄인다.

**Tech Stack:** Swift 6.0+ / iOS 18+ · SwiftUI · TCA · Swift Testing(유닛) · XCTest(UI 테스트만) · Tuist

**Spec:** `docs/superpowers/specs/2026-08-23-free-crop-and-label-steps-design.md`

## Global Constraints

- **Swift 6.0+, iOS 18+.** SwiftUI 전용. GCD 금지(`async/await`·`actor`·`Task`·`AsyncStream`만). `ObservableObject`/`@Published` 금지.
- **유닛 테스트는 Swift Testing**(`import Testing`, `@Test`, `#expect`). XCTest는 `ChalNa/UITests/`만 예외.
- **전체 테스트는 `ChalNa-Workspace` 스킴으로만 실행한다.** `-scheme ChalNa`의 test 액션에는 유닛 8스위트가 들어있지 않다 — 그걸로 돌리면 조용히 빠진다.
  ```bash
  xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa-Workspace \
             -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
  ```
- **단일 모듈 테스트는 베이스 모듈명 스킴**을 쓴다(`-scheme DesignSystemTests`는 존재하지 않는다):
  ```bash
  xcodebuild -workspace ChalNa.xcworkspace -scheme CompositionService \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing:CompositionServiceTests/ClipFramingTests test
  ```
- **Spacing/padding은 토큰 없이 리터럴 숫자**(`.padding(16)`). 색/타이포/라디우스/모션은 `ChalNa*` 토큰. 화면 좌우 여백은 `20`.
- **리터럴 HEX·`Color.white`/`Color.black`·`.font(.system(...))` 하드코딩 금지.** `scripts/design-lint.sh`가 6규칙으로 정적 검사하며 **현재 전부 0건이다. 커밋 전 반드시 실행한다.**
  ```bash
  ./scripts/design-lint.sh
  ```
- **한국어 주석 OK, 식별자는 영어.** 한 파일 = 한 타입.
- 커밋 메시지 한국어 OK. 커밋 본문 끝에 `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.
- Tuist는 `buildableFolders`(Xcode 16 file-system-synchronized group)를 쓰므로 **파일 추가·삭제에 `tuist generate`가 필요 없다.** 단 `Project.swift`나 `Tuist/Package.swift`를 건드리면 필요하다 — 이 계획은 건드리지 않는다.

## File Structure

**Phase A — 크롭 제약 제거**

| 파일 | 책임 | 변경 |
|---|---|---|
| `Modules/Models/Sources/ClipTransform.swift` | 크롭 상태 값 타입 + 산술 안전 가드 | 상수 완화, `sanitized` 추가 |
| `Modules/Models/Sources/ClipFraming.swift` | 배치 기하 SSOT | clamp 2함수 삭제, `resolvedRect` 자유화 |
| `Modules/Models/Sources/RubberBand.swift` | 러버밴드 감쇠 | **삭제**(고아) |
| `Modules/CompositionService/Sources/CompositionService.swift` | export affine 산출 | clamp 호출 → `sanitized` |
| `Modules/CompositionService/Sources/ChalNaVideoCompositor.swift` | CoreImage 합성 | doc 주석만 정정 |
| `Modules/TimelineFeature/Sources/ClipAdjustView.swift` | 크롭 조정 화면 | 러버밴드·스냅백·엣지 햅틱·중복 rect·재클램프 제거 |

**Phase B — 라벨 2스텝**

| 파일 | 책임 | 변경 |
|---|---|---|
| `Modules/Models/Sources/ClipLabel.swift` | 박스 자막 모델 | `hasBackground` 추가 |
| `Modules/CompositionService/Sources/CompositionService.swift` | 합성 라벨 레이어 | `makeCustomLabelLayers` 분기 + internal화 |
| `Modules/TimelineFeature/Sources/Components/ClipLabelText.swift` | 라벨 표시 뷰 + **색 리터럴 유일 보관소** | `ClipLabelBoxPalette` 추가, `BoxSubtitleStyle` 분기 |
| `Modules/TimelineFeature/Sources/LabelEditorView.swift` | 라벨 에디터 | 3-phase → 2-step, 배경 토글 |
| `scripts/design-lint.sh` | 정적 검사 | 규칙 5 예외에서 `LabelEditorView.swift` 제거 |

**테스트**

| 파일 | 변경 |
|---|---|
| `Modules/CompositionService/Tests/ClipFramingTests.swift` | clamp 7케이스 삭제, `sanitized`·자유 프레이밍 케이스 추가 |
| `Modules/CompositionService/Tests/CompositionTransformTests.swift` | 3케이스 기대 갱신 |
| `Modules/CompositionService/Tests/PreviewExportContractTests.swift` | 2케이스 rename + 축소 계약 1개 추가 |
| `Modules/CompositionService/Tests/RubberBandTests.swift` | **삭제** |
| `Modules/CompositionService/Tests/CompositorRenderTests.swift` | 축소 → 검정 여백 픽셀 케이스 추가 |
| `Modules/CompositionService/Tests/CustomLabelLayoutTests.swift` | 배경 ON/OFF 레이어 케이스 3개 추가 |
| `Modules/CompositionService/Tests/CompositorLabelTests.swift` | 배경 OFF 픽셀 케이스 추가 |
| `Modules/AppCore/Tests/ClipLabelTests.swift` | `hasBackground` 케이스 2개 추가 |
| `Modules/TimelineFeature/Tests/ClipLabelBoxPaletteTests.swift` | **신규** |
| `ChalNa/UITests/CropAdjustUITests.swift` | 러버밴드 → 자유 크롭 플로우 |
| `ChalNa/UITests/LabelEditorUITests.swift` | 2스텝 플로우 |

---

## Task 1: `ClipTransform` 안전 가드로 전환

크롭 제약의 의미를 "UX 한계"에서 "산술 안전 가드"로 바꾼다. 이 태스크만으로도 축소·과확대가
허용되지만 offset clamp는 아직 살아 있다(Task 3에서 제거).

**Files:**
- Modify: `Modules/Models/Sources/ClipTransform.swift` (전체 교체)
- Test: `Modules/CompositionService/Tests/ClipFramingTests.swift` (섹션 추가)
- Test: `Modules/CompositionService/Tests/CompositionTransformTests.swift:300-312` (1케이스 기대 갱신)

**Interfaces:**
- Consumes: 없음 (첫 태스크)
- Produces:
  - `ClipTransform.minScale: CGFloat` == `0.1`
  - `ClipTransform.maxScale: CGFloat` == `10.0`
  - `ClipTransform.sanitized: ClipTransform` — scale을 `[minScale, maxScale]`로 clamp, non-finite scale은 `1.0`, non-finite offset 성분은 `0`으로 되돌린다. Task 2·3이 이걸 호출한다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`Modules/CompositionService/Tests/ClipFramingTests.swift` 파일 **맨 끝의 닫는 `}` 직전**에 붙인다:

```swift
    // MARK: - ClipTransform.sanitized (산술 안전 가드)

    /// 하한 미달 배율은 minScale(0.1)로 clamp — 축소 자체는 허용되지만 0 근처는 막는다.
    @Test func testSanitized_ClampsBelowMinScale() {
        let t = ClipTransform(scale: 0.05, offset: CGPoint(x: 0.3, y: -0.2)).sanitized
        #expect(abs(t.scale - ClipTransform.minScale) < 0.0001, "scale \(t.scale)")
        #expect(abs(t.offset.x - 0.3) < 0.0001, "offset 은 건드리지 않는다: \(t.offset.x)")
        #expect(abs(t.offset.y - (-0.2)) < 0.0001, "offset 은 건드리지 않는다: \(t.offset.y)")
    }

    /// 상한 초과 배율은 maxScale(10)로 clamp.
    @Test func testSanitized_ClampsAboveMaxScale() {
        let t = ClipTransform(scale: 100, offset: .zero).sanitized
        #expect(abs(t.scale - ClipTransform.maxScale) < 0.0001, "scale \(t.scale)")
    }

    /// 범위 안 값은 그대로 통과 — 0.5 는 이제 유효한 축소값이다.
    @Test func testSanitized_PassesThroughValidRange() {
        let t = ClipTransform(scale: 0.5, offset: CGPoint(x: 5, y: -5)).sanitized
        #expect(abs(t.scale - 0.5) < 0.0001, "scale \(t.scale)")
        #expect(abs(t.offset.x - 5) < 0.0001, "offset 제한 없음: \(t.offset.x)")
        #expect(abs(t.offset.y - (-5)) < 0.0001, "offset 제한 없음: \(t.offset.y)")
    }

    /// non-finite 방어: NaN scale → 1.0, NaN/Inf offset 성분 → 0.
    @Test func testSanitized_RecoversFromNonFinite() {
        let t = ClipTransform(scale: .nan, offset: CGPoint(x: .infinity, y: .nan)).sanitized
        #expect(abs(t.scale - 1.0) < 0.0001, "scale \(t.scale)")
        #expect(t.offset.x == 0, "offset.x \(t.offset.x)")
        #expect(t.offset.y == 0, "offset.y \(t.offset.y)")
    }
```

- [ ] **Step 2: 테스트가 실패하는 것을 확인한다**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme CompositionService \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CompositionServiceTests/ClipFramingTests test 2>&1 | tail -30
```
기대: 컴파일 실패 — `value of type 'ClipTransform' has no member 'sanitized'`

- [ ] **Step 3: `ClipTransform.swift` 를 아래 내용으로 전체 교체한다**

```swift
import CoreGraphics
import Foundation

/// 한 클립을 9:16 캔버스 안에서 사용자가 확대/축소/이동한 상태.
/// 기본값 `.fill` = 센터 크롭(캔버스 꽉 채움). `ClipRotation`/`ClipLabel` 과 동일하게 EditSession 이 들고 다닌다.
///
/// **UX 제약은 없다.** 사용자는 캔버스보다 작게 줄이거나(여백 발생) 캔버스 밖으로 밀어낼 수 있다.
/// 드러나는 여백은 검정이다 — 합성은 `ChalNaVideoCompositor` 의 검정 베이스, 프리뷰는
/// `ChalNaColor.canvas`(= 검정) 가 받는다. `minScale`/`maxScale` 은 **UX 한계가 아니라
/// 산술 안전 가드**이며, 적용 지점은 `sanitized` 하나다.
public struct ClipTransform: Hashable, Sendable {
    /// aspectFill(센터 크롭) 대비 배율. 1.0 = 꽉 채움, <1.0 = 여백 생김, >1.0 = 추가 확대.
    public var scale: CGFloat
    /// 캔버스(renderSize) 기준 정규화 평행이동. x=가로 비율, y=세로 비율(y-down). 제한 없음.
    public var offset: CGPoint

    public init(scale: CGFloat = 1.0, offset: CGPoint = .zero) {
        self.scale = scale
        self.offset = offset
    }

    /// 산술 안전 가드용 배율 범위(0 나눗셈·오버플로 방지). **UX 제약이 아니다.**
    public static let minScale: CGFloat = 0.1
    public static let maxScale: CGFloat = 10.0

    /// 기본 프레이밍: aspectFill 센터 크롭(추가 확대·이동 없음).
    public static let fill = ClipTransform(scale: 1.0, offset: .zero)

    /// 산술 안전 가드를 적용한 값. scale 은 `[minScale, maxScale]` 로 clamp 하고,
    /// non-finite(NaN/Inf) 는 기본값으로 되돌린다. offset 은 범위 제한 없이 유한성만 본다.
    ///
    /// 프리뷰(`ClipFraming.resolvedRect`)와 export(`AVFoundationCompositionService.transform`)가
    /// **둘 다 이걸 경유**해 같은 값을 본다 — 예전엔 export 만 scale 을 clamp 하고 프리뷰는
    /// 하지 않는 비대칭이 있었다.
    public var sanitized: ClipTransform {
        let s = scale.isFinite ? min(max(scale, Self.minScale), Self.maxScale) : 1.0
        return ClipTransform(
            scale: s,
            offset: CGPoint(x: offset.x.isFinite ? offset.x : 0,
                            y: offset.y.isFinite ? offset.y : 0)
        )
    }
}
```

- [ ] **Step 4: 하한 완화로 깨지는 기존 테스트를 고친다**

`Modules/CompositionService/Tests/CompositionTransformTests.swift` 의 마지막 테스트
(`testTransform_UserScaleBelowMin_ClampsToFill`, 약 `:298-312`)를 아래로 교체한다.
`export()` 의 scale clamp 범위가 `[0.1, 10]` 이 되어 0.5 가 더 이상 1.0으로 올라가지 않는다.

```swift
    /// 축소(scale 0.5): 하한이 없어졌으므로 그대로 0.5 배로 렌더된다 —
    /// 세로 1080×1920 클립이 540×960 으로 줄고 캔버스 중앙에 놓여 상하좌우에 여백이 생긴다.
    /// fillScale = 1, totalScale = 0.5, centerTranslate = ((1080-540)/2, (1920-960)/2) = (270, 480).
    @Test func testTransform_UserScaleBelowFill_ShrinksWithMargin() {
        let natural = CGSize(width: 1080, height: 1920)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural, preferredTransform: .identity, rotation: .r0,
            renderSize: render, framing: ClipTransform(scale: 0.5, offset: .zero)
        )
        let topLeft = CGPoint(x: 0, y: 0).applying(t)
        let bottomRight = CGPoint(x: natural.width, y: natural.height).applying(t)
        #expect(abs(topLeft.x - 270) < 0.5 && abs(topLeft.y - 480) < 0.5, "좌상단 (270,480): \(topLeft)")
        #expect(abs(bottomRight.x - 810) < 0.5 && abs(bottomRight.y - 1440) < 0.5,
                "우하단 (810,1440): \(bottomRight)")
    }
```

- [ ] **Step 5: 테스트가 통과하는 것을 확인한다**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme CompositionService \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CompositionServiceTests test 2>&1 | tail -30
```
기대: `TEST SUCCEEDED` — 특히 `testSanitized_*` 4개와 `testTransform_UserScaleBelowFill_ShrinksWithMargin` 통과.

- [ ] **Step 6: 커밋**

```bash
git add Modules/Models/Sources/ClipTransform.swift \
        Modules/CompositionService/Tests/ClipFramingTests.swift \
        Modules/CompositionService/Tests/CompositionTransformTests.swift
git commit -m "$(cat <<'EOF'
♻️ refactor: ClipTransform 배율 제약을 UX 한계 → 산술 안전 가드로 전환

- minScale 1.0→0.1, maxScale 4.0→10.0. 축소(여백 발생)와 과확대를 허용한다.
- sanitized 추가 — clamp + non-finite 방어를 한 곳에 모아 프리뷰/export 비대칭 제거.
- 축소 clamp 를 검증했던 export 테스트를 "그대로 줄어든다" 기대로 교체.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `ClipAdjustView` 러버밴드·스냅백·엣지 햅틱 제거

경계가 없어지면 러버밴드는 저항할 대상이, 스냅백은 목표가, 엣지 햅틱은 발화 순간이 없다.
이 태스크가 `ClipFraming` clamp 함수의 마지막 UI 소비자를 끊어 Task 3을 가능하게 한다.

**Files:**
- Modify: `Modules/TimelineFeature/Sources/ClipAdjustView.swift`
- Delete: `Modules/Models/Sources/RubberBand.swift`
- Delete: `Modules/CompositionService/Tests/RubberBandTests.swift`
- Modify: `ChalNa/UITests/CropAdjustUITests.swift`

**Interfaces:**
- Consumes: `ClipTransform.sanitized` (Task 1)
- Produces: 없음 (뷰 내부 변경). `RubberBand` 타입은 이 태스크 이후 존재하지 않는다.

- [ ] **Step 1: `ClipAdjustView.swift` 의 타입 doc 을 교체한다**

`:7-18` 의 doc 블록 전체(`/// 클립 1개를 …` 부터 `/// - 더블탭 = 기본 프레이밍(센터 크롭) 리셋.` 까지)를 아래로 교체:

```swift
/// 클립 1개를 9:16 캔버스 안에서 핀치 줌·드래그·회전으로 프레이밍하는 풀스크린 화면.
/// 전경은 aspectFill(센터 크롭) 기준 + ClipFraming.resolvedRect 배치 → export 와 픽셀 일치(WYSIWYG).
/// 편집은 EditSession 에 live 반영(회전 기존 동작과 동일, 별도 취소 없음).
///
/// 인터랙션:
/// - 확대·축소·이동에 **제약이 없다.** 캔버스보다 작게 줄이거나 캔버스 밖으로 밀어낼 수 있고,
///   드러나는 여백은 검정(`ChalNaColor.canvas`)이다 — export 도 동일(컴포지터의 검정 베이스).
///   따라서 러버밴드 저항·스프링 스냅백·한계 도달 햅틱은 없다(저항할 경계가 없다).
///   배율은 `ClipTransform.sanitized` 의 산술 안전 가드([0.1, 10])만 통과한다.
/// - 드래그/핀치 중에만 3분할 그리드 표시(Apple Photos 패턴).
/// - 더블탭 = 기본 프레이밍(센터 크롭) 리셋. 스프링 애니메이션은 이 리셋에만 남는다.
```

- [ ] **Step 2: 제스처 상태 프로퍼티를 교체한다**

`:22-32` 의 `raw` / `working` / `isAdjusting` / `atEdge` 4개 선언을 아래 2개로 교체:

```swift
    /// 제스처 중 누적되는 표시 변환(안전 가드만 적용). nil = 제스처 없음 → committed 그대로.
    @State private var live: ClipTransform? = nil
    /// 드래그/핀치 진행 중 여부 — 3분할 그리드 표시 조건.
    @State private var isAdjusting = false
```

- [ ] **Step 3: `canvas` 를 교체한다** (`:69-93`)

clamp 유무로 갈렸던 두 갈래 렌더가 하나로 합쳐진다.

```swift
    private var canvas: some View {
        ChalNaCanvas { box in
            let factor = box.width / Self.render.width
            let rrect = ClipFraming.resolvedRect(
                display: displaySize, rotation: rotation,
                render: Self.render, transform: live ?? committed
            )

            RotatableContent(rotation: rotation) {
                foreground
            }
            .frame(width: rrect.width * factor, height: rrect.height * factor)
            .position(x: rrect.midX * factor, y: rrect.midY * factor)

            thirdsGrid(box: box)
                .opacity(isAdjusting ? 1 : 0)
                .animation(ChalNaMotion.fast, value: isAdjusting)
        } overlay: { box in
            PinchPanGesture(
                onChange: { handleGestureChange($0, $1, viewBox: box) },
                onEnded: { commitLive() }
            )
            .frame(width: box.width, height: box.height)
            .onTapGesture(count: 2) { resetToCenterCrop() }
        }
        .padding(.horizontal, 20)
    }
```

- [ ] **Step 4: `resolvedRectUnclamped` 를 삭제한다** (`:96-107`)

doc 주석(`/// 러버밴드 오버슛을 …`) 포함 함수 전체를 지운다. `ClipFraming.resolvedRect` 와
완전히 동일해졌다.

- [ ] **Step 5: `rotate()` 의 재클램프를 제거한다** (`:178-197`)

```swift
    private func rotate() {
        session.cycleRotation(for: store.clipID)
        // 진행 중이던 제스처 상태는 옛 회전 좌표계 값이므로 무효화.
        // (offset 재클램프는 없다 — 이동 한계 자체가 사라졌으므로 "스테일 offset" 개념이 없다.)
        live = nil
        isAdjusting = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
```

- [ ] **Step 6: `resetToCenterCrop()` 을 교체한다** (`:200-211`)

```swift
    /// 기본 프레이밍(센터 크롭)으로 리셋 — 더블탭/초기화 버튼 공용.
    private func resetToCenterCrop() {
        isAdjusting = false
        // 시각 변화는 committed(EditSession) 갱신에서 오므로 세션 뮤테이션까지
        // withAnimation 안에 둬야 스프링이 실제로 애니메이션된다.
        withAnimation(Self.snapBack) {
            live = nil
            session.resetTransform(for: store.clipID)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
```

- [ ] **Step 7: `handleGestureChange` / `commitWorking` 을 교체한다** (`:213-259`)

```swift
    private func handleGestureChange(_ scaleFactor: CGFloat, _ translation: CGSize, viewBox: CGSize) {
        var base = live ?? committed
        base.scale *= scaleFactor
        base.offset.x += viewBox.width > 0 ? translation.width / viewBox.width : 0
        base.offset.y += viewBox.height > 0 ? translation.height / viewBox.height : 0
        // 제약이 없으니 표시값 = 원시값. 산술 안전 가드만 통과시킨다(idempotent).
        live = base.sanitized
        isAdjusting = true
    }

    private func commitLive() {
        guard let final = live else { return }
        session.setTransform(final, for: store.clipID)
        live = nil
        isAdjusting = false
    }
```

- [ ] **Step 8: 힌트 문구를 교체한다** (`:169`)

축소도 가능해졌으므로 "확대해요" 를 고친다. UI 테스트가 `'더블탭 = 초기화'` 를 grep 하므로
그 부분 문자열은 반드시 유지한다.

```swift
        Text("드래그로 옮기고 핀치로 크기를 바꿔요. 더블탭 = 초기화")
```

- [ ] **Step 9: 고아가 된 `RubberBand` 를 삭제한다**

```bash
rm Modules/Models/Sources/RubberBand.swift
rm Modules/CompositionService/Tests/RubberBandTests.swift
```

- [ ] **Step 10: 빌드해서 `RubberBand` 참조가 남지 않았는지 확인한다**

```bash
grep -rn "RubberBand" Modules/ ChalNa/ && echo "!! 참조 남음" || echo "OK: 참조 없음"
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -20
```
기대: grep 이 `OK: 참조 없음`, 빌드 `BUILD SUCCEEDED`

- [ ] **Step 11: 크롭 UI 테스트를 자유 크롭 플로우로 교체한다**

`ChalNa/UITests/CropAdjustUITests.swift` 의 클래스 doc(`:3-7`)을 교체:

```swift
/// 크롭 조정 플로우 시각 검증용 UI 테스트 (devMock 픽스처 사용, 사진 권한 불필요).
///
/// 각 체크포인트에서 `Thread.sleep` 으로 화면을 유지해, 호스트에서 `simctl io screenshot`
/// 폴링으로 프레임을 수집·검수할 수 있게 한다. XCTAttachment 스냅샷도 함께 남긴다.
///
/// 확대·축소·이동에 제약이 없으므로(러버밴드·스냅백 없음) 검증 대상은
/// "축소하면 검정 여백이 드러난다 · 캔버스 밖으로 밀어도 튕겨 돌아오지 않는다 · 초기화가 복구한다" 다.
```

`testAdjustFlow_CenterCrop_RubberBand_Reset` 의 시그니처를 이름만 바꾸고
`// 1)` ~ `// 4)` 블록(약 `:51-79`)을 아래로 교체한다. `// 5)` 더블탭 블록은 그대로 둔다.

```swift
    func testAdjustFlow_FreeCrop_ZoomOut_Pan_Reset() throws {
```

```swift
        // 1) scale=1(딱 맞음)에서 우측으로 크게 드래그 —
        //    이동 제약이 없으므로 손을 떼도 스냅백 없이 그 자리에 머물러야 한다.
        //    (좌측에 검정 여백이 드러난 상태로 커밋된다.)
        let farRight = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.45))
        canvasCenter.press(forDuration: 0.2, thenDragTo: farRight,
                           withVelocity: 300, thenHoldForDuration: 1.0)
        checkpoint(app, name: "30-panned-past-cover", holdSeconds: 3)

        // 2) 핀치 인(축소) → 사진이 캔버스보다 작아지고 사방에 검정 여백이 생긴다.
        app.pinch(withScale: 0.5, velocity: -1.0)
        checkpoint(app, name: "40-zoomed-out-with-margin", holdSeconds: 3)

        // 3) 축소 상태에서 좌측으로 드래그 → 제약 없이 그대로 이동
        let left = app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.45))
        canvasCenter.press(forDuration: 0.2, thenDragTo: left,
                           withVelocity: 300, thenHoldForDuration: 1.0)
        checkpoint(app, name: "50-panned-while-shrunk", holdSeconds: 3)

        // 4) 회전 — 재클램프가 없어졌으므로 프레이밍(scale·offset)이 그대로 유지되어야 한다.
        let rotateButton = app.buttons["회전"].firstMatch
        XCTAssertTrue(rotateButton.waitForExistence(timeout: 5), "회전 버튼")
        rotateButton.tap()
        checkpoint(app, name: "55-rotated-keeps-framing", holdSeconds: 3)
        // 원위치(r0)로 3번 더 회전.
        for _ in 0..<3 { rotateButton.tap() }
```

- [ ] **Step 12: 크롭 UI 테스트를 실행한다**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:ChalNaUITests/CropAdjustUITests test 2>&1 | tail -30
```
기대: `TEST SUCCEEDED`. 실패하면 첨부 스크린샷(`30-panned-past-cover`, `40-zoomed-out-with-margin`)을
확인해 검정 여백이 실제로 보이는지 눈으로 확인한다.

- [ ] **Step 13: design-lint 실행 후 커밋**

```bash
./scripts/design-lint.sh
git add -A Modules/TimelineFeature/Sources/ClipAdjustView.swift \
           Modules/Models/Sources/RubberBand.swift \
           Modules/CompositionService/Tests/RubberBandTests.swift \
           ChalNa/UITests/CropAdjustUITests.swift
git commit -m "$(cat <<'EOF'
🔥 remove: 크롭 조정 화면의 러버밴드·스냅백·엣지 햅틱 제거

- 이동/배율 경계가 사라져 저항·스냅백·한계 햅틱이 의미를 잃었다. raw+working 2중 상태를
  live 하나로, resolvedRectUnclamped(ClipFraming.resolvedRect 와 동일해짐)를 삭제.
- 회전 후 offset 재클램프 제거 — 이동 한계가 없으니 스테일 offset 개념이 없다.
- 유일 소비자가 사라진 Models/RubberBand.swift 와 그 테스트 삭제.
- UI 테스트를 자유 크롭(축소 여백·스냅백 없음·회전 후 프레이밍 유지) 검증으로 교체.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `ClipFraming` clamp 삭제 + export 경로 정렬

**Files:**
- Modify: `Modules/Models/Sources/ClipFraming.swift`
- Modify: `Modules/CompositionService/Sources/CompositionService.swift:529-579` (`transform`)
- Test: `Modules/CompositionService/Tests/ClipFramingTests.swift`
- Test: `Modules/CompositionService/Tests/CompositionTransformTests.swift`
- Test: `Modules/CompositionService/Tests/PreviewExportContractTests.swift`

**Interfaces:**
- Consumes: `ClipTransform.sanitized` (Task 1)
- Produces:
  - `ClipFraming.maxOffsetFraction` · `ClipFraming.clampedOffset` — **삭제됨.** 이후 태스크에서 호출하지 않는다.
  - `ClipFraming.orientedSize(_:rotation:)` · `ClipFraming.fillScale(display:rotation:render:)` · `ClipFraming.resolvedRect(display:rotation:render:transform:)` — 시그니처 그대로 유지.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`Modules/CompositionService/Tests/ClipFramingTests.swift` 에서 `// MARK: - maxOffsetFraction / clampedOffset`
섹션 헤더와 그 아래 5개 테스트, 그리고 `// MARK: - 회전 + offset 조합 …` 섹션의 앞 2개 테스트
(총 7개: `testClampedOffset_ExactCover_LocksToCenter`, `testMaxOffsetFraction_Landscape_HorizontalOnly`,
`testClampedOffset_Landscape_ClampsToCropLimit`, `testClampedOffset_Zoomed_ClampsToCoverEdge`,
`testClampedOffset_BelowCover_LocksToCenter`, `testMaxOffsetFraction_R90_Portrait_BecomesHorizontal`,
`testClampedOffset_R90_Landscape_InvalidatesStaleOffset`)를 **삭제**하고, 그 자리에 아래를 넣는다.

```swift
    // MARK: - 자유 프레이밍 (clamp 없음)

    /// 예전 이동 한계(가로 클립 scale 1 → 1.08025)를 크게 넘는 offset 도 그대로 반영된다.
    /// 1920×1080 → fillScale 1.77778 → 3413.33×1920. offset.x=2.0 → 중심이 +2160px 이동.
    /// 결과 minX = 540 - 3413.33/2 + 2160 = 993.33 (캔버스 우측 밖으로 밀려남).
    @Test func testResolvedRect_OffsetBeyondCover_MovesFreely() {
        let r = ClipFraming.resolvedRect(
            display: CGSize(width: 1920, height: 1080), rotation: .r0, render: render,
            transform: ClipTransform(scale: 1, offset: CGPoint(x: 2.0, y: 0))
        )
        #expect(abs(r.minX - 993.33) < 0.5, "minX \(r.minX)")
    }

    /// scale < 1: 전경이 캔버스보다 작아진다(여백 발생). 세로 1080×1920 × 0.5 → 540×960 중앙.
    @Test func testResolvedRect_ScaleBelowFill_SmallerThanCanvas() {
        let r = ClipFraming.resolvedRect(
            display: CGSize(width: 1080, height: 1920), rotation: .r0, render: render,
            transform: ClipTransform(scale: 0.5, offset: .zero)
        )
        #expect(abs(r.width - 540) < 0.5, "w \(r.width)")
        #expect(abs(r.height - 960) < 0.5, "h \(r.height)")
        #expect(abs(r.minX - 270) < 0.5, "minX \(r.minX)")
        #expect(abs(r.minY - 480) < 0.5, "minY \(r.minY)")
    }

    /// 축소 + 이동 조합: 작아진 전경을 캔버스 밖으로도 밀 수 있다.
    /// 540×960 을 offset(0.5, -0.5) → 중심 (540+540, 960-960) = (1080, 0) → minX 810, minY -480.
    @Test func testResolvedRect_ShrunkAndPushedOutOfCanvas() {
        let r = ClipFraming.resolvedRect(
            display: CGSize(width: 1080, height: 1920), rotation: .r0, render: render,
            transform: ClipTransform(scale: 0.5, offset: CGPoint(x: 0.5, y: -0.5))
        )
        #expect(abs(r.minX - 810) < 0.5, "minX \(r.minX)")
        #expect(abs(r.minY - (-480)) < 0.5, "minY \(r.minY)")
    }

    /// resolvedRect 는 산술 안전 가드를 경유한다 — NaN scale 은 1.0 으로 복구되어 fill 이 된다.
    @Test func testResolvedRect_NonFiniteScale_FallsBackToFill() {
        let r = ClipFraming.resolvedRect(
            display: CGSize(width: 1080, height: 1920), rotation: .r0, render: render,
            transform: ClipTransform(scale: .nan, offset: .zero)
        )
        #expect(abs(r.width - 1080) < 0.5, "w \(r.width)")
        #expect(abs(r.height - 1920) < 0.5, "h \(r.height)")
    }
```

이어서 파일 마지막 테스트 `testResolvedRect_R90_WithOffset_ShiftsWithinLimit` 의 이름과 doc 만
바꾼다(값은 예전 한계값과 동일하므로 기대치는 그대로 통과한다):

```swift
    /// r90 + 비제로 offset 의 resolvedRect: 세로 클립을 r90 돌리면 가로가 되어
    /// offset.x=1.08025 에서 rect 좌측 끝이 정확히 캔버스 좌측(0)에 닿는다.
    /// (예전엔 이 값이 clamp 한계였고, 지금은 그냥 "딱 맞는 지점"이라는 의미만 남는다.)
    @Test func testResolvedRect_R90_WithOffset_ShiftsToCanvasEdge() {
```

- [ ] **Step 2: 테스트가 실패하는 것을 확인한다**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme CompositionService \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CompositionServiceTests/ClipFramingTests test 2>&1 | tail -40
```
기대: `testResolvedRect_OffsetBeyondCover_MovesFreely` 등이 FAIL (`minX` 가 clamp 되어 0 근처)

- [ ] **Step 3: `ClipFraming.swift` 를 아래 내용으로 전체 교체한다**

```swift
import CoreGraphics

/// 클립을 9:16 캔버스 안에 배치하는 기하의 단일 진실원천(SSOT).
/// 프리뷰·조정 화면·영상 합성(export)이 **모두 이 계산을 공유**해 WYSIWYG 가 어긋나지 않게 한다.
/// 좌표계는 SwiftUI/CG 표준(y-down). `display` 는 `preferredTransform` 적용 후 표시 크기.
///
/// 기준 배율은 **aspectFill(센터 크롭)** — `ClipTransform.fill`(scale 1, offset 0)이면 클립이
/// 캔버스를 꽉 덮는다. 하지만 사용자 scale·offset 에는 **제약이 없다**: scale < 1 이면 캔버스보다
/// 작아지고, offset 은 캔버스 밖까지 자유롭게 나갈 수 있다. 드러나는 여백은 검정이다
/// (합성은 `ChalNaVideoCompositor` 의 검정 베이스, 프리뷰는 `ChalNaColor.canvas`).
public enum ClipFraming {
    /// 사용자 회전 반영 표시 크기.
    public static func orientedSize(_ display: CGSize, rotation: ClipRotation) -> CGSize {
        rotation.swapsAxes ? CGSize(width: display.height, height: display.width) : display
    }

    /// renderSize 를 꽉 덮는 aspectFill 배율(회전 반영). 0/NaN/Inf 가드. 모든 배치의 기준 배율.
    public static func fillScale(display: CGSize, rotation: ClipRotation, render: CGSize) -> CGFloat {
        let s = orientedSize(display, rotation: rotation)
        let w = max(s.width, 1), h = max(s.height, 1)
        let raw = max(render.width / w, render.height / h)
        return (raw.isFinite && raw > 0) ? raw : 1
    }

    /// 캔버스(render) 좌표계(y-down)에서 전경이 차지하는 사각형. scale·offset 을 **clamp 없이** 반영한다.
    /// `transform` 은 `ClipTransform.sanitized` 의 산술 안전 가드만 통과한다 —
    /// export 경로(`AVFoundationCompositionService.transform`)도 같은 가드를 쓴다.
    public static func resolvedRect(
        display: CGSize, rotation: ClipRotation, render: CGSize, transform: ClipTransform
    ) -> CGRect {
        let t = transform.sanitized
        let s = orientedSize(display, rotation: rotation)
        let fill = fillScale(display: display, rotation: rotation, render: render)
        let size = CGSize(width: s.width * fill * t.scale, height: s.height * fill * t.scale)
        let center = CGPoint(x: render.width / 2 + t.offset.x * render.width,
                             y: render.height / 2 + t.offset.y * render.height)
        return CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                      width: size.width, height: size.height)
    }
}
```

- [ ] **Step 4: `CompositionService.transform` 의 ④·⑥ 단계를 교체한다**

`Modules/CompositionService/Sources/CompositionService.swift` 에서
`// ④ fill(센터 크롭) 배율은 …` 부터 `let totalScale = fillScale * userScale` 까지(약 `:551-555`)를:

```swift
        // ④ fill(센터 크롭) 배율은 ClipFraming 과 공유. 사용자 배율에는 UX 제약이 없고
        //    `sanitized` 의 산술 안전 가드([0.1, 10] + non-finite 방어)만 적용된다 —
        //    1 미만이면 캔버스에 검정 여백이 드러난다(컴포지터의 검정 베이스가 받는다).
        let safeFraming = framing.sanitized
        let fillScale = ClipFraming.fillScale(display: displaySize, rotation: rotation, render: renderSize)
        let totalScale = fillScale * safeFraming.scale
```

그리고 `// ⑥ 사용자 이동 …` 부터 `y: clampedFrac.y * renderSize.height)` 까지(약 `:564-568`)를:

```swift
        // ⑥ 사용자 이동(정규화 비율 → 픽셀). clamp 없음 — 전경이 캔버스 밖으로 나갈 수 있다.
        let offsetTranslate = CGAffineTransform(translationX: safeFraming.offset.x * renderSize.width,
                                                y: safeFraming.offset.y * renderSize.height)
```

또한 함수 doc(`:527-528`)의 `/// framing == .fill 이면 추가 조작 없는 기본 센터 크롭.` 아래에 한 줄 추가:

```swift
    /// scale·offset 에 제약은 없다 — 전경이 캔버스를 못 덮으면 남는 영역은 컴포지터의 검정 베이스가 받는다.
```

- [ ] **Step 5: `clampedOffset`/`maxOffsetFraction` 을 쓰던 export 테스트 2개를 고친다**

`Modules/CompositionService/Tests/CompositionTransformTests.swift`:

(a) `testTransform_LandscapeOffsetAtLimit_RevealsSourceEdge` (약 `:243-255`) — 삭제된
`ClipFraming.maxOffsetFraction` 을 호출하므로 리터럴로 바꾼다:

```swift
    /// 가로 1920×1080 클립을 offset.x = 1.08025 로 밀면 소스 좌측 끝이 캔버스 좌측(0)에 정확히 닿는다.
    /// 유도: fillScale = 1920/1080 = 1.77778 → scaledW = 3413.33.
    ///       (3413.33 - 1080) / 2 / 1080 = 1.08025. (예전 이동 한계값이었고 지금은 그냥 기준점이다.)
    @Test func testTransform_LandscapeOffsetAtCoverEdge_RevealsSourceEdge() {
        let natural = CGSize(width: 1920, height: 1080)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural, preferredTransform: .identity, rotation: .r0,
            renderSize: render, framing: ClipTransform(scale: 1, offset: CGPoint(x: 1.08025, y: 0))
        )
        let topLeft = CGPoint(x: 0, y: 0).applying(t)
        #expect(abs(topLeft.x - 0) < 0.5, "offset 1.08025 에서 소스 좌측 끝 = 캔버스 좌측: \(topLeft.x)")
    }
```

(b) `testTransform_OffsetBeyondLimit_ClampsToLimit` (약 `:286-297`) — clamp 가 사라졌다:

```swift
    /// 한계를 크게 초과한 offset(x=2.0)도 clamp 되지 않고 그대로 반영된다.
    /// centerTranslate.x = (1080 - 3413.33)/2 = -1166.67, offsetTranslate.x = 2.0 × 1080 = 2160
    /// → topLeft.x = -1166.67 + 2160 = 993.33 (전경이 캔버스 우측 밖으로 밀려남).
    @Test func testTransform_OffsetBeyondCover_MovesFreely() {
        let natural = CGSize(width: 1920, height: 1080)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural, preferredTransform: .identity, rotation: .r0,
            renderSize: render, framing: ClipTransform(scale: 1, offset: CGPoint(x: 2.0, y: 0))
        )
        let topLeft = CGPoint(x: 0, y: 0).applying(t)
        #expect(abs(topLeft.x - 993.33) < 0.5, "clamp 없이 그대로 이동: \(topLeft.x)")
    }
```

- [ ] **Step 6: 계약 테스트의 이름·doc 을 갱신하고 축소 케이스를 추가한다**

`Modules/CompositionService/Tests/PreviewExportContractTests.swift`.
**assertion 은 그대로 통과한다**(양쪽 경로가 같이 clamp 를 잃었으므로) — 이름과 주석만 거짓말이 된다.

파일 상단 doc 의 `…배율/오프셋 원시값은 `ClipFraming.fillScale`·`clampedOffset`` 을
`…배율/오프셋 원시값은 `ClipFraming.fillScale` 과 `ClipTransform.sanitized`` 로 바꾼다.
`tolerance` 위 주석의 `두 경로 모두 같은 `fillScale`/`clampedOffset` 값을 쓰지만` 도
`두 경로 모두 같은 `fillScale`/`sanitized` 값을 쓰지만` 으로 바꾼다.

그리고 `// MARK: - clampedOffset 이 실제로 clamp 되는 경로` 이하 2개 테스트를 아래로 교체:

```swift
    // MARK: - 극단 offset / 축소 (clamp 가 없어진 경로)

    /// 예전 이동 한계(≈1.08025)를 크게 넘는 offset. 두 경로가 똑같이 clamp 없이 반영해야 한다.
    @Test func testContract_Landscape_R0_ExtremeOffset() {
        expectContract(display: CGSize(width: 1920, height: 1080), rotation: .r0,
                       transform: ClipTransform(scale: 1, offset: CGPoint(x: 2.0, y: -0.5)))
    }

    /// 회전 + scale + 극단 offset 조합 — 회전이 오리엔티드 축을 바꾸는 경로에서도 일치.
    @Test func testContract_Portrait_R90_ScaleAndExtremeOffset() {
        expectContract(display: CGSize(width: 1080, height: 1920), rotation: .r90,
                       transform: ClipTransform(scale: 2, offset: CGPoint(x: 5.0, y: 5.0)))
    }

    /// 축소(scale < 1) — 전경이 캔버스를 못 덮는 새 영역. 프리뷰가 그리는 여백 위치와
    /// export 가 만드는 여백 위치가 어긋나면 WYSIWYG 가 깨지는 지점이다.
    @Test func testContract_Portrait_R0_ScaleBelowFill() {
        expectContract(display: CGSize(width: 1080, height: 1920), rotation: .r0,
                       transform: ClipTransform(scale: 0.5, offset: CGPoint(x: 0.2, y: -0.3)))
    }
```

- [ ] **Step 7: 테스트가 통과하는 것을 확인한다**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme CompositionService \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CompositionServiceTests test 2>&1 | tail -30
grep -rn "clampedOffset\|maxOffsetFraction" Modules/ ChalNa/ && echo "!! 참조 남음" || echo "OK: 참조 없음"
```
기대: `TEST SUCCEEDED` + `OK: 참조 없음`

- [ ] **Step 8: 커밋**

```bash
git add Modules/Models/Sources/ClipFraming.swift \
        Modules/CompositionService/Sources/CompositionService.swift \
        Modules/CompositionService/Tests/
git commit -m "$(cat <<'EOF'
🔥 remove: ClipFraming 의 offset clamp 삭제 — 크롭 이동 제약 해제

- maxOffsetFraction·clampedOffset 삭제. identity 로 남기지 않았다(죽은 추상이고,
  호출부 독자에게 제약이 아직 있다고 잘못 알린다).
- resolvedRect 와 export transform 둘 다 ClipTransform.sanitized 를 경유해
  같은 안전 가드를 본다(예전엔 export 만 scale 을 clamp 하는 비대칭이 있었다).
- 프리뷰↔export 계약 테스트에 축소(scale<1) 케이스 추가 — 여백 위치가 어긋나면 잡힌다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: 축소 시 여백이 검정인 것을 픽셀로 잠근다

컴포지터는 코드 변경이 없다. "여백 = 검정" 은 지금 **주석에만** 있는 사실이라, 나중에 누가
검정 베이스를 지우면 조용히 깨진다. 픽셀 테스트로 못 박고 주석을 정정한다.

**Files:**
- Modify: `Modules/CompositionService/Sources/ChalNaVideoCompositor.swift:38-39` (doc 주석)
- Modify: `Modules/CompositionService/Sources/ChalNaVideoCompositor.swift:82` (doc 주석)
- Test: `Modules/CompositionService/Tests/CompositorRenderTests.swift`

**Interfaces:**
- Consumes: `ClipFraming.resolvedRect` 자유화 (Task 3), `ClipTransform(scale:offset:)` (Task 1)
- Produces: 없음

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`Modules/CompositionService/Tests/CompositorRenderTests.swift` 의
`testCompositor_PlacesForegroundUnflipped_CenterCropFillsCanvas` 바로 뒤(`// MARK: - Helpers` 앞)에 추가:

```swift
    /// 축소(scale 0.5): 전경이 캔버스를 못 덮고 상·하단에 여백이 생긴다. 그 여백은 **검정**이어야 한다
    /// (`ChalNaVideoCompositor` 의 불투명 검정 베이스). 이 사실은 지금까지 주석에만 있었다.
    ///
    /// 기하: 640×360 → fillScale = max(1080/640, 1920/360) = 5.3333, ×0.5 = 2.6667
    ///       → 전경 1706.67×960, 캔버스 중앙 배치 → y ∈ [480, 1440) 만 전경, 그 밖은 검정.
    ///       x 는 여전히 넘침(1706.67 > 1080)이라 좌우 여백은 없다.
    @Test func testCompositor_ScaleBelowFill_LeavesBlackMargin() async throws {
        let srcURL = try await makeQuadrantVideo(width: 640, height: 360, seconds: 0.5, fps: 24)
        defer { try? FileManager.default.removeItem(at: srcURL) }

        let clip = Clip(
            kind: .video,
            capturedAt: Date(),
            duration: 0.5,
            preset: .jejuSea,
            thumbnailData: nil,
            videoURL: srcURL,
            displaySize: CGSize(width: 640, height: 360)
        )

        let service = AVFoundationCompositionService()
        var outURL: URL?
        for await event in service.export(
            clips: [clip], rotations: [:],
            transforms: [clip.id: ClipTransform(scale: 0.5, offset: .zero)],
            clipLabels: [:]
        ) {
            switch event {
            case .completed(let url): outURL = url
            case .failed(let msg): Issue.record("export failed: \(msg)"); return
            case .progress: break
            }
        }
        guard let exportedURL = outURL else {
            Issue.record("export never completed")
            return
        }
        defer { try? FileManager.default.removeItem(at: exportedURL) }

        let asset = AVURLAsset(url: exportedURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = false
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let cgImage = try await generator.image(at: CMTime(seconds: 0.25, preferredTimescale: 600)).image
        let sampler = try PixelSampler(cgImage: cgImage, width: 1080, height: 1920)

        // 여백 샘플 2곳(상단 밴드·하단 밴드 좌측) + 전경 샘플 1곳.
        // 자동 시각/날짜 라벨은 우측 하단이라 여백 밴드와 겹칠 수 있다 —
        // 손계산 주석이 아니라 `LabelText.stampRect` 로 회피를 확인한다.
        let samplePoints: [(x: Int, y: Int)] = [(100, 100), (100, 1800), (270, 700)]
        expectClearOfAutoLabelStamp(samplePoints, capturedAt: clip.capturedAt)

        let topMargin = sampler.rgb(x: 100, y: 100)
        let bottomMargin = sampler.rgb(x: 100, y: 1800)
        // x=270 → 소스 좌측 절반, y=700 → 전경 상단 절반 → 4분면 좌상 RED.
        let foreground = sampler.rgb(x: 270, y: 700)

        print("[CompositorRenderTests] topMargin=\(topMargin) bottomMargin=\(bottomMargin) foreground=\(foreground)")

        #expect(topMargin.r < 24 && topMargin.g < 24 && topMargin.b < 24,
                "축소 시 상단 여백은 검정이어야 함: \(topMargin)")
        #expect(bottomMargin.r < 24 && bottomMargin.g < 24 && bottomMargin.b < 24,
                "축소 시 하단 여백은 검정이어야 함: \(bottomMargin)")
        #expect(foreground.r > 150 && foreground.g < 120 && foreground.b < 120,
                "축소된 전경 상단 좌측은 RED 여야 함: \(foreground)")
    }
```

- [ ] **Step 2: 테스트를 실행한다**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme CompositionService \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CompositionServiceTests/CompositorRenderTests test 2>&1 | tail -30
```
기대: **PASS** — Task 3 로 축소가 이미 동작하고 컴포지터의 검정 베이스가 이미 있으므로
이 테스트는 첫 실행에서 통과한다. 이건 회귀 가드(characterization test)다.
FAIL 이면 `print` 로 찍힌 실제 RGB 값으로 원인을 좁힌다 — 특히 `foreground` 가 검정이면
전경 배치가 어긋난 것이고, `topMargin` 이 회색이면 aspectFill 이 안 풀린 것이다.

- [ ] **Step 3: 컴포지터 doc 주석을 정정한다**

`Modules/CompositionService/Sources/ChalNaVideoCompositor.swift:38-39` 의 타입 doc:

```swift
/// 9:16 캔버스에 전경(aspectFill 센터 크롭 + 사용자 변환)을 배치하고 라벨 오버레이를 얹는 커스텀 컴포지터.
/// 전경은 캔버스를 **꽉 덮지 않을 수 있다** — 사용자가 fill 미만으로 축소하거나 캔버스 밖으로
/// 밀어낼 수 있기 때문이다(`ClipTransform` 참고). 드러나는 여백은 아래 불투명 검정 베이스가 받는다.
```

`:82` 의 `// ① 전경: …` 주석:

```swift
        // ① 전경: aspectFill(센터 크롭) + 사용자 변환. 불투명 검정 베이스 위에 얹는다 —
        //    서브픽셀 경계 틈뿐 아니라, 축소·캔버스 밖 이동으로 생기는 여백도 이 베이스가 채운다.
        //    (`CompositorRenderTests.testCompositor_ScaleBelowFill_LeavesBlackMargin` 가 픽셀로 잠근다.)
```

- [ ] **Step 4: 전체 유닛 테스트를 돌려 Phase A 를 마감한다**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa-Workspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -40
```
기대: `TEST SUCCEEDED`. 8스위트 전부 그린.

- [ ] **Step 5: 커밋**

```bash
./scripts/design-lint.sh
git add Modules/CompositionService/Sources/ChalNaVideoCompositor.swift \
        Modules/CompositionService/Tests/CompositorRenderTests.swift
git commit -m "$(cat <<'EOF'
✅ test: 축소 시 여백이 검정인 것을 픽셀로 잠금

- 640×360 클립을 scale 0.5 로 export 해 상·하단 여백이 검정, 전경은 4분면 색인지 확인.
- "여백 = 검정" 은 지금까지 컴포지터 주석에만 있던 사실이라 검정 베이스를 지우면
  조용히 깨졌다. 주석도 축소·캔버스 밖 이동을 반영해 정정.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `ClipLabel.hasBackground` 추가

**Files:**
- Modify: `Modules/Models/Sources/ClipLabel.swift`
- Test: `Modules/AppCore/Tests/ClipLabelTests.swift`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `ClipLabel.hasBackground: Bool` — 기본 `true`
  - `ClipLabel.init(text:sizeFraction:position:hasBackground:)` — 모든 인자에 기본값이 있어 기존 호출부는 그대로 컴파일된다. Task 6·7·8이 이 프로퍼티를 읽는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`Modules/AppCore/Tests/ClipLabelTests.swift` 의 마지막 `}` 직전에 추가:

```swift
    /// 기본은 배경 ON — 기존 라벨의 외형(흰 박스)이 그대로 유지되어야 한다.
    @Test func defaultHasBackgroundIsOn() {
        #expect(ClipLabel().hasBackground)
    }

    /// 배경 유무는 값 동등성에 참여한다 — 참여하지 않으면 토글이 뷰 갱신을 못 일으킨다.
    @Test func hasBackgroundParticipatesInEquality() {
        let on = ClipLabel(text: "제주 바다", hasBackground: true)
        let off = ClipLabel(text: "제주 바다", hasBackground: false)
        #expect(on != off)
        #expect(on.hashValue != off.hashValue)
    }
```

- [ ] **Step 2: 테스트가 실패하는 것을 확인한다**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme AppCore \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:AppCoreTests/ClipLabelTests test 2>&1 | tail -20
```
기대: 컴파일 실패 — `no member 'hasBackground'`

- [ ] **Step 3: `ClipLabel.swift` 의 상단 doc·프로퍼티·init 을 교체한다**

`:1-25` 구간(doc 부터 `init` 끝까지)을 아래로 교체:

```swift
import CoreGraphics
import Foundation

/// 편집 세션 동안 클립별로 사용자가 붙이는 박스 자막. 회전(`ClipRotation`)과 같은 per-clip 메타로,
/// 불변 `Clip` 이 아니라 `EditSession` 의 딕셔너리에 담는다.
///
/// 스타일은 `hasBackground` 로 갈린다:
/// - `true`  — 흰 배경 + 검정 글씨 + 검정 테두리 박스
/// - `false` — 배경·테두리 없는 흰 글씨(장식 없음)
///
/// 사용자가 정하는 것은 문구 · 크기 · 위치 · 배경 유무 네 가지다.
public struct ClipLabel: Hashable, Sendable {
    /// 자막 문구. 빈/공백 문자열이면 자막 없음으로 취급.
    public var text: String
    /// 9:16 캔버스 높이 대비 글자 크기 비율. `clampedSizeFraction` 으로 0.04...0.25 클램프해 사용.
    public var sizeFraction: CGFloat
    /// 9:16 캔버스 기준 정규화 위치(자막 중심). x,y ∈ 0...1, y는 위(0)→아래(1) 스크린 방향.
    public var position: CGPoint
    /// 배경 박스(흰 면 + 검정 테두리) 표시 여부. false 면 흰 글자만 그린다.
    ///
    /// **패딩은 ON/OFF 에서 동일하다.** 배경을 지울 때 패딩까지 지우면 박스 크기가 달라져
    /// `position`(박스 중심) 역산이 바뀌고, 토글할 때마다 라벨이 움직인다. 프리뷰
    /// (`BoxSubtitleStyle`)와 합성(`makeCustomLabelLayers`)이 이 규칙을 공유한다.
    public var hasBackground: Bool

    public init(
        text: String = "",
        sizeFraction: CGFloat = 0.10,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        hasBackground: Bool = true
    ) {
        self.text = text
        self.sizeFraction = sizeFraction
        self.position = position
        self.hasBackground = hasBackground
    }
```

- [ ] **Step 4: 테스트가 통과하는 것을 확인한다**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme AppCore \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:AppCoreTests test 2>&1 | tail -20
```
기대: `TEST SUCCEEDED`

- [ ] **Step 5: 커밋**

```bash
git add Modules/Models/Sources/ClipLabel.swift Modules/AppCore/Tests/ClipLabelTests.swift
git commit -m "$(cat <<'EOF'
✨ feat: ClipLabel 에 배경 박스 유무(hasBackground) 추가

- 기본 true(기존 흰 박스 외형 유지). 모든 init 인자에 기본값이 있어 기존 호출부는 그대로 컴파일.
- 패딩은 ON/OFF 동일하다는 규칙을 프로퍼티 doc 에 명시 — 패딩이 바뀌면 position(박스 중심)
  역산이 달라져 토글마다 라벨이 움직인다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: 합성(`CATextLayer`) 배경 ON/OFF 분기

**Files:**
- Modify: `Modules/CompositionService/Sources/CompositionService.swift:464-506` (`makeCustomLabelLayers`)
- Test: `Modules/CompositionService/Tests/CustomLabelLayoutTests.swift`
- Test: `Modules/CompositionService/Tests/CompositorLabelTests.swift`

**Interfaces:**
- Consumes: `ClipLabel.hasBackground` (Task 5)
- Produces:
  - `AVFoundationCompositionService.makeCustomLabelLayers(label:placedRect:renderSize:) -> [CALayer]` — `private static` 에서 **internal `static`** 으로 승격(테스트 도달용). `#if canImport(UIKit)` 안에 있다.
  - 반환 규약: `hasBackground == true` → `[bgLayer, textLayer]`, `false` → `[textLayer]`. 두 경우 `textLayer.frame` 은 동일하다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`Modules/CompositionService/Tests/CustomLabelLayoutTests.swift` 의 마지막 `}` 직전에 추가하고,
파일 상단 import 에 `import QuartzCore` 를 더한다(`CALayer`/`CATextLayer` 용).

```swift
    // MARK: - 배경 박스 ON/OFF (ClipLabel.hasBackground)

    #if canImport(UIKit)
    /// 배경 ON: [배경 박스, 텍스트] 2 레이어. 박스는 흰 면 + 검정 테두리, 글자는 검정.
    @Test func customLabelLayers_BackgroundOn_BoxAndBlackText() {
        let label = ClipLabel(text: "제주 바다", sizeFraction: 0.10,
                              position: CGPoint(x: 0.5, y: 0.5), hasBackground: true)
        let layers = AVFoundationCompositionService.makeCustomLabelLayers(
            label: label,
            placedRect: CGRect(x: 0, y: 0, width: 1080, height: 1920),
            renderSize: CGSize(width: 1080, height: 1920)
        )
        #expect(layers.count == 2, "배경 ON 은 [bg, text] 2 레이어: \(layers.count)")
        #expect(layers[0].backgroundColor == UIColor.white.cgColor, "박스 면은 흰색")
        #expect(layers[0].borderColor == UIColor.black.cgColor, "박스 테두리는 검정")
        #expect(layers[0].borderWidth > 0, "테두리 두께 \(layers[0].borderWidth)")

        let text = layers[1] as? CATextLayer
        let attrs = (text?.string as? NSAttributedString)?.attributes(at: 0, effectiveRange: nil)
        #expect(attrs?[.foregroundColor] as? UIColor == UIColor.black, "글자는 검정")
    }

    /// 배경 OFF: 텍스트 1 레이어만. 글자는 흰색, 장식(그림자·테두리) 없음.
    @Test func customLabelLayers_BackgroundOff_WhiteTextOnly() {
        let label = ClipLabel(text: "제주 바다", sizeFraction: 0.10,
                              position: CGPoint(x: 0.5, y: 0.5), hasBackground: false)
        let layers = AVFoundationCompositionService.makeCustomLabelLayers(
            label: label,
            placedRect: CGRect(x: 0, y: 0, width: 1080, height: 1920),
            renderSize: CGSize(width: 1080, height: 1920)
        )
        #expect(layers.count == 1, "배경 OFF 는 텍스트 1 레이어: \(layers.count)")

        let text = layers[0] as? CATextLayer
        let attrs = (text?.string as? NSAttributedString)?.attributes(at: 0, effectiveRange: nil)
        #expect(attrs?[.foregroundColor] as? UIColor == UIColor.white, "글자는 흰색")
        #expect(text?.shadowOpacity == 0, "장식 없음 — 그림자 0: \(text?.shadowOpacity ?? -1)")
    }

    /// 토글이 글자 위치를 움직이지 않는다 — 패딩을 유지하므로 textLayer.frame 이 동일해야 한다.
    /// (`ClipLabel.hasBackground` doc 의 규칙을 픽셀 기하로 잠근다.)
    @Test func customLabelLayers_ToggleKeepsTextFrame() {
        let placed = CGRect(x: 0, y: 0, width: 1080, height: 1920)
        let render = CGSize(width: 1080, height: 1920)
        let on = AVFoundationCompositionService.makeCustomLabelLayers(
            label: ClipLabel(text: "제주 바다", sizeFraction: 0.12,
                             position: CGPoint(x: 0.3, y: 0.7), hasBackground: true),
            placedRect: placed, renderSize: render
        )
        let off = AVFoundationCompositionService.makeCustomLabelLayers(
            label: ClipLabel(text: "제주 바다", sizeFraction: 0.12,
                             position: CGPoint(x: 0.3, y: 0.7), hasBackground: false),
            placedRect: placed, renderSize: render
        )
        let onText = on.last!.frame
        let offText = off.last!.frame
        #expect(onText == offText, "배경 토글이 글자 프레임을 바꿈: ON \(onText) vs OFF \(offText)")
    }
    #endif
```

- [ ] **Step 2: 테스트가 실패하는 것을 확인한다**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme CompositionService \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CompositionServiceTests/CustomLabelLayoutTests test 2>&1 | tail -20
```
기대: 컴파일 실패 — `makeCustomLabelLayers` 가 `private` 이라 접근 불가

- [ ] **Step 3: `makeCustomLabelLayers` 를 교체한다**

`Modules/CompositionService/Sources/CompositionService.swift` 의
`/// 박스 자막 라벨 한 개를 그릴 레이어들([배경 박스, 텍스트]).` doc 부터
`return [bgLayer, textLayer]` 까지(약 `:464-505`)를 아래로 교체:

```swift
    /// 박스 자막 라벨 한 개를 그릴 레이어들.
    ///
    /// - `label.hasBackground == true`  → `[배경 박스, 텍스트]` (흰 면 · 검정 테두리 · 검정 글씨)
    /// - `label.hasBackground == false` → `[텍스트]` (흰 글씨, 장식 없음)
    ///
    /// **두 경우 `textLayer.frame` 은 동일하다** — 패딩을 유지하므로 토글이 위치를 움직이지 않는다.
    /// 프리뷰의 `BoxSubtitleStyle`/`ClipLabelBoxPalette` 가 같은 규칙·같은 색을 쓴다(WYSIWYG).
    /// `internal`(테스트 도달용) — `CustomLabelLayoutTests` 가 레이어 구성과 글자 프레임을 잠근다.
    static func makeCustomLabelLayers(
        label: ClipLabel,
        placedRect: CGRect,
        renderSize: CGSize
    ) -> [CALayer] {
        let fontSize = max(8, label.clampedSizeFraction * placedRect.height)
        let textSize = measureCustomText(label.text, fontSize: fontSize)
        let origin = customLabelOrigin(placedRect: placedRect, position: label.position, textSize: textSize, renderSize: renderSize)

        let textLayer = CATextLayer()
        textLayer.string = NSAttributedString(
            string: label.text,
            attributes: [
                .font: overlayCustomUIFont(fontSize: fontSize),
                // 흰 박스 위면 검정, 영상 위에 직접 올리면 흰색. 프리뷰의 ClipLabelBoxPalette 와 같은 규칙.
                .foregroundColor: label.hasBackground ? UIColor.black : UIColor.white,
                .kern: ClipLabel.BoxStyle.letterSpacing(for: fontSize),
            ]
        )
        textLayer.contentsScale = 2.0
        textLayer.isWrapped = false
        textLayer.alignmentMode = .center
        textLayer.frame = CGRect(origin: origin, size: textSize)
        textLayer.opacity = 1

        // 배경 OFF: 장식 없이 텍스트만. (패딩은 계산에 쓰지 않으므로 frame 은 위와 동일하게 유지된다.)
        guard label.hasBackground else { return [textLayer] }

        // 흰 배경 + 검정 테두리 박스. (프리뷰 ClipLabelText 와 동일한 ClipLabel.BoxStyle 사용)
        let padX = fontSize * ClipLabel.BoxStyle.horizontalPaddingFraction
        let padY = fontSize * ClipLabel.BoxStyle.verticalPaddingFraction
        let bgLayer = CALayer()
        bgLayer.frame = CGRect(
            x: origin.x - padX,
            y: origin.y - padY,
            width: textSize.width + padX * 2,
            height: textSize.height + padY * 2
        )
        bgLayer.backgroundColor = UIColor.white.cgColor
        bgLayer.borderColor = UIColor.black.cgColor
        bgLayer.borderWidth = fontSize * ClipLabel.BoxStyle.borderWidthFraction
        bgLayer.opacity = 1

        return [bgLayer, textLayer]
    }
```

- [ ] **Step 4: 테스트가 통과하는 것을 확인한다**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme CompositionService \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CompositionServiceTests/CustomLabelLayoutTests test 2>&1 | tail -20
```
기대: `TEST SUCCEEDED`

- [ ] **Step 5: 배경 OFF 픽셀 테스트를 추가한다**

`Modules/CompositionService/Tests/CompositorLabelTests.swift` 의
`testCompositor_OverlaysLabel_WhiteBoxVisible_AndAutoLabelsAtBottomRight` 뒤,
`// MARK: - Export + sample` 앞에 추가:

```swift
    /// 배경 OFF 라벨: 흰 **박스**가 아니라 흰 **글자**만 올라간다.
    /// 회색 영상 중앙 200×200 영역의 near-white 픽셀 수가
    /// 배경 ON 보다 확연히 적어야 한다(박스 면적이 사라졌으므로).
    @Test func testCompositor_BackgroundOffLabel_NoWhiteBox() async throws {
        let srcURL = try await makeSolidGrayVideo(width: 640, height: 360, seconds: 0.5, fps: 24)
        defer { try? FileManager.default.removeItem(at: srcURL) }

        let clip = Clip(
            kind: .video,
            capturedAt: Date(),
            duration: 0.5,
            preset: .jejuSea,
            thumbnailData: nil,
            videoURL: srcURL,
            displaySize: CGSize(width: 640, height: 360)
        )

        let on = ClipLabel(text: "TEST", sizeFraction: 0.12,
                           position: CGPoint(x: 0.5, y: 0.5), hasBackground: true)
        let off = ClipLabel(text: "TEST", sizeFraction: 0.12,
                            position: CGPoint(x: 0.5, y: 0.5), hasBackground: false)

        let samplerOn = try await exportAndSample(clip: clip, clipLabels: [clip.id: on])
        let samplerOff = try await exportAndSample(clip: clip, clipLabels: [clip.id: off])

        let region = CGRect(x: 440, y: 860, width: 200, height: 200)
        expectClearOfAutoLabelStamp(
            [(Int(region.minX), Int(region.minY)), (Int(region.maxX), Int(region.maxY))],
            capturedAt: clip.capturedAt
        )
        let whiteOn = samplerOn.countNearWhite(in: region, threshold: 220)
        let whiteOff = samplerOff.countNearWhite(in: region, threshold: 220)

        print("[CompositorLabelTests] whiteOn=\(whiteOn) whiteOff=\(whiteOff)")

        // 흰 글자만 남으므로 near-white 픽셀은 있지만(글리프), 박스 면적만큼은 없다.
        #expect(whiteOff > 0, "배경 OFF 도 흰 글자는 보여야 함: \(whiteOff)")
        #expect(whiteOff < whiteOn / 2,
                "배경 OFF 는 박스 면적만큼 흰 픽셀이 줄어야 함: on=\(whiteOn) off=\(whiteOff)")
    }
```

- [ ] **Step 6: 픽셀 테스트를 실행한다**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme CompositionService \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CompositionServiceTests/CompositorLabelTests test 2>&1 | tail -30
```
기대: `TEST SUCCEEDED`. FAIL 이면 `print` 의 `whiteOn`/`whiteOff` 실측값을 보고
임계(`whiteOn / 2`)를 실측 기반으로 조정한다 — **추측으로 완화하지 말고 찍힌 값으로 판단한다.**

- [ ] **Step 7: 커밋**

```bash
./scripts/design-lint.sh
git add Modules/CompositionService/
git commit -m "$(cat <<'EOF'
✨ feat: 합성 박스 자막에 배경 ON/OFF 분기

- hasBackground == false 면 bgLayer 를 만들지 않고 글자색을 흰색으로 — 장식 없음.
- textLayer.frame 은 ON/OFF 동일(패딩 유지) → 토글이 라벨 위치를 안 움직인다.
  이 동일성을 CustomLabelLayoutTests 가 잠근다.
- makeCustomLabelLayers 를 private → internal 로(테스트 도달). 픽셀 차분 테스트도 추가.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: 프리뷰 렌더 분기 + design-lint 예외 정리

라벨 박스의 **색 리터럴을 `ClipLabelText.swift` 한 파일로 모은다.** `LabelEditorView.swift` 는
흰색 규칙(4) 예외에 없으므로, 거기에 흰 글자 리터럴을 넣으면 규칙이 깨진다. 대신 팔레트 헬퍼를
호출하게 하면 `LabelEditorView` 에는 흰색도 검정도 남지 않고, 결과로 규칙 5의 예외가 죽은
예외가 되므로 그것도 제거한다.

**Files:**
- Modify: `Modules/TimelineFeature/Sources/Components/ClipLabelText.swift`
- Modify: `Modules/TimelineFeature/Sources/LabelEditorView.swift:225` (`boxSubtitleStyle` 호출부만)
- Create: `Modules/TimelineFeature/Tests/ClipLabelBoxPaletteTests.swift`
- Modify: `scripts/design-lint.sh:88-99` (규칙 5 예외 목록 + 주석)

**Interfaces:**
- Consumes: `ClipLabel.hasBackground` (Task 5)
- Produces:
  - `ClipLabelBoxPalette.foreground(hasBackground: Bool, placeholder: Bool) -> Color`
  - `ClipLabelBoxPalette.boxFill: Color` · `ClipLabelBoxPalette.boxBorder: Color`
  - `View.boxSubtitleStyle(fontPx: CGFloat, hasBackground: Bool) -> some View` — **시그니처가 바뀐다**(`hasBackground` 추가). Task 8이 이 새 시그니처를 쓴다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

새 파일 `Modules/TimelineFeature/Tests/ClipLabelBoxPaletteTests.swift`:

```swift
import SwiftUI
import Testing
@testable import TimelineFeature

/// 박스 자막 색 팔레트가 합성(`CATextLayer`)과 같은 규칙을 쓰는지 값 수준에서 잠근다.
/// 합성 쪽 대응 가드는 `CompositionServiceTests/CustomLabelLayoutTests` 다 —
/// 두 렌더 경로가 색을 따로 결정하면 WYSIWYG 가 조용히 어긋난다.
struct ClipLabelBoxPaletteTests {

    /// 배경 ON: 흰 박스 위 검정 글씨.
    @Test func foregroundWithBackgroundIsBlack() {
        #expect(ClipLabelBoxPalette.foreground(hasBackground: true, placeholder: false) == Color.black)
    }

    /// 배경 OFF: 영상 위 직접이라 흰 글씨.
    @Test func foregroundWithoutBackgroundIsWhite() {
        #expect(ClipLabelBoxPalette.foreground(hasBackground: false, placeholder: false) == Color.white)
    }

    /// placeholder 는 같은 색의 50% — 배경 유무와 무관하게 같은 규칙.
    @Test func placeholderDimsSameBase() {
        #expect(ClipLabelBoxPalette.foreground(hasBackground: true, placeholder: true)
                == Color.black.opacity(0.5))
        #expect(ClipLabelBoxPalette.foreground(hasBackground: false, placeholder: true)
                == Color.white.opacity(0.5))
    }

    /// 박스 면·테두리 색은 합성(bgLayer)과 동일해야 한다.
    @Test func boxColorsMatchComposition() {
        #expect(ClipLabelBoxPalette.boxFill == Color.white)
        #expect(ClipLabelBoxPalette.boxBorder == Color.black)
    }
}
```

- [ ] **Step 2: 테스트가 실패하는 것을 확인한다**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme TimelineFeature \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:TimelineFeatureTests/ClipLabelBoxPaletteTests test 2>&1 | tail -20
```
기대: 컴파일 실패 — `cannot find 'ClipLabelBoxPalette' in scope`

- [ ] **Step 3: `ClipLabelText.swift` 를 아래 내용으로 전체 교체한다**

```swift
import SwiftUI
import UIKit
import Models
import DesignSystem

/// 박스 자막 색 팔레트.
///
/// **다크 토큰 적용 예외.** 이 색들은 합성(`CATextLayer`/`CALayer`)이 쓰는 `UIColor` 와
/// 픽셀 단위로 일치해야 하므로 역할 토큰(테마·Dynamic Type 따라 변함)을 쓸 수 없다.
/// `scripts/design-lint.sh` 규칙 4(흰색)·5(검정) 예외에 **이 파일만** 등록돼 있고,
/// 라벨 박스의 색 리터럴은 여기 한곳에만 둔다 — `LabelEditorView` 는 이 헬퍼를 호출해
/// 리터럴을 갖지 않는다(파일 단위 예외를 늘리지 않기 위함).
enum ClipLabelBoxPalette {
    /// 글자색. 배경 ON = 검정(흰 박스 위), OFF = 흰색(영상 위 직접).
    /// 합성 `makeCustomLabelLayers` 의 `foregroundColor` 분기와 같은 규칙이다.
    static func foreground(hasBackground: Bool, placeholder: Bool) -> Color {
        let base: Color = hasBackground ? .black : .white
        return placeholder ? base.opacity(0.5) : base
    }

    /// 배경 박스 면색 (합성 `bgLayer.backgroundColor`).
    static let boxFill = Color.white
    /// 배경 박스 테두리색 (합성 `bgLayer.borderColor`).
    static let boxBorder = Color.black
}

/// ClipLabel 한 개를 박스 자막 스타일로 그리는 공용 텍스트 뷰.
/// `label.hasBackground` 가 true 면 흰 배경·검정 글씨·검정 테두리, false 면 흰 글씨만.
/// 자막 에디터와 타임라인 미리보기가 공유한다. 위치/드래그는 호출 측 담당.
/// `fontPx` = 표시 박스 높이 × clampedSizeFraction.
/// 텍스트 박스를 합성(CATextLayer)과 동일한 UIFont 측정값·박스 스타일(ClipLabel.BoxStyle)로 고정해,
/// `.position` 중심 기준과 박스 외형을 영상 출력과 맞춘다.
struct ClipLabelText: View {
    let label: ClipLabel
    let fontPx: CGFloat
    var placeholder: Bool = false

    private var displayString: String { placeholder ? String(localized: "자막 입력") : label.text }

    /// 합성 measureCustomText 와 동일한 UIFont(시스템 light) 로 측정한 텍스트 크기.
    private var measuredSize: CGSize {
        let ui = UIFont.systemFont(ofSize: fontPx, weight: .light)
        let s = NSAttributedString(string: displayString, attributes: [
            .font: ui,
            .kern: ClipLabel.BoxStyle.letterSpacing(for: fontPx),
        ]).size()
        return CGSize(width: ceil(s.width), height: ceil(s.height))
    }

    private var styledText: some View {
        Text(displayString)
            // 다크 토큰 적용 예외: 합성(CATextLayer)과 동일한 UIFont(systemFont, ofSize: fontPx)로
            // 픽셀 일치해야 하므로 역할 토큰(krBody 삭제됨) 대신 직접 시스템 폰트를 쓴다.
            // `scripts/design-lint.sh` 규칙 1 예외에 이 파일이 등록돼 있다.
            .font(.system(size: fontPx, weight: .light))
            .tracking(ClipLabel.BoxStyle.letterSpacing(for: fontPx))
            .lineLimit(1)
            .fixedSize()
            .frame(width: measuredSize.width, height: measuredSize.height)
            .foregroundColor(ClipLabelBoxPalette.foreground(
                hasBackground: label.hasBackground, placeholder: placeholder
            ))
    }

    var body: some View {
        styledText.boxSubtitleStyle(fontPx: fontPx, hasBackground: label.hasBackground)
    }
}

/// 박스 자막 배경(흰 면 + 검정 테두리 + 패딩). 표시(ClipLabelText)와 인라인 편집(TextField)이 공유한다.
/// `hasBackground == false` 면 면·테두리를 그리지 않는다.
struct BoxSubtitleStyle: ViewModifier {
    let fontPx: CGFloat
    let hasBackground: Bool

    func body(content: Content) -> some View {
        content
            // 패딩은 배경 ON/OFF 에서 **동일**하다. 바뀌면 박스 크기가 달라져
            // ClipLabel.position(박스 중심) 역산이 어긋나고 토글마다 라벨이 움직인다.
            // 합성(makeCustomLabelLayers)도 같은 이유로 textLayer.frame 을 그대로 둔다.
            .padding(.horizontal, fontPx * ClipLabel.BoxStyle.horizontalPaddingFraction)
            .padding(.vertical, fontPx * ClipLabel.BoxStyle.verticalPaddingFraction)
            .background {
                if hasBackground {
                    Rectangle().fill(ClipLabelBoxPalette.boxFill)
                }
            }
            .overlay {
                if hasBackground {
                    Rectangle().strokeBorder(
                        ClipLabelBoxPalette.boxBorder,
                        lineWidth: fontPx * ClipLabel.BoxStyle.borderWidthFraction
                    )
                }
            }
    }
}

extension View {
    /// 박스 자막 스타일을 적용한다. `hasBackground == false` 면 패딩만 적용하고 면·테두리는 생략.
    func boxSubtitleStyle(fontPx: CGFloat, hasBackground: Bool) -> some View {
        modifier(BoxSubtitleStyle(fontPx: fontPx, hasBackground: hasBackground))
    }
}
```

- [ ] **Step 4: `LabelEditorView` 의 호출부를 새 시그니처에 맞춘다**

`Modules/TimelineFeature/Sources/LabelEditorView.swift:225` 의

```swift
            .boxSubtitleStyle(fontPx: fontPx)
```
을

```swift
            .boxSubtitleStyle(fontPx: fontPx, hasBackground: label.hasBackground)
```
으로 바꾼다. (이 파일의 나머지 재구성은 Task 8에서 한다. 여기서는 컴파일만 맞춘다 —
`.foregroundColor(.black)` 리터럴 2곳도 Task 8에서 팔레트 호출로 바뀐다.)

- [ ] **Step 5: 테스트가 통과하고 빌드가 되는지 확인한다**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme TimelineFeature \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:TimelineFeatureTests test 2>&1 | tail -20
```
기대: `TEST SUCCEEDED`

- [ ] **Step 6: design-lint 를 실행해 현재 상태를 확인한다**

```bash
./scripts/design-lint.sh
```
기대: 6규칙 전부 0건. (`LabelEditorView.swift` 는 아직 `.black` 리터럴을 갖고 있고
규칙 5 예외에 등록돼 있으므로 통과한다. 예외 제거는 Task 8 에서 리터럴이 사라진 뒤에 한다.)

- [ ] **Step 7: 커밋**

```bash
git add Modules/TimelineFeature/Sources/Components/ClipLabelText.swift \
        Modules/TimelineFeature/Sources/LabelEditorView.swift \
        Modules/TimelineFeature/Tests/ClipLabelBoxPaletteTests.swift
git commit -m "$(cat <<'EOF'
✨ feat: 프리뷰 박스 자막에 배경 ON/OFF 분기 + 색 리터럴을 한 파일로 집약

- ClipLabelBoxPalette 신설 — 라벨 박스의 흰색/검정 리터럴을 ClipLabelText.swift 하나에만 둔다.
  LabelEditorView 는 헬퍼를 호출해 리터럴을 갖지 않으므로 design-lint 파일 예외를 늘리지 않는다.
- BoxSubtitleStyle 이 hasBackground 를 받아 면·테두리만 생략. 패딩은 ON/OFF 동일.
- 합성과 같은 색 규칙인지 값 수준으로 잠그는 테스트 추가.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: `LabelEditorView` 2스텝 재구성

3-phase 상태 머신(`idle`/`editing`/`adjusting`)을 2-step(`text`/`style`)으로 줄이고,
스텝 2 하단에 배경 토글을 붙인다.

**Files:**
- Modify: `Modules/TimelineFeature/Sources/LabelEditorView.swift`
- Modify: `scripts/design-lint.sh` (규칙 5 예외에서 `LabelEditorView.swift` 제거)
- Modify: `ChalNa/UITests/LabelEditorUITests.swift`

**Interfaces:**
- Consumes: `ClipLabelBoxPalette.foreground(hasBackground:placeholder:)`, `View.boxSubtitleStyle(fontPx:hasBackground:)` (Task 7); `ClipLabel.hasBackground` (Task 5)
- Produces: 없음 (뷰 내부). `LabelEditorView.init(clip:rotation:transform:initialLabel:onCommit:onCancel:)` 시그니처는 **바뀌지 않는다** — `TimelineView` 호출부는 그대로다.

- [ ] **Step 1: 타입 doc 과 상태 프로퍼티를 교체한다**

`Modules/TimelineFeature/Sources/LabelEditorView.swift` 의 `:5-14` doc 블록을:

```swift
/// 전체화면 라벨 에디터. 사진은 상단 고정·최대 크기로 두고, 그 위에서 라벨을 배치한다.
///
/// **2스텝 플로우** (`Step`):
/// - `.text`  : 키보드 ↑. 인라인 TextField 로 문구만 입력한다. 라벨은 가시영역(상단바~키보드)
///              높이 정중앙으로 띄운다. 하단 컨트롤 없음. `[다음]` → `.style`.
/// - `.style` : 키보드 ↓. 라벨을 드래그로 자유 배치(중심 정렬 가이드 + 스냅)하고,
///              하단에서 배경 ON/OFF · 크기를 정한다. `[‹]`/라벨 탭 → `.text`, `[저장]` → 커밋.
///
/// 진입은 기존 라벨 재편집이어도 **항상 `.text` 부터**다. 문구를 비운 채 저장하면
/// `ClipLabel.isVisible == false` 로 라벨 없음이 되며, 이것이 라벨을 지우는 유일한 경로다
/// (그래서 `[다음]` 을 비활성화하지 않는다).
///
/// 배치는 box-local **좌상단 코너 `anchorCorner`(point)** 를 단일 출처로 삼고(요구: leading/top 고정·우하 확장),
/// 저장 모델 `ClipLabel.position`(중심)은 커밋 시 코너에서 역산한다 → 합성/미리보기와 WYSIWYG 유지.
```

그리고 `:24-36` 의 상태 선언 중 `phase` 와 관련된 것을 교체한다.
`@State private var phase: Phase = .idle` 을 삭제하고 그 자리에:

```swift
    @State private var step: Step = .text
    /// 드래그 진행 중 여부 — 정렬 가이드 표시 조건.
    @State private var isDragging = false
```

`private enum Phase { case idle, editing, adjusting }` 를 삭제하고:

```swift
    private enum Step { case text, style }
```

- [ ] **Step 2: `body` 의 phase 잔재를 정리한다**

`:57-77` 의 `body` 에서 `.safeAreaInset(edge: .bottom) { sizeControls }` 를
`.safeAreaInset(edge: .bottom) { bottomControls }` 로 바꾸고,
아래 `onChange(of: focused)` 블록 3줄을 **삭제**한다(포커스 상실이 스텝을 바꾸면 안 된다):

```swift
        .onChange(of: focused) { _, isFocused in
            if !isFocused, phase == .editing { phase = .idle }
        }
```

`body` 의 나머지(`.ignoresSafeArea(.keyboard, edges: .bottom)`, `.chalNaScreen()`,
`.contentShape(Rectangle())`, `.onTapGesture { backgroundTapped() }`,
`.onAppear { keyboard.start() }`, `.onDisappear { keyboard.stop() }`)는 그대로 둔다.

- [ ] **Step 3: `topBar` 를 스텝별로 분기한다**

`:81-88` 의 `topBar` 를 교체:

```swift
    @ViewBuilder
    private var topBar: some View {
        switch step {
        case .text:
            ChalNaNavBar(
                title: "라벨",
                leading: .close(action: onCancel),
                trailing: .text("다음") { goToStyle() },
                showsDivider: true
            )
        case .style:
            ChalNaNavBar(
                title: "라벨",
                leading: .back { goToText() },
                trailing: .text("저장") { onCommit(committedLabel()) },
                showsDivider: true
            )
        }
    }
```

- [ ] **Step 4: `labelLayer` / `displayCornerY` / `labelContent` 를 교체한다**

`:133-150` 의 `labelLayer` 안에서 `if phase == .adjusting { alignmentGuides(box: box) }` 를
`if step == .style && isDragging { alignmentGuides(box: box) }` 로 바꾸고,
`.animation(phase == .adjusting ? nil : ChalNaMotion.standard, value: floatDeltaY)` 를
아래로 바꾼다 (`.style` 에서는 `floatDeltaY` 가 항상 0 이라 애니메이션이 발화하지 않는다):

```swift
                .animation(ChalNaMotion.standard, value: floatDeltaY)
```

`:169-173` 의 `displayCornerY` guard 를 교체:

```swift
    /// 표시용 코너 Y. `.text` 스텝에서는 가시영역(상단바~키보드) 높이의 정중앙으로 올린다.
    private func displayCornerY(box: CGSize, boxTopGlobalY: CGFloat, padded: CGSize) -> CGFloat {
        guard step == .text, keyboard.height > 0 else { return anchorCorner.y }
        let visibleCenterLocalY = (keyboard.topY - boxTopGlobalY) / 2   // 박스 상단=상단바 아래 기준
        return visibleCenterLocalY - padded.height / 2
    }
```

`:175-190` 의 `labelContent` 를 교체 — `boxTopGlobalY` 인자는 더 이상 필요 없다
(`.style` 에는 플로팅이 없으므로 드래그 시작점이 곧 `anchorCorner` 다):

```swift
    @ViewBuilder
    private func labelContent(fontPx: CGFloat, padded: CGSize, box: CGSize) -> some View {
        switch step {
        case .text:
            inlineEditor(fontPx: fontPx)
        case .style:
            let isEmpty = label.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ClipLabelText(label: label, fontPx: fontPx, placeholder: isEmpty)
                .overlay(selectionFrame)
                .contentShape(Rectangle())
                .onTapGesture { goToText() }
                .gesture(dragGesture(box: box, padded: padded))
        }
    }
```

`labelLayer` 안의 호출부도 인자에 맞춰 바꾼다:

```swift
            labelContent(fontPx: renderedFontPx, padded: padded, box: box)
```

- [ ] **Step 5: `inlineEditor` 의 색 리터럴을 팔레트 호출로 바꾼다**

`:192-200` 의 함수 doc 을 교체(더 이상 검정 리터럴이 없다):

```swift
    /// 편집 상태: 같은 박스 스타일의 인라인 TextField.
    ///
    /// **다크 토큰 적용 예외(폰트만).** 라벨 박스는 영상 출력(`CATextLayer`)과 픽셀 일치해야
    /// 하므로 Dynamic Type 을 따르는 역할 토큰이 아니라 `.font(.system(size: fontPx, ...))` 를
    /// 직접 쓴다 — `scripts/design-lint.sh` 규칙 1 예외에 이 파일이 등록돼 있다.
    /// 색은 리터럴을 두지 않고 `ClipLabelBoxPalette`(ClipLabelText.swift)를 호출한다.
```

본문에서 `.foregroundColor(.black)` 을:

```swift
            .foregroundColor(ClipLabelBoxPalette.foreground(
                hasBackground: label.hasBackground, placeholder: false
            ))
```

placeholder 오버레이의 `.foregroundColor(.black.opacity(0.5))` 를:

```swift
                        .foregroundColor(ClipLabelBoxPalette.foreground(
                            hasBackground: label.hasBackground, placeholder: true
                        ))
```

(Task 7 에서 이미 바꾼 `.boxSubtitleStyle(fontPx: fontPx, hasBackground: label.hasBackground)` 는 그대로.)

- [ ] **Step 6: `selectionFrame` 과 하단 컨트롤을 교체한다**

`:229-235` 의 `selectionFrame` 에서 `.opacity(phase == .adjusting ? 1 : 0)` 를
`.opacity(step == .style ? 1 : 0)` 으로 바꾼다.

`:252-283` 의 `sizeControls` 전체를 아래 `bottomControls` 로 교체한다.
키보드 오프셋·이중 애니메이션이 사라진다 — 컨트롤이 `.style` 에만 존재하고 그때 키보드는 내려가 있다.

```swift
    // MARK: - Bottom controls (스텝 2 전용)

    @ViewBuilder
    private var bottomControls: some View {
        if step == .style {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("배경")
                        .font(ChalNaTypography.label)
                        .foregroundColor(ChalNaColor.textSecondary)
                    Spacer(minLength: 0)
                    Toggle("", isOn: $label.hasBackground)
                        .labelsHidden()
                        .tint(ChalNaColor.accentFill)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("크기")
                        .font(ChalNaTypography.label)
                        .foregroundColor(ChalNaColor.textSecondary)
                    ChalNaSlider(
                        // ChalNaSlider 는 Binding<Double> — sizeFraction(CGFloat)을 브리징한다.
                        value: Binding(
                            get: { Double(label.sizeFraction) },
                            set: { label.sizeFraction = CGFloat($0) }
                        ),
                        range: Double(ClipLabel.minSizeFraction)...Double(ClipLabel.maxSizeFraction),
                        step: nil,
                        onEditingChanged: { editing in
                            // 드래그 종료 시 현재 크기로 베이크 → scaleEffect=1 로 글자를 선명하게 재렌더.
                            if !editing { renderedSizeFraction = label.clampedSizeFraction }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(ChalNaColor.bg.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) {
                Rectangle().fill(ChalNaColor.border).frame(height: 1)
            }
        }
    }
```

- [ ] **Step 7: 제스처와 스텝 전이를 교체한다**

`:287-343` 의 `dragGesture` / `startEditing` / `endAdjusting` / `backgroundTapped` 를 아래로 교체
(`applyDrag` 는 그대로 둔다):

```swift
    private func dragGesture(box: CGSize, padded: CGSize) -> some Gesture {
        // minimumDistance 16: 같은 요소에 탭(→ 문구 스텝)과 드래그(위치 조정)가 함께 걸려 있어
        // 구분이 필요하다. 짧은 제스처가 위치 조정으로 오인되는 것을 줄인다.
        DragGesture(minimumDistance: 16, coordinateSpace: .global)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragBaseCorner = anchorCorner
                }
                applyDrag(
                    proposed: CGPoint(x: dragBaseCorner.x + value.translation.width,
                                      y: dragBaseCorner.y + value.translation.height),
                    box: box, padded: padded
                )
            }
            .onEnded { _ in
                isDragging = false
                showVGuide = false
                showHGuide = false
            }
    }
```

`applyDrag` 뒤에 스텝 전이 헬퍼를 넣는다:

```swift
    private func goToStyle() {
        focused = false
        step = .style
    }

    private func goToText() {
        step = .text
        focused = true
    }

    /// 라벨 외 영역 탭. `.text` 에서는 키보드만 내린다(스텝은 유지 — 라벨을 다시 탭하면 재포커스).
    /// `.style` 에서는 할 일이 없다.
    private func backgroundTapped() {
        if step == .text { focused = false }
    }
```

- [ ] **Step 8: `reflow` 의 최초 진입 처리를 교체한다**

`:352-360` 의 `guard didInit else { ... }` 블록에서
`if !label.isVisible { startEditing() }` 줄을 아래로 바꾼다
(빈 라벨뿐 아니라 **항상** 문구 스텝에서 시작한다):

```swift
            didInit = true
            // 진입은 항상 문구 스텝(`step` 기본값 `.text`)이다 — 기존 라벨 재편집도 마찬가지.
            focused = true
            return
```

- [ ] **Step 9: 빌드하고 `phase` 잔재가 없는지 확인한다**

```bash
grep -n "phase\|Phase\|startEditing\|endAdjusting\|sizeControls" Modules/TimelineFeature/Sources/LabelEditorView.swift \
  && echo "!! 잔재 남음" || echo "OK: 잔재 없음"
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -20
```
기대: `OK: 잔재 없음` + `BUILD SUCCEEDED`

- [ ] **Step 10: 죽은 예외가 된 design-lint 규칙 5 항목을 제거한다**

먼저 리터럴이 실제로 사라졌는지 확인한다:

```bash
grep -nE '(Color\.black|\.black\b|Color\(white: *0(\b|\.)|UIColor\.black|UIColor\(white: *0(\b|\.)))' \
  Modules/TimelineFeature/Sources/LabelEditorView.swift \
  && echo "!! 아직 검정 리터럴 있음 — 예외를 남겨야 한다" || echo "OK: 검정 리터럴 없음"
```

`OK` 면 `scripts/design-lint.sh` 의 규칙 5 주석 중
`#    LabelEditorView 는 검정 쪽만 실사용이라 여기 등록한다).` 문장을 아래로 교체:

```
#    검정 하드코딩은 규칙 4처럼 아무 파일에서나 써도 5개 규칙이 전부 그린으로 남는다.
#    예외 대상은 규칙 4와 동일한 "영상 출력 픽셀 일치" 부류:
#    CompositionService(라벨 전경·테두리) · ClipLabelText(박스 자막의 검은 글자·검은 테두리가
#    CATextLayer 출력과 픽셀 일치해야 한다).
#    LabelEditorView.swift 는 라벨 2스텝 재구성에서 색 결정을 ClipLabelBoxPalette
#    (ClipLabelText.swift)로 옮기면서 검정 리터럴이 사라져 예외에서 제거했다 —
#    매치 없는 예외는 그 파일에 새로 들어오는 진짜 위반을 영구히 가린다.
```

그리고 `check "검정 하드코딩" ...` 인자 목록에서 마지막 줄
`'TimelineFeature/Sources/LabelEditorView.swift'` 를 삭제하고, 그 앞 줄의
`\` 연속 표시를 지워 목록을 닫는다:

```bash
check "검정 하드코딩" '(Color\.black|\.black\b|Color\(white: *0(\b|\.)|UIColor\.black|UIColor\(white: *0(\b|\.))' \
  'DesignSystem/Sources/Tokens/' \
  'CompositionService/Sources/CompositionService.swift' \
  'TimelineFeature/Sources/Components/ClipLabelText.swift'
```

- [ ] **Step 11: design-lint 가 6규칙 0건인지 확인한다**

```bash
./scripts/design-lint.sh
```
기대: 6규칙 전부 0건, 종료 코드 0. 실패하면 어떤 파일의 어떤 줄인지 출력에서 확인해 고친다 —
예외를 추가해 넘기지 않는다.

- [ ] **Step 12: 라벨 UI 테스트를 2스텝 플로우로 교체한다**

`ChalNa/UITests/LabelEditorUITests.swift` 의 **클래스 doc 은 그대로 보존한다** —
`print` 계측이 UI 테스트에서 무효하다는 정정 기록과 키보드 알림 실측값은 다음 사람이 같은
함정에 빠지는 것을 막는 유일한 기록이다.

첫 테스트 `testLabelEditor_KeyboardUp_ControlsRemainReachable` 을 아래로 교체한다
(`navigateToLabelEditor` 등 나머지 헬퍼·테스트는 그대로 둔다):

```swift
    /// 스텝 1(문구) 진입 → `[다음]` → 스텝 2(스타일) 컨트롤 도달성 → `[‹]` 로 복귀.
    ///
    /// 클래스 doc 의 계측 정정 기록 참고: 키보드 알림은 실제로 발생하고 `keyboard.height` 도
    /// 실측값(SE 260pt / 17 계열 335pt)에 도달한다. 다만 소프트 키보드 그래픽은 스크린샷에
    /// 나타나지 않고, `XCUIElement.frame` 으로 정확한 상승폭(pt)을 재는 것은 불안정하다 —
    /// 그래서 수치 assert 대신 도달성(exists/isHittable) assert 를 쓴다.
    func testLabelEditor_TwoStepFlow_ControlsReachable() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CHALNA_APP_MODE"] = "devMock"
        app.launchArguments += ["-AppleLanguages", "(ko)"]
        app.launch()

        navigateToLabelEditor(app)

        // ── 스텝 1: 문구. 진입은 항상 문구 스텝이며 키보드가 올라와 있어야 한다.
        let textField = app.textFields.firstMatch
        XCTAssertTrue(textField.waitForExistence(timeout: 10), "라벨 인라인 TextField")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "스텝 1 에서 키보드가 올라오지 않음")

        XCTContext.runActivity(
            named: "키보드 알림 실측 정정: keyboardWillChangeFrameNotification 발생 확인됨(SE 260pt/17계열 335pt) — Task 16 잔여 질문 해소, 최초 'not captured' 결론은 계측 채널 오류였음"
        ) { _ in }

        // 스텝 1 에는 크기 슬라이더·배경 토글이 없어야 한다(문구 입력에만 집중).
        XCTAssertFalse(app.sliders.firstMatch.exists, "스텝 1 에 크기 슬라이더가 있으면 안 됨")
        XCTAssertFalse(app.switches.firstMatch.exists, "스텝 1 에 배경 토글이 있으면 안 됨")

        textField.typeText("제주 바다")

        let next = app.buttons["다음"].firstMatch
        XCTAssertTrue(next.exists, "스텝 1 에 다음 버튼이 없음")
        XCTAssertTrue(next.isHittable, "키보드 ↑ 상태에서 다음 버튼을 탭할 수 없음")
        let close = app.buttons["닫기"].firstMatch
        XCTAssertTrue(close.exists && close.isHittable, "키보드 ↑ 상태에서 닫기 버튼 도달 불가")

        // ── 스텝 2: 스타일. 키보드가 내려가고 배경 토글 + 크기 슬라이더가 나타난다.
        next.tap()

        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 5), "스텝 2 에 크기 슬라이더가 없음")
        XCTAssertTrue(slider.isHittable, "스텝 2 에서 크기 슬라이더를 탭할 수 없음")

        let backgroundToggle = app.switches.firstMatch
        XCTAssertTrue(backgroundToggle.exists, "스텝 2 에 배경 토글이 없음")
        XCTAssertTrue(backgroundToggle.isHittable, "스텝 2 에서 배경 토글을 탭할 수 없음")

        let save = app.buttons["저장"].firstMatch
        XCTAssertTrue(save.exists && save.isHittable, "스텝 2 에서 저장 버튼 도달 불가")

        // 배경을 끄고 켜도 화면이 유지되어야 한다(라벨이 사라지거나 크래시하지 않는다).
        backgroundToggle.tap()
        XCTAssertTrue(slider.isHittable, "배경 OFF 후 슬라이더 도달 불가")
        backgroundToggle.tap()

        // ── 스텝 1 복귀: 뒤로 버튼 → 키보드 다시 ↑
        let back = app.buttons["뒤로"].firstMatch
        XCTAssertTrue(back.exists, "스텝 2 에 뒤로 버튼이 없음")
        back.tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5), "스텝 1 복귀 실패")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "스텝 1 복귀 후 키보드가 올라오지 않음")
    }
```

> **접근성 라벨 확인 필수.** 위 테스트는 `app.buttons["닫기"]` · `app.buttons["뒤로"]` 를 쓴다.
> `ChalNaNavAction.close`/`.back` 이 실제로 어떤 `accessibilityLabel` 을 쓰는지
> `Modules/DesignSystem/Sources/Components/ChalNaNavAction.swift` 에서 확인하고, 다르면
> 그 값으로 바꾼다. 추측하지 말고 소스를 읽는다.

- [ ] **Step 13: 라벨 UI 테스트를 실행한다**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:ChalNaUITests/LabelEditorUITests test 2>&1 | tail -40
```
기대: `TEST SUCCEEDED`. Dynamic Type 상한 테스트도 같은 파일에 있으므로 함께 통과해야 한다 —
스텝 2 컨트롤 기준으로 실패하면 그 테스트의 대상 요소를 슬라이더/토글로 갱신한다.

- [ ] **Step 14: 커밋**

```bash
git add Modules/TimelineFeature/Sources/LabelEditorView.swift \
        scripts/design-lint.sh \
        ChalNa/UITests/LabelEditorUITests.swift
git commit -m "$(cat <<'EOF'
✨ feat: 라벨 에디터를 [문구] → [위치·배경·크기] 2스텝으로 재구성

- Phase(idle/editing/adjusting) 3개 → Step(text/style) 2개 + isDragging.
  포커스 상실이 스텝을 바꾸던 전이와 드래그로 편집→조정 넘어가던 전이를 제거.
- 진입은 기존 라벨 재편집이어도 항상 문구 스텝부터. 스텝 2 하단에 배경 토글 + 크기 슬라이더.
  컨트롤이 스텝 2에만 있으므로 키보드 오프셋·이중 애니메이션이 필요 없어졌다.
- 색 결정을 ClipLabelBoxPalette 로 옮겨 LabelEditorView 의 검정 리터럴이 사라졌고,
  죽은 예외가 된 design-lint 규칙 5 항목을 제거(매치 없는 예외는 진짜 위반을 가린다).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: 전체 검증 + CLAUDE.md 갱신

**Files:**
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: Task 1~8 전부
- Produces: 없음

- [ ] **Step 1: 전체 유닛 테스트를 돌려 실측값을 기록한다**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa-Workspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tee /tmp/chalna-test.log | tail -40
grep -E "Test Suite '.*Tests' passed|Executed [0-9]+ test" /tmp/chalna-test.log | tail -20
```
기대: `TEST SUCCEEDED`. **8스위트 각각의 케이스 수를 이 출력에서 실측해 적어둔다** —
계획서의 예측값을 쓰지 않는다.

- [ ] **Step 2: UI 테스트 3종을 돌린다**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:ChalNaUITests test 2>&1 | tail -40
```
기대: `TEST SUCCEEDED`. 사진 권한 알럿이 탭을 가로채면 `springboard` 처리가 필요하고,
권한 쿼터는 앱을 uninstall 해서 리셋한다.

- [ ] **Step 3: design-lint 를 실행한다**

```bash
./scripts/design-lint.sh
```
기대: 6규칙 전부 0건.

- [ ] **Step 4: 시뮬레이터에서 두 플로우를 눈으로 확인한다**

`ios-build-run` 서브에이전트에 위임하거나 직접:

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme "ChalNa Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
# 설치·실행 후 devMock 픽스처로: 조정 화면에서 핀치 인 → 검정 여백 확인,
# 라벨 화면에서 문구 입력 → [다음] → 배경 토글 OFF → 흰 글자 확인 → [저장]
```

- [ ] **Step 5: CLAUDE.md 를 갱신한다**

아래 4곳을 고친다.

(a) **"비디오 합성 원칙"** 첫 항목의
`**출력은 1080×1920(9:16 세로) 고정, 클립은 aspectFill 센터 크롭**이 기본(`ClipTransform.fill`, scale 하한 1.0 — 여백/블러 배경 없음)` 을:

```
- **출력은 1080×1920(9:16 세로) 고정.** 기본 프레이밍은 aspectFill 센터 크롭(`ClipTransform.fill`)이지만 **사용자 확대·축소·이동에 제약이 없다** — scale < 1 로 줄이거나 캔버스 밖으로 밀어낼 수 있고, 드러나는 여백은 **검정**이다(합성은 `ChalNaVideoCompositor` 의 불투명 검정 베이스, 프리뷰는 `ChalNaColor.canvas`). `ClipTransform.minScale`/`maxScale`(0.1 / 10)은 UX 한계가 아니라 **산술 안전 가드**이며 적용 지점은 `ClipTransform.sanitized` 하나다 — 프리뷰(`ClipFraming.resolvedRect`)와 export(`CompositionService.transform`)가 둘 다 이걸 경유한다(예전엔 export 만 clamp 하는 비대칭이 있었다). 과거의 `ClipFraming.clampedOffset`/`maxOffsetFraction` 은 삭제됐다 — identity 로 남기지 않은 이유는 아무것도 안 하는 clamp 가 호출부 독자에게 제약이 아직 있다고 잘못 알리기 때문이다. 배치 기하 SSOT 는 여전히 `ClipFraming`(Models)이고 프리뷰·조정 화면·export 가 공유한다(WYSIWYG). 사용자 크롭 조정은 `EditSession.transforms`.
```

(b) **"비디오 합성 원칙"** 에 박스 자막 항목을 추가한다(자동 라벨 항목들 뒤):

```
- **사용자 박스 자막(`ClipLabel`)의 스타일은 `hasBackground` 로 갈린다** — `true`(기본) = 흰 배경 + 검정 글씨 + 검정 테두리, `false` = 배경·테두리 없는 흰 글씨(장식 없음). **패딩은 ON/OFF 동일**하다: 배경을 지울 때 패딩까지 지우면 박스 크기가 달라져 `position`(박스 중심) 역산이 어긋나고 토글마다 라벨이 움직인다. 이 규칙을 프리뷰(`BoxSubtitleStyle`)와 합성(`makeCustomLabelLayers`)이 공유하고, `CustomLabelLayoutTests.customLabelLayers_ToggleKeepsTextFrame` 이 `textLayer.frame` 동일성으로 잠근다. 라벨 편집은 **`[문구 입력] → [위치·배경·크기]` 2스텝**이다(`LabelEditorView` 의 `Step.text`/`.style`) — 진입은 기존 라벨 재편집이어도 항상 문구 스텝부터이고, 문구를 비운 채 저장하는 것이 라벨을 지우는 유일한 경로다.
```

(c) **"다크 토큰 적용 예외"** 의 라벨 박스 항목을 교체:

```
- **라벨 박스 픽셀 일치** — `ClipLabelText.swift`(TimelineFeature). 화면 라벨이 합성(`CATextLayer`)의 `UIFont` 측정값·색과 픽셀 단위로 일치해야 해서, Dynamic Type 에 따라 스케일되는 역할 토큰을 쓸 수 없다. **박스 자막의 색 리터럴은 이 파일의 `ClipLabelBoxPalette` 한곳에만 둔다** — `LabelEditorView.swift` 는 이 헬퍼를 호출하므로 색 리터럴이 없고, 그래서 규칙 5(검정) 예외에서 **제거됐다**(폰트 규칙 1 예외는 `.font(.system(size: fontPx, ...))` 때문에 유지된다). 매치 없는 예외는 그 파일에 새로 들어오는 진짜 위반을 영구히 가린다.
```

(d) **"테스트"** 절의 케이스 수를 Step 1 의 실측값으로 갱신하고, 변동 사유를 한 줄 남긴다
(RubberBandTests 7 삭제 · ClipFraming clamp 7 삭제 · 신규 케이스 추가).

- [ ] **Step 6: 커밋**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
📝 docs: CLAUDE.md 에 자유 크롭 · 라벨 2스텝 반영

- 크롭 제약 제거(여백=검정, minScale/maxScale 는 산술 안전 가드, clampedOffset 삭제 근거).
- ClipLabel.hasBackground 와 패딩 동일 규칙, 라벨 2스텝 플로우.
- design-lint 규칙 5 예외에서 LabelEditorView 제거된 이유.
- 8스위트 케이스 수 실측값 갱신.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review 결과

**Spec coverage** — spec 각 절이 어느 태스크에 들어갔는지:

| Spec | Task |
|---|---|
| §3.1 `ClipTransform` | Task 1 |
| §3.2 `ClipFraming` clamp 삭제 | Task 3 |
| §3.3 `CompositionService.transform` | Task 3 |
| §3.4 컴포지터 doc 정정 | Task 4 |
| §3.5 `ClipAdjustView` | Task 2 |
| §3.6 `RubberBand` 고아 제거 | Task 2 |
| §4.1 `ClipLabel.hasBackground` | Task 5 |
| §4.2 패딩 유지 | Task 5(doc) · 6(합성 가드) · 7(프리뷰) |
| §4.3 렌더 분기 + design-lint | Task 6(합성) · 7(프리뷰) · 8(예외 제거) |
| §4.4 2스텝 상태 머신 | Task 8 |
| §4.5 `makeCustomLabelLayers` internal화 | Task 6 |
| §5.1 수정·삭제 테스트 | Task 1·2·3 |
| §5.2 신규 테스트 | Task 1·3·4·5·6·7 |
| §5.3 UI 테스트 | Task 2(크롭) · 8(라벨) |
| §5.4 회귀 기준선 실측 | Task 9 |
| §6 CLAUDE.md | Task 9 |

**Spec 이 놓쳤던 것 (계획에서 보강)**

1. **`CompositionTransformTests.testTransform_LandscapeOffsetAtLimit_RevealsSourceEdge` 가
   `ClipFraming.maxOffsetFraction` 을 호출한다.** spec §5.1 은 이 파일에서 2케이스만
   고친다고 했지만 실제로는 **3케이스**다 — 이 테스트는 삭제되는 함수를 부르므로 컴파일이
   깨진다. Task 3 Step 5(a) 에서 리터럴 유도값으로 교체한다.
2. **`PreviewExportContractTests` 의 두 clamp 테스트는 assertion 이 그대로 통과한다.**
   양쪽 경로가 같이 clamp 를 잃으므로 비교 결과가 여전히 같다. 즉 "수정"이 아니라
   이름·주석만 거짓이 되는 것이고, 실질 보강은 **축소(scale<1) 계약 케이스 추가**다.
   Task 3 Step 6 에 반영.
3. **Task 순서가 컴파일 가능성으로 정해졌다.** `maxOffsetFraction` 을 지우면
   `ClipAdjustView:226` 이 깨지므로 `ClipAdjustView` 정리(Task 2)가 `ClipFraming`
   삭제(Task 3)보다 **먼저** 와야 한다. spec 은 순서를 명시하지 않았다.
4. **Task 1 만으로 `testTransform_UserScaleBelowMin_ClampsToFill` 이 깨진다**(minScale
   완화만으로 0.5 가 통과). spec 은 이걸 §5.1 의 Task 3 급 변경으로 묶어뒀지만,
   태스크마다 그린을 유지하려면 Task 1 에서 고쳐야 한다.
5. **Task 4 의 픽셀 테스트는 첫 실행에서 PASS 한다**(characterization test). TDD 의
   red-green 이 아니라 회귀 가드이므로, 실패를 기대하지 말고 그 성격을 계획에 명시했다.

**Placeholder scan** — "적절히 처리", "TBD", "Task N과 유사" 없음. 모든 코드 스텝에 실제
코드 블록이 있고, 모든 검증 스텝에 실행 명령과 기대 출력이 있다. 단 Task 8 Step 12 의
접근성 라벨(`"닫기"`/`"뒤로"`)은 **소스를 읽어 확인하라는 지시**로 남겼다 — 추측값을
계획에 박는 것보다 안전하다.

**Type consistency** — `ClipTransform.sanitized`(Task 1 정의 → 2·3 사용),
`ClipLabel.hasBackground`(5 → 6·7·8), `ClipLabelBoxPalette.foreground(hasBackground:placeholder:)`
(7 → 8), `boxSubtitleStyle(fontPx:hasBackground:)`(7 정의 → 7 Step 4·8 사용),
`makeCustomLabelLayers(label:placedRect:renderSize:)`(6) — 이름·인자 레이블이 태스크 간 일치.
`labelContent(fontPx:padded:box:)` 는 Task 8 에서 `boxTopGlobalY` 인자를 떼면서
정의(Step 4)와 호출부(Step 4 후단) 양쪽을 같이 고치도록 명시.
