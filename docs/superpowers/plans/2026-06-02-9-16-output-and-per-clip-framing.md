# 9:16 고정 출력 + 클립별 프레이밍(맞춤/줌/팬) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** export 영상을 항상 9:16/1080×1920로 고정하고, 각 클립을 전용 풀스크린 화면에서 핀치 줌·드래그·회전으로 자유롭게 프레이밍(기본 맞춤, 여백은 블러 필)할 수 있게 한다.

**Architecture:** `Models` 에 값 타입 `ClipTransform`(scale·offset) 와 순수 기하 함수 `ClipFraming` 을 두어 **프리뷰·조정 화면·export 가 동일 계산을 공유(WYSIWYG 단일 진실원천)**. 편집 상태는 기존 회전/라벨과 동일하게 `EditSession` 에 싣고 MediaPicker→Timeline→Export 로 흐른다. 블러 배경은 기존 `AVVideoCompositionCoreAnimationTool` 의 `videoLayer` 아래에 클립별 정지 블러 레이어를 시간창 게이팅으로 삽입한다.

**Tech Stack:** Swift 6 · SwiftUI · TCA(StackState) · AVFoundation(AVMutableVideoComposition, CoreAnimationTool, CoreImage) · Swift Testing · Tuist.

> **빌드/테스트 명령** (반복 사용):
> - 생성: `tuist generate`
> - 빌드: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
> - 테스트(전체): `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
> - 단일 테스트: 위 test 명령에 `-only-testing:CompositionServiceTests/<TestType>/<testCase>` 추가
> - 시뮬레이터 시각 검증은 `ios-build-run` 서브에이전트에 위임(`ChalNa Dev` 스킴이면 권한 없이 fixture 미디어로 전체 플로우 확인 가능).

---

## File Structure

**신규 파일**
- `Modules/Models/Sources/ClipTransform.swift` — 클립별 사용자 변환 값 타입(scale·offset).
- `Modules/Models/Sources/ClipFraming.swift` — fit/clamp/resolvedRect 순수 기하(SSOT).
- `Modules/CompositionService/Tests/ClipFramingTests.swift` — ClipFraming 단위 테스트.
- `Modules/TimelineFeature/Sources/ClipAdjustFeature.swift` — 조정 화면 Reducer.
- `Modules/TimelineFeature/Sources/ClipAdjustView.swift` — 조정 화면 View(핀치/팬/회전/리셋).

**수정 파일**
- `Modules/CompositionService/Sources/CompositionService.swift` — renderSize 상수화, 고아 헬퍼 제거, `transform`/`placedRect` 의 ClipFraming 사용, `scales` 관통, 블러 배경.
- `Modules/CompositionService/Sources/CompositionClient.swift` — `export` 시그니처에 `scales`.
- `Modules/CompositionService/Tests/CompositionRenderSizeTests.swift` — 고정 상수 검증으로 재작성.
- `Modules/CompositionService/Tests/CompositionTransformTests.swift` — `framing:` 인자 추가 + 줌/팬 케이스.
- `Modules/AppCore/Sources/EditSession.swift` — `scales` 상태 + 접근자 + 초기화.
- `Modules/AppCore/Sources/AppRouter.swift` — `Route.clipAdjust`.
- `Modules/ExportFeature/Sources/ExportFeature.swift` — `startExport`/export 호출에 `scales`.
- `Modules/ExportFeature/Sources/ExportView.swift` — `session.scales` 전달, 커버 9:16 세로 교정.
- `Modules/FilmDetailFeature/Sources/FilmDetailView.swift` — 커버 비율 9:16.
- `Modules/TimelineFeature/Sources/Components/PreviewPanel.swift` — 9:16 + 블러 + transform 반영.
- `Modules/TimelineFeature/Sources/Components/EditToolbar.swift` — 회전 버튼 → 조정 버튼.
- `Modules/TimelineFeature/Sources/TimelineView.swift` — 조정 화면 push, 회전 로직 이동.
- `ChalNa/Sources/App/AppFeature.swift` — `Path.clipAdjust` + 액션 + 핸들러.
- `ChalNa/Sources/App/RootView.swift` — destination + 라우터 핸들러 배선.

> **컨벤션 엄수**: spacing/padding 은 리터럴 숫자, 색/타이포/라디우스/섀도우는 `ChalNa*` 토큰. `Color(hex:)`/`.font(.system)`/리터럴 cornerRadius 금지. GCD 금지(Swift Concurrency). `@Observable`/TCA(ObservableObject 금지). 한 파일 = 한 타입.

---

## Milestone 1 — 9:16 고정 출력 (독립, 먼저 ship)

### Task 1: renderSize 를 1080×1920 고정으로 (테스트 먼저)

**Files:**
- Test: `Modules/CompositionService/Tests/CompositionRenderSizeTests.swift` (전면 재작성)
- Modify: `Modules/CompositionService/Sources/CompositionService.swift:583-644`

- [ ] **Step 1: 테스트를 고정 상수 검증으로 재작성**

`CompositionRenderSizeTests.swift` 전체를 아래로 교체:

```swift
import Foundation
import CoreGraphics
import Testing
import Models
import CompositionService

struct CompositionRenderSizeTests {

    /// 입력이 무엇이든 출력 캔버스는 항상 1080×1920.
    @Test func testRenderSize_AlwaysFixed1080x1920_Portrait() async {
        let clips = [Self.makeClip(displaySize: CGSize(width: 1920, height: 1080))]
        let size = await AVFoundationCompositionService.resolveRenderSize(clips: clips, rotations: [:])
        #expect(size.width == 1080, "width: \(size.width)")
        #expect(size.height == 1920, "height: \(size.height)")
    }

    @Test func testRenderSize_FixedRegardlessOfMix() async {
        let clips = [
            Self.makeClip(displaySize: CGSize(width: 1920, height: 1080)),
            Self.makeClip(displaySize: CGSize(width: 1080, height: 1920)),
            Self.makeClip(displaySize: CGSize(width: 1080, height: 1080)),
        ]
        let size = await AVFoundationCompositionService.resolveRenderSize(clips: clips, rotations: [:])
        #expect(size.width == 1080)
        #expect(size.height == 1920)
    }

    @Test func testRenderSize_FixedWhenAllMissing() async {
        let clips = [Self.makeClip(displaySize: nil)]
        let size = await AVFoundationCompositionService.resolveRenderSize(clips: clips, rotations: [:])
        #expect(size.width == 1080)
        #expect(size.height == 1920)
    }

    @Test func testRenderSize_EmptyClips_StillFixed() async {
        let size = await AVFoundationCompositionService.resolveRenderSize(clips: [], rotations: [:])
        #expect(size.width == 1080)
        #expect(size.height == 1920)
    }

    @Test func testOutputSizeConstant() {
        #expect(AVFoundationCompositionService.outputSize == CGSize(width: 1080, height: 1920))
    }

    // MARK: - Helpers
    private static func makeClip(displaySize: CGSize?) -> Clip {
        Clip(kind: .video, capturedAt: Date(), duration: 1.0, preset: .jejuSea,
             thumbnailData: nil, videoURL: nil, locationNote: nil, displaySize: displaySize)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild ... test -only-testing:CompositionServiceTests/CompositionRenderSizeTests`
Expected: `testOutputSizeConstant` 는 `outputSize` 미정의로 **컴파일 실패**, 나머지는 1920≠1080 으로 FAIL.

- [ ] **Step 3: 상수 추가 + resolveRenderSize 상수화 + 고아 제거**

`CompositionService.swift` 의 `// MARK: - RenderSize` 블록(`:583-644`)을 아래로 교체. (기존 `resolveRenderSize` 본문, `snapEven`, `effectiveSize` 를 제거하고 상수 + 고정 반환만 남김)

```swift
    // MARK: - RenderSize

    /// 최종 출력 캔버스 — 9:16 세로 고정.
    public static let outputSize = CGSize(width: 1080, height: 1920)

    /// 출력 캔버스는 입력 클립과 무관하게 항상 `outputSize`(1080×1920).
    /// 비율이 다른 클립은 `transform()` 이 aspectFit + 가운데 정렬로 자동 letterbox/pillarbox 처리하고,
    /// 남는 여백은 블러 배경 레이어가 채운다. (시그니처는 호출부 호환을 위해 유지)
    public static func resolveRenderSize(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation]
    ) async -> CGSize {
        outputSize
    }
```

> 참고: 기존 `effectiveSize(for:)`·`snapEven(_:)` 은 이 변경으로 호출처가 사라진다 → **둘 다 삭제**(내 변경이 만든 미사용 코드 정리). 다른 곳에서 참조되지 않음(`resolveRenderSize` 전용이었음).

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild ... test -only-testing:CompositionServiceTests/CompositionRenderSizeTests`
Expected: 5개 케이스 PASS.

- [ ] **Step 5: 커밋**

```bash
git add Modules/CompositionService/Sources/CompositionService.swift Modules/CompositionService/Tests/CompositionRenderSizeTests.swift
git commit -m "feat: 출력 캔버스 9:16/1080x1920 고정 (resolveRenderSize 상수화)"
```

---

### Task 2: 저장본/커버 미리보기 비율을 9:16 세로로 교정

**Files:**
- Modify: `Modules/FilmDetailFeature/Sources/FilmDetailView.swift:133`
- Modify: `Modules/ExportFeature/Sources/ExportView.swift:162-185`

- [ ] **Step 1: FilmDetail 썸네일 카드 비율 교정**

`FilmDetailView.swift:133` 한 줄 교체:

```swift
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
```

- [ ] **Step 2: Export 커버를 세로 9:16 로 교정**

`ExportView.swift` 의 `coverWidth(forAvailableHeight:)`(`:162-171`) 에서 가로→세로 도출로 변경. `:169` 한 줄 교체:

```swift
        let widthFromHeight = (envelope - 60) * 9 / 16
```

그리고 커버 프레임(`:184`) 한 줄 교체:

```swift
                            .frame(width: width, height: width * 16 / 9)
```

- [ ] **Step 3: 빌드**

Run: `xcodebuild ... build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: 시각 검증(ios-build-run 위임)**

`ChalNa Dev` 스킴으로 실행 → export 완료 화면 커버와 FilmDetail 썸네일이 **세로(9:16)** 로 표시되는지 확인. 레이아웃이 넘치면 `coverWidth` 의 clamp 상·하한(`240`, `360`)을 조정.

- [ ] **Step 5: 커밋**

```bash
git add Modules/FilmDetailFeature/Sources/FilmDetailView.swift Modules/ExportFeature/Sources/ExportView.swift
git commit -m "fix: 저장본/Export 커버 미리보기 비율 9:16 세로 교정"
```

---

## Milestone 2 — 데이터 모델 & 합성 수학

### Task 3: `ClipTransform` 값 타입

**Files:**
- Create: `Modules/Models/Sources/ClipTransform.swift`

- [ ] **Step 1: 파일 생성**

```swift
import CoreGraphics
import Foundation

/// 한 클립을 9:16 캔버스 안에서 사용자가 확대/이동한 상태.
/// 기본값 `.fit` = 맞춤(여백 발생). `ClipRotation`/`ClipLabel` 과 동일하게 EditSession 이 들고 다닌다.
public struct ClipTransform: Hashable, Sendable {
    /// 맞춤(fit) 대비 배율. 1.0 = 맞춤, >1.0 = 확대. 권장 범위 [1.0, 4.0].
    public var scale: CGFloat
    /// 캔버스(renderSize) 기준 정규화 평행이동. x=가로 비율, y=세로 비율(y-down). clamp 는 `ClipFraming`.
    public var offset: CGPoint

    public init(scale: CGFloat = 1.0, offset: CGPoint = .zero) {
        self.scale = scale
        self.offset = offset
    }

    /// 맞춤(원본 그대로 aspectFit, 이동 없음).
    public static let fit = ClipTransform(scale: 1.0, offset: .zero)
}
```

- [ ] **Step 2: 빌드 확인**

Run: `tuist generate && xcodebuild ... build`
Expected: BUILD SUCCEEDED (아직 사용처 없음).

- [ ] **Step 3: 커밋**

```bash
git add Modules/Models/Sources/ClipTransform.swift
git commit -m "feat: ClipTransform 값 타입 추가(클립별 줌/이동 상태)"
```

---

### Task 4: `ClipFraming` 기하 SSOT (테스트 먼저)

**Files:**
- Create: `Modules/Models/Sources/ClipFraming.swift`
- Test: `Modules/CompositionService/Tests/ClipFramingTests.swift`

- [ ] **Step 1: 실패 테스트 작성**

`ClipFramingTests.swift` 생성:

```swift
import Foundation
import CoreGraphics
import Testing
import Models

struct ClipFramingTests {
    let render = CGSize(width: 1080, height: 1920)

    /// 가로 1920×1080 → 9:16 캔버스: fitScale = 1080/1920 = 0.5625.
    @Test func testFitScale_Landscape() {
        let s = ClipFraming.fitScale(display: CGSize(width: 1920, height: 1080), rotation: .r0, render: render)
        #expect(abs(s - 0.5625) < 0.0001, "\(s)")
    }

    /// 세로 720×1280 → 9:16 캔버스: fitScale = min(1080/720, 1920/1280)=min(1.5,1.5)=1.5.
    @Test func testFitScale_Portrait() {
        let s = ClipFraming.fitScale(display: CGSize(width: 720, height: 1280), rotation: .r0, render: render)
        #expect(abs(s - 1.5) < 0.0001, "\(s)")
    }

    /// r90 회전 시 축 swap 후 fit. 1920×1080 + r90 → oriented 1080×1920 → fitScale 1.0.
    @Test func testFitScale_AppliesRotation() {
        let s = ClipFraming.fitScale(display: CGSize(width: 1920, height: 1080), rotation: .r90, render: render)
        #expect(abs(s - 1.0) < 0.0001, "\(s)")
    }

    /// .fit 변환의 resolvedRect 는 placedRect(가운데 정렬 fit 사각형)과 같아야 한다.
    /// 가로 1920×1080 → scaledSize 1080×607.5, 가운데 정렬 → origin.y = (1920-607.5)/2 = 656.25.
    @Test func testResolvedRect_Fit_Landscape_Centered() {
        let r = ClipFraming.resolvedRect(display: CGSize(width: 1920, height: 1080), rotation: .r0, render: render, transform: .fit)
        #expect(abs(r.width - 1080) < 0.5, "w \(r.width)")
        #expect(abs(r.height - 607.5) < 0.5, "h \(r.height)")
        #expect(abs(r.minX - 0) < 0.5, "x \(r.minX)")
        #expect(abs(r.minY - 656.25) < 0.5, "y \(r.minY)")
    }

    /// scale=2 → 사이즈 2배, 가운데 유지.
    @Test func testResolvedRect_Scale2_GrowsCentered() {
        let r = ClipFraming.resolvedRect(display: CGSize(width: 1080, height: 1920), rotation: .r0, render: render,
                                         transform: ClipTransform(scale: 2, offset: .zero))
        #expect(abs(r.width - 2160) < 0.5, "w \(r.width)")
        #expect(abs(r.height - 3840) < 0.5, "h \(r.height)")
        #expect(abs(r.midX - 540) < 0.5, "midX \(r.midX)")
        #expect(abs(r.midY - 960) < 0.5, "midY \(r.midY)")
    }

    /// fit(=프레임을 넘지 않음)일 때 offset 은 양축 0으로 clamp.
    @Test func testClampedOffset_Fit_LocksToCenter() {
        let o = ClipFraming.clampedOffset(CGPoint(x: 0.5, y: 0.5),
                                          display: CGSize(width: 1080, height: 1920), rotation: .r0,
                                          render: render, scale: 1.0)
        #expect(abs(o.x) < 0.0001, "x \(o.x)")
        #expect(abs(o.y) < 0.0001, "y \(o.y)")
    }

    /// 세로 클립을 scale=2 로 키우면: scaledH=3840, maxFracY=(3840-1920)/2/1920=0.5.
    /// 가로는 scaledW=2160, maxFracX=(2160-1080)/2/1080=0.5. 과도한 offset 은 [-0.5,0.5]로 clamp.
    @Test func testClampedOffset_Zoomed_ClampsToCoverEdge() {
        let o = ClipFraming.clampedOffset(CGPoint(x: 1.0, y: -1.0),
                                          display: CGSize(width: 1080, height: 1920), rotation: .r0,
                                          render: render, scale: 2.0)
        #expect(abs(o.x - 0.5) < 0.0001, "x \(o.x)")
        #expect(abs(o.y - (-0.5)) < 0.0001, "y \(o.y)")
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: `xcodebuild ... test -only-testing:CompositionServiceTests/ClipFramingTests`
Expected: 컴파일 실패(`ClipFraming` 미정의).

- [ ] **Step 3: ClipFraming 구현**

`Modules/Models/Sources/ClipFraming.swift` 생성:

```swift
import CoreGraphics

/// 클립을 9:16 캔버스 안에 배치하는 기하의 단일 진실원천(SSOT).
/// 프리뷰·조정 화면·영상 합성(export)이 **모두 이 계산을 공유**해 WYSIWYG 가 어긋나지 않게 한다.
/// 좌표계는 SwiftUI/CG 표준(y-down). `display` 는 `preferredTransform` 적용 후 표시 크기.
public enum ClipFraming {
    /// 사용자 회전 반영 표시 크기.
    public static func orientedSize(_ display: CGSize, rotation: ClipRotation) -> CGSize {
        rotation.swapsAxes ? CGSize(width: display.height, height: display.width) : display
    }

    /// renderSize 안 aspectFit 배율(회전 반영). 0/NaN/Inf 가드.
    public static func fitScale(display: CGSize, rotation: ClipRotation, render: CGSize) -> CGFloat {
        let s = orientedSize(display, rotation: rotation)
        let w = max(s.width, 1), h = max(s.height, 1)
        let raw = min(render.width / w, render.height / h)
        return (raw.isFinite && raw > 0) ? raw : 1
    }

    /// 전경이 renderSize 를 덮을 때 가장자리 밖 여백이 보이지 않도록 offset(정규화 비율)을 clamp.
    /// 덮지 못하는(작은) 축은 0(중앙)으로 고정. proposed/return 모두 renderSize 대비 비율.
    public static func clampedOffset(
        _ proposed: CGPoint, display: CGSize, rotation: ClipRotation, render: CGSize, scale: CGFloat
    ) -> CGPoint {
        let s = orientedSize(display, rotation: rotation)
        let fit = fitScale(display: display, rotation: rotation, render: render)
        let scaledW = s.width * fit * scale
        let scaledH = s.height * fit * scale
        let maxFracX = render.width > 0 ? max(0, (scaledW - render.width) / 2) / render.width : 0
        let maxFracY = render.height > 0 ? max(0, (scaledH - render.height) / 2) / render.height : 0
        return CGPoint(
            x: min(max(proposed.x, -maxFracX), maxFracX),
            y: min(max(proposed.y, -maxFracY), maxFracY)
        )
    }

    /// 캔버스(render) 좌표계(y-down)에서 전경이 차지하는 사각형. scale·offset(clamp 적용) 반영.
    public static func resolvedRect(
        display: CGSize, rotation: ClipRotation, render: CGSize, transform: ClipTransform
    ) -> CGRect {
        let s = orientedSize(display, rotation: rotation)
        let fit = fitScale(display: display, rotation: rotation, render: render)
        let size = CGSize(width: s.width * fit * transform.scale, height: s.height * fit * transform.scale)
        let clamped = clampedOffset(transform.offset, display: display, rotation: rotation, render: render, scale: transform.scale)
        let center = CGPoint(x: render.width / 2 + clamped.x * render.width,
                             y: render.height / 2 + clamped.y * render.height)
        return CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                      width: size.width, height: size.height)
    }
}
```

- [ ] **Step 4: 통과 확인**

Run: `tuist generate && xcodebuild ... test -only-testing:CompositionServiceTests/ClipFramingTests`
Expected: 7개 케이스 PASS.

- [ ] **Step 5: 커밋**

```bash
git add Modules/Models/Sources/ClipFraming.swift Modules/CompositionService/Tests/ClipFramingTests.swift
git commit -m "feat: ClipFraming 기하 SSOT 추가(fit/clamp/resolvedRect) + 테스트"
```

---

### Task 5: `transform()` 에 사용자 변환 반영 (회귀 가드 + 신규 케이스)

**Files:**
- Modify: `Modules/CompositionService/Sources/CompositionService.swift:646-740` (`transform`, `placedRect`)
- Test: `Modules/CompositionService/Tests/CompositionTransformTests.swift`

- [ ] **Step 1: 기존 테스트에 `framing: .fit` 인자 추가 + 신규 케이스 추가**

`CompositionTransformTests.swift` 의 **모든** `transform(...)` 호출에 마지막 인자로 `framing: .fit` 을 추가한다(8곳). 예시(`:15-20`):

```swift
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r0,
            renderSize: render,
            framing: .fit
        )
```

그리고 파일 끝(마지막 `}` 직전)에 신규 케이스 2개 추가:

```swift
    /// scale=2: 세로 클립이 2배로 커져 캔버스를 넘는다. 중심은 캔버스 중앙 유지.
    /// 1080×1920 + fit(1.0)×2 → scaledSize 2160×3840, 좌상단 (-540, -960).
    @Test func testTransform_UserScale2_GrowsFromCenter() {
        let natural = CGSize(width: 1080, height: 1920)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural, preferredTransform: .identity, rotation: .r0,
            renderSize: render, framing: ClipTransform(scale: 2, offset: .zero)
        )
        let topLeft = CGPoint(x: 0, y: 0).applying(t)
        let bottomRight = CGPoint(x: natural.width, y: natural.height).applying(t)
        #expect(abs(topLeft.x - (-540)) < 0.5, "x \(topLeft.x)")
        #expect(abs(topLeft.y - (-960)) < 0.5, "y \(topLeft.y)")
        #expect(abs(bottomRight.x - 1620) < 0.5, "x \(bottomRight.x)")
        #expect(abs(bottomRight.y - 2880) < 0.5, "y \(bottomRight.y)")
    }

    /// offset: scale=2 로 키운 뒤 x=+0.5 비율 이동 → 중심이 +540px 우측으로.
    @Test func testTransform_UserOffset_ShiftsCenter() {
        let natural = CGSize(width: 1080, height: 1920)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural, preferredTransform: .identity, rotation: .r0,
            renderSize: render, framing: ClipTransform(scale: 2, offset: CGPoint(x: 0.5, y: 0))
        )
        // 중심점(원본 540,960)이 캔버스 중심(540,960) + (0.5×1080, 0) = (1080,960) 으로.
        let center = CGPoint(x: 540, y: 960).applying(t)
        #expect(abs(center.x - 1080) < 0.5, "cx \(center.x)")
        #expect(abs(center.y - 960) < 0.5, "cy \(center.y)")
    }
```

- [ ] **Step 2: 실패 확인**

Run: `xcodebuild ... test -only-testing:CompositionServiceTests/CompositionTransformTests`
Expected: 컴파일 실패(`transform` 에 `framing:` 인자 없음).

- [ ] **Step 3: `transform`/`placedRect` 구현 변경**

`CompositionService.swift` 의 `transform(...)`(`:652-712`) 를 아래로 교체(시그니처에 `framing` 추가, fit 계산을 `ClipFraming` 으로 위임, userScale·offset 적용):

```swift
    /// 한 클립을 renderSize 안에 aspectFit(=맞춤)으로 배치하고, 사용자 변환(scale·offset)을 추가 적용한 affine transform.
    /// framing == .fit 이면 기존 맞춤 동작과 동일(회귀 가드).
    public static func transform(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        rotation: ClipRotation,
        renderSize: CGSize,
        framing: ClipTransform
    ) -> CGAffineTransform {
        let displayRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let displaySize = CGSize(width: abs(displayRect.width), height: abs(displayRect.height))
        let postRotationSize: CGSize = rotation.swapsAxes
            ? CGSize(width: displaySize.height, height: displaySize.width)
            : displaySize

        let normalizeAfterPreferred = CGAffineTransform(translationX: -displayRect.minX, y: -displayRect.minY)

        let rotationMatrix = rotation.transform
        let rotatedRect = CGRect(origin: .zero, size: displaySize).applying(rotationMatrix)
        let rotationNormalize = CGAffineTransform(translationX: -rotatedRect.minX, y: -rotatedRect.minY)

        // fit 배율은 ClipFraming 과 공유. 사용자 배율(>=1)을 곱한다.
        let fitScale = ClipFraming.fitScale(display: displaySize, rotation: rotation, render: renderSize)
        let userScale = max(1.0, framing.scale)
        let totalScale = fitScale * userScale

        let scaledSize = CGSize(width: postRotationSize.width * totalScale,
                                height: postRotationSize.height * totalScale)
        let scaleMatrix = CGAffineTransform(scaleX: totalScale, y: totalScale)
        let centerTranslate = CGAffineTransform(translationX: (renderSize.width - scaledSize.width) / 2,
                                                y: (renderSize.height - scaledSize.height) / 2)

        // 사용자 이동(정규화 비율 → 픽셀). clamp 도 ClipFraming 공유.
        let clampedFrac = ClipFraming.clampedOffset(framing.offset, display: displaySize,
                                                    rotation: rotation, render: renderSize, scale: userScale)
        let offsetTranslate = CGAffineTransform(translationX: clampedFrac.x * renderSize.width,
                                                y: clampedFrac.y * renderSize.height)

        return preferredTransform
            .concatenating(normalizeAfterPreferred)
            .concatenating(rotationMatrix)
            .concatenating(rotationNormalize)
            .concatenating(scaleMatrix)
            .concatenating(centerTranslate)
            .concatenating(offsetTranslate)
    }
```

그리고 `placedRect(...)`(`:716-740`) 본문을 `ClipFraming` 으로 위임(라벨은 줌과 무관하게 **fit 사각형** 유지 — §자막 결합 끊기):

```swift
    /// 한 클립이 renderSize 안에서 aspectFit + 가운데 정렬됐을 때 차지하는 사각형(줌 미반영 = 라벨 기준).
    public static func placedRect(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        rotation: ClipRotation,
        renderSize: CGSize
    ) -> CGRect {
        let displayRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let displaySize = CGSize(width: abs(displayRect.width), height: abs(displayRect.height))
        return ClipFraming.resolvedRect(display: displaySize, rotation: rotation, render: renderSize, transform: .fit)
    }
```

> `minDisplayDimension` 상수(`:648`)는 `transform`/`placedRect` 에서 더 이상 쓰이지 않으면 제거(고아 정리). `ClipFraming` 내부 `max(...,1)` 가드로 대체됨.

- [ ] **Step 4: 통과 확인**

Run: `xcodebuild ... test -only-testing:CompositionServiceTests/CompositionTransformTests`
Expected: 기존 8 케이스 + 신규 2 케이스 모두 PASS (특히 `.fit` 케이스가 기존 기대값 그대로 = 회귀 없음).

- [ ] **Step 5: 커밋**

```bash
git add Modules/CompositionService/Sources/CompositionService.swift Modules/CompositionService/Tests/CompositionTransformTests.swift
git commit -m "feat: transform 에 클립별 scale/offset 반영(ClipFraming 공유), placedRect SSOT 위임"
```

---

### Task 6: `EditSession.scales` 상태

**Files:**
- Modify: `Modules/AppCore/Sources/EditSession.swift`
- Test: `Modules/AppCore/Tests/` (기존 AppCoreTests 위치에 신규 파일) `EditSessionScalesTests.swift`

- [ ] **Step 1: 실패 테스트 작성**

`Modules/AppCore/Tests/EditSessionScalesTests.swift` 생성:

```swift
import Foundation
import Testing
import Models
@testable import AppCore

struct EditSessionScalesTests {
    private func makeClip() -> Clip {
        Clip(kind: .live, capturedAt: Date(), duration: 1, preset: .jejuSea)
    }

    @Test func testTransformDefaultsToFit() {
        let s = EditSession()
        let c = makeClip()
        #expect(s.transform(for: c.id) == .fit)
    }

    @Test func testSetAndReadTransform() {
        let s = EditSession()
        let c = makeClip()
        let t = ClipTransform(scale: 2, offset: CGPoint(x: 0.1, y: -0.2))
        s.setTransform(t, for: c.id)
        #expect(s.transform(for: c.id) == t)
    }

    @Test func testResetTransform() {
        let s = EditSession()
        let c = makeClip()
        s.setTransform(ClipTransform(scale: 3), for: c.id)
        s.resetTransform(for: c.id)
        #expect(s.transform(for: c.id) == .fit)
    }

    @Test func testReplaceClearsScales() {
        let s = EditSession()
        let c = makeClip()
        s.setTransform(ClipTransform(scale: 2), for: c.id)
        s.replace(clips: [makeClip()], title: "x")
        #expect(s.transform(for: c.id) == .fit)
        #expect(s.scales.isEmpty)
    }

    @Test func testClearClearsScales() {
        let s = EditSession()
        let c = makeClip()
        s.setTransform(ClipTransform(scale: 2), for: c.id)
        s.clear()
        #expect(s.scales.isEmpty)
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: `xcodebuild ... test -only-testing:AppCoreTests/EditSessionScalesTests`
Expected: 컴파일 실패(`scales`/`transform(for:)`/`setTransform`/`resetTransform` 미정의).

> 만약 AppCore 테스트 타겟 이름이 다르면 `Module.unitTests(for:)` 규칙상 `AppCoreTests`. 기존 테스트 디렉터리 위치는 `Modules/AppCore/Tests/`.

- [ ] **Step 3: EditSession 확장**

`EditSession.swift` 를 아래처럼 수정.

(a) 저장 프로퍼티 추가 — `labels` 선언(`:13`) 바로 아래:

```swift
    /// 클립별 사용자 변환(줌/이동). dict miss = `.fit`.
    public var scales: [Clip.ID: ClipTransform]
```

(b) `init` 시그니처/본문에 `scales` 추가 (`:15-25`):

```swift
    public init(
        title: String = "",
        clips: [Clip] = [],
        rotations: [Clip.ID: ClipRotation] = [:],
        labels: [Clip.ID: ClipLabel] = [:],
        scales: [Clip.ID: ClipTransform] = [:]
    ) {
        self.title = title
        self.clips = clips
        self.rotations = rotations
        self.labels = labels
        self.scales = scales
    }
```

(c) `replace`(`:27-32`)·`clear`(`:34-39`) 에 `scales = [:]` 추가:

```swift
    public func replace(clips: [Clip], title: String) {
        self.clips = clips
        self.title = title
        self.rotations = [:]
        self.labels = [:]
        self.scales = [:]
    }

    public func clear() {
        clips = []
        title = ""
        rotations = [:]
        labels = [:]
        scales = [:]
    }
```

(d) `// MARK: - Label` 위(또는 파일 끝)에 접근자 추가:

```swift
    // MARK: - Transform (zoom/offset)

    public func transform(for id: Clip.ID) -> ClipTransform {
        scales[id] ?? .fit
    }

    public func setTransform(_ transform: ClipTransform, for id: Clip.ID) {
        scales[id] = transform
    }

    public func resetTransform(for id: Clip.ID) {
        scales[id] = nil
    }
```

- [ ] **Step 4: 통과 확인**

Run: `xcodebuild ... test -only-testing:AppCoreTests/EditSessionScalesTests`
Expected: 5개 PASS.

- [ ] **Step 5: 커밋**

```bash
git add Modules/AppCore/Sources/EditSession.swift Modules/AppCore/Tests/EditSessionScalesTests.swift
git commit -m "feat: EditSession 에 클립별 scales(줌/이동) 상태 추가"
```

---

### Task 7: `scales` 를 CompositionClient → 액터 → buildComposition 까지 관통

**Files:**
- Modify: `Modules/CompositionService/Sources/CompositionService.swift:37-90` (프로토콜+편의+actor export+run), `:148-224` (buildComposition)
- Modify: `Modules/CompositionService/Sources/CompositionClient.swift`

- [ ] **Step 1: 프로토콜/편의/actor 시그니처에 `scales` 추가**

`CompositionService.swift` 변경:

(a) 프로토콜(`:37-44`):

```swift
public protocol CompositionServicing: Sendable {
    /// 클립 배열·회전·클립별 변환·자동 라벨 설정·클립별 사용자 라벨을 받아 mp4를 만든다.
    func export(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        scales: [Clip.ID: ClipTransform],
        labelSettings: LabelSettings,
        clipLabels: [Clip.ID: ClipLabel]
    ) -> AsyncStream<ExportEvent>
}
```

(b) 편의 확장(`:47-60`) — 각 호출에 `scales: [:]` 추가:

```swift
public extension CompositionServicing {
    func export(clips: [Clip], rotations: [Clip.ID: ClipRotation], labelSettings: LabelSettings) -> AsyncStream<ExportEvent> {
        export(clips: clips, rotations: rotations, scales: [:], labelSettings: labelSettings, clipLabels: [:])
    }
    func export(clips: [Clip], rotations: [Clip.ID: ClipRotation]) -> AsyncStream<ExportEvent> {
        export(clips: clips, rotations: rotations, scales: [:], labelSettings: .default, clipLabels: [:])
    }
    func export(clips: [Clip]) -> AsyncStream<ExportEvent> {
        export(clips: clips, rotations: [:], scales: [:], labelSettings: .default, clipLabels: [:])
    }
}
```

(c) actor `export`(`:66-82`):

```swift
    public nonisolated func export(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        scales: [Clip.ID: ClipTransform],
        labelSettings: LabelSettings,
        clipLabels: [Clip.ID: ClipLabel]
    ) -> AsyncStream<ExportEvent> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                guard let self else { continuation.finish(); return }
                await self.run(clips: clips, rotations: rotations, scales: scales, labelSettings: labelSettings, clipLabels: clipLabels, continuation: continuation)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
```

(d) `run`(`:86-94`) 시그니처에 `scales` 추가 + `buildComposition` 호출에 전달(`:94`):

```swift
    private func run(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        scales: [Clip.ID: ClipTransform],
        labelSettings: LabelSettings,
        clipLabels: [Clip.ID: ClipLabel],
        continuation: AsyncStream<ExportEvent>.Continuation
    ) async {
        do {
            let built = try await buildComposition(clips: clips, rotations: rotations, scales: scales, labelSettings: labelSettings, clipLabels: clipLabels)
```

(e) `buildComposition`(`:148-153`) 시그니처에 `scales` 추가:

```swift
    private func buildComposition(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        scales: [Clip.ID: ClipTransform],
        labelSettings: LabelSettings,
        clipLabels: [Clip.ID: ClipLabel]
    ) async throws -> BuiltComposition {
```

(f) 클립 루프의 `transform(...)` 호출(`:207-212`) 에 `framing` 전달:

```swift
            let transform = Self.transform(
                naturalSize: naturalSize,
                preferredTransform: preferredTransform,
                rotation: userRotation,
                renderSize: renderSize,
                framing: scales[clip.id] ?? .fit
            )
```

- [ ] **Step 2: CompositionClient 시그니처 갱신**

`CompositionClient.swift` 전체 교체:

```swift
import Foundation
import ComposableArchitecture
import Models

@DependencyClient
public struct CompositionClient: Sendable {
    public var export: @Sendable (
        _ clips: [Clip],
        _ rotations: [Clip.ID: ClipRotation],
        _ scales: [Clip.ID: ClipTransform],
        _ labelSettings: LabelSettings,
        _ clipLabels: [Clip.ID: ClipLabel]
    ) -> AsyncStream<ExportEvent> = { _, _, _, _, _ in
        AsyncStream { $0.finish() }
    }
}

extension CompositionClient: DependencyKey {
    public static let liveValue: CompositionClient = {
        let service = AVFoundationCompositionService()
        return CompositionClient(
            export: { clips, rotations, scales, labelSettings, clipLabels in
                service.export(clips: clips, rotations: rotations, scales: scales, labelSettings: labelSettings, clipLabels: clipLabels)
            }
        )
    }()

    public static let testValue = CompositionClient()
}

public extension DependencyValues {
    var compositionClient: CompositionClient {
        get { self[CompositionClient.self] }
        set { self[CompositionClient.self] = newValue }
    }
}
```

- [ ] **Step 3: 빌드 (CompositionService 단독 포커스 가능)**

Run: `tuist generate && xcodebuild ... build`
Expected: BUILD SUCCEEDED. (ExportFeature 미수정 상태면 호출부 인자 불일치로 실패할 수 있음 → Task 8 과 연속 진행, 또는 Task 8 까지 한 커밋으로 묶어도 됨)

- [ ] **Step 4: 기존 합성 테스트 회귀 확인**

Run: `xcodebuild ... test -only-testing:CompositionServiceTests`
Expected: PASS (transform/renderSize/customLabel 모두).

- [ ] **Step 5: 커밋**

```bash
git add Modules/CompositionService/Sources/CompositionService.swift Modules/CompositionService/Sources/CompositionClient.swift
git commit -m "feat: scales(클립별 변환)를 CompositionClient~buildComposition 까지 관통"
```

---

### Task 8: ExportFeature/ExportView 에서 `scales` 전달

**Files:**
- Modify: `Modules/ExportFeature/Sources/ExportFeature.swift:100-117`
- Modify: `Modules/ExportFeature/Sources/ExportView.swift:51`

- [ ] **Step 1: Action 시그니처 + export 호출에 scales 추가**

`ExportFeature.swift` 의 `startExport` Action 케이스 선언(파일 상단 Action enum 내 `case startExport(...)`) 에 `scales` 추가. 케이스 시그니처를 아래로:

```swift
        case startExport(clips: [Clip], rotations: [Clip.ID: ClipRotation], scales: [Clip.ID: ClipTransform], clipLabels: [Clip.ID: ClipLabel])
```

리듀서 매칭(`:100`)·export 호출(`:117`) 변경:

```swift
            case let .startExport(clips, rotations, scales, clipLabels):
                guard !clips.isEmpty else { return .none }
                state.phase = .exporting
                state.progress = 0
                state.errorMessage = nil
                state.exportedURL = nil
                state.didAddToLibrary = false
                analyticsTracker.log(.exportStarted(clipCount: clips.count))
                let labelSettings = LabelSettings(
                    timeEnabled: state.timeEnabled,
                    timePosition: state.timePosition,
                    timeOpacity: state.timeOpacity,
                    dateEnabled: state.dateEnabled,
                    datePosition: state.datePosition,
                    dateOpacity: state.dateOpacity
                )
                return .run { send in
                    for await event in compositionClient.export(clips, rotations, scales, labelSettings, clipLabels) {
                        switch event {
                        case let .progress(p): await send(.exportProgress(p))
                        case let .completed(url): await send(.exportCompleted(url))
                        case let .failed(msg): await send(.exportFailed(msg))
                        }
                    }
                }
                .cancellable(id: CancelID.exportStream, cancelInFlight: true)
```

> `import Models` 가 ExportFeature 에 이미 있는지 확인(ClipTransform 타입 사용). 없으면 추가.

- [ ] **Step 2: ExportView 호출에 session.scales 전달**

`ExportView.swift:51` 교체:

```swift
            store.send(.startExport(clips: session.clips, rotations: session.rotations, scales: session.scales, clipLabels: session.labels))
```

- [ ] **Step 3: 빌드 + 합성 회귀**

Run: `tuist generate && xcodebuild ... build && xcodebuild ... test -only-testing:CompositionServiceTests`
Expected: BUILD SUCCEEDED, 테스트 PASS.

- [ ] **Step 4: 시각 검증(ios-build-run)** — `ChalNa Dev` 로 export 1회. 결과 mp4 가 1080×1920, 비포트레이트 클립은 검은 여백(블러는 Task 9에서). 회귀 없음.

- [ ] **Step 5: 커밋**

```bash
git add Modules/ExportFeature/Sources/ExportFeature.swift Modules/ExportFeature/Sources/ExportView.swift
git commit -m "feat: Export 플로우에 클립별 scales 전달"
```

---

## Milestone 3 — 블러 필 배경

### Task 9: 클립별 정지 블러 배경 레이어

**Files:**
- Modify: `Modules/CompositionService/Sources/CompositionService.swift:169-257` (entries 튜플 + 게이팅), `:305-417` (애니메이션 툴 함수), 신규 helper

- [ ] **Step 1: entries 튜플에 thumbnailData 추가**

`buildComposition` 의 `layerInstructions` 튜플 타입(`:169`)에 `thumbnailData: Data?` 추가:

```swift
        var layerInstructions: [(timeRange: CMTimeRange, transform: CGAffineTransform, capturedAt: Date, clipID: Clip.ID, placedRect: CGRect, thumbnailData: Data?)] = []
```

append(`:221`) 변경:

```swift
            layerInstructions.append((placedRange, transform, clip.capturedAt, clip.id, pRect, clip.thumbnailData))
```

- [ ] **Step 2: 게이팅 변경 + 함수 호출 인자 확장**

`:242-250` 블록 교체 — 콘텐츠가 있으면 **항상** 툴 부착(블러 배경 위해):

```swift
        // 4) 블러 배경 + 라벨 오버레이. 배경은 항상 필요하므로 hasContent 면 부착.
        if hasContent {
            videoComposition.animationTool = Self.makeBackdropAndLabelTool(
                renderSize: renderSize,
                entries: layerInstructions.map { ($0.timeRange, $0.capturedAt, $0.clipID, $0.placedRect, $0.thumbnailData) },
                labelSettings: labelSettings,
                clipLabels: clipLabels
            )
        }
```

- [ ] **Step 3: 함수 이름/시그니처 변경 + 배경 삽입**

`makeDateLabelAnimationTool`(`:310-316`) 의 선언을 아래로 바꾸고(이름 `makeBackdropAndLabelTool`, entries 튜플에 `thumbnailData` 추가), `videoLayer` 추가 직후 배경 삽입 루프를 넣는다.

선언/상단(`:310-320`) 교체:

```swift
    /// 클립별 블러 배경(videoLayer 아래) + 촬영일시/커스텀 라벨(videoLayer 위)을 합성하는 툴.
    private static func makeBackdropAndLabelTool(
        renderSize: CGSize,
        entries: [(timeRange: CMTimeRange, capturedAt: Date, clipID: Clip.ID, placedRect: CGRect, thumbnailData: Data?)],
        labelSettings: LabelSettings,
        clipLabels: [Clip.ID: ClipLabel]
    ) -> AVVideoCompositionCoreAnimationTool {
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = parentLayer.frame
        parentLayer.addSublayer(videoLayer)

        #if canImport(UIKit)
        // 각 클립의 블러 배경을 videoLayer 아래에 깔고, 자기 timeRange 동안만 보이게 한다.
        for entry in entries {
            if let backdrop = makeBlurredBackdropLayer(thumbnailData: entry.thumbnailData, renderSize: renderSize, timeRange: entry.timeRange) {
                parentLayer.insertSublayer(backdrop, below: videoLayer)
            }
        }
        #endif
```

> 위 블록은 기존 `:316-320`(parentLayer/videoLayer 구성)을 대체하고, 기존 `let minDim = ...`(`:322`) 이하 라벨 로직은 그대로 둔다. 함수 끝 `return AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)`(`:413-416`)도 그대로.

- [ ] **Step 4: 블러 배경 helper 추가**

`#if canImport(UIKit)` 섹션(예: `addShowAnimation`(`:570-580`) 근처) 안에 추가. 파일 상단에 `import CoreImage` 추가(없으면).

```swift
    private static let backdropCIContext = CIContext(options: nil)

    /// 클립 썸네일을 가우시안 블러 → 캔버스 aspectFill 로 깐 배경 레이어(+어두운 스크림).
    /// timeRange 동안만 opacity=1. 썸네일이 없으면 nil(배경 생략 = 검정).
    private static func makeBlurredBackdropLayer(thumbnailData: Data?, renderSize: CGSize, timeRange: CMTimeRange) -> CALayer? {
        guard let data = thumbnailData, let ui = UIImage(data: data), let cg = ui.cgImage else { return nil }
        let ci = CIImage(cgImage: cg)
        guard let blur = CIFilter(name: "CIGaussianBlur") else { return nil }
        blur.setValue(ci, forKey: kCIInputImageKey)
        blur.setValue(min(renderSize.width, renderSize.height) * 0.04, forKey: kCIInputRadiusKey)
        guard let out = blur.outputImage,
              let rendered = backdropCIContext.createCGImage(out.cropped(to: ci.extent), from: ci.extent) else { return nil }

        let layer = CALayer()
        layer.frame = CGRect(origin: .zero, size: renderSize)
        layer.contents = rendered
        layer.contentsGravity = .resizeAspectFill
        layer.masksToBounds = true
        layer.opacity = 0
        addShowAnimation(to: layer, timeRange: timeRange)

        let scrim = CALayer()
        scrim.frame = layer.bounds
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.18).cgColor
        layer.addSublayer(scrim)
        return layer
    }
```

- [ ] **Step 5: 빌드 + 합성 회귀**

Run: `tuist generate && xcodebuild ... build && xcodebuild ... test -only-testing:CompositionServiceTests`
Expected: BUILD SUCCEEDED, 테스트 PASS(블러는 단위 테스트 없음, 기존 라벨/transform 회귀만 확인).

- [ ] **Step 6: 시각 검증(ios-build-run)**

`ChalNa Dev` 로 가로/정사각 클립 포함 export → 여백이 **블러 배경**으로 채워지는지, 라벨 ON/OFF 모두 정상인지(라벨 OFF 일 때도 배경 보임), 클립 전환 시 배경이 클립별로 바뀌는지 확인.

- [ ] **Step 7: 커밋**

```bash
git add Modules/CompositionService/Sources/CompositionService.swift
git commit -m "feat: 클립별 정지 블러 배경 합성(여백 블러 필)"
```

---

## Milestone 4 — 전용 조정 화면 + 프리뷰 WYSIWYG

### Task 10: `ClipAdjustFeature` (라우트용 Reducer)

**Files:**
- Create: `Modules/TimelineFeature/Sources/ClipAdjustFeature.swift`

- [ ] **Step 1: 파일 생성** (FilmDetailFeature.State 패턴 모방)

```swift
import ComposableArchitecture
import Foundation
import Models

/// 클립 1개의 프레이밍(줌/이동/회전)을 편집하는 풀스크린 화면 Reducer.
/// 실제 편집 상태는 `EditSession`(환경)에 직접 쓴다 — 회전/라벨과 동일한 패턴.
/// 이 Reducer 는 라우트 식별(`clipID`)만 들고, 화면 전환은 View+AppRouter 가 처리.
@Reducer
public struct ClipAdjustFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public let clipID: Clip.ID
        public init(clipID: Clip.ID) { self.clipID = clipID }
    }

    public enum Action: Equatable {
        case doneTapped
    }

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .doneTapped:
                return .none   // 실제 pop 은 View 의 router.pop()
            }
        }
    }
}
```

- [ ] **Step 2: 빌드**

Run: `tuist generate && xcodebuild ... build`
Expected: BUILD SUCCEEDED (아직 라우트 미연결).

- [ ] **Step 3: 커밋**

```bash
git add Modules/TimelineFeature/Sources/ClipAdjustFeature.swift
git commit -m "feat: ClipAdjustFeature(조정 화면 라우트 Reducer) 추가"
```

---

### Task 11: 라우트 배선 (AppRouter / AppFeature / RootView)

**Files:**
- Modify: `Modules/AppCore/Sources/AppRouter.swift:6-15`
- Modify: `ChalNa/Sources/App/AppFeature.swift:26-53, 62-116`
- Modify: `ChalNa/Sources/App/RootView.swift:40-77`

- [ ] **Step 1: Route 케이스 추가**

`AppRouter.swift` 의 `Route` enum 에 케이스 추가(`:14` `case support` 아래):

```swift
    case clipAdjust(clipID: UUID)
```

- [ ] **Step 2: AppFeature 에 Path 케이스 + 액션 + 핸들러**

`AppFeature.swift`:

(a) `import TimelineFeature` 는 이미 있음(`:7`). Action enum 에 추가(`:39` 근처):

```swift
        case routerPushedClipAdjust(clipID: UUID)
```

(b) `Path` enum 에 케이스 추가(`:52` `case support` 아래):

```swift
        case clipAdjust(ClipAdjustFeature)
```

(c) 리듀서에 핸들러 추가(`:108-110` `routerPushedSupport` 케이스 아래):

```swift
            case let .routerPushedClipAdjust(clipID):
                state.path.append(.clipAdjust(ClipAdjustFeature.State(clipID: clipID)))
                return .none
```

- [ ] **Step 3: RootView destination + 라우터 핸들러**

`RootView.swift`:

(a) `destinationView`(`:42-51`) 에 케이스 추가:

```swift
        case let .clipAdjust(s):    ClipAdjustView(store: s)
```

(b) `wireRouterHandlers` 의 switch(`:56-73`) 에 추가:

```swift
            case let .clipAdjust(clipID):
                store.send(.routerPushedClipAdjust(clipID: clipID))
```

- [ ] **Step 4: 빌드**

Run: `tuist generate && xcodebuild ... build`
Expected: `ClipAdjustView` 미정의로 실패 → Task 12 에서 생성. (Task 12 까지 묶어 진행 권장)

- [ ] **Step 5: 커밋** (Task 12 통과 후 함께 커밋해도 됨)

```bash
git add Modules/AppCore/Sources/AppRouter.swift ChalNa/Sources/App/AppFeature.swift ChalNa/Sources/App/RootView.swift
git commit -m "feat: clipAdjust 라우트 배선(AppRouter/AppFeature/RootView)"
```

---

### Task 12: `ClipAdjustView` (핀치 줌/드래그/회전/리셋)

**Files:**
- Create: `Modules/TimelineFeature/Sources/ClipAdjustView.swift`

- [ ] **Step 1: 파일 생성**

```swift
import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem

/// 클립 1개를 9:16 캔버스 안에서 핀치 줌·드래그·회전으로 프레이밍하는 풀스크린 화면.
/// 배경=블러 필, 전경=ClipFraming.resolvedRect 로 배치 → export 와 픽셀 일치(WYSIWYG).
/// 편집은 EditSession 에 live 반영(회전 기존 동작과 동일, 별도 취소 없음).
struct ClipAdjustView: View {
    @Environment(EditSession.self) private var session
    @Environment(AppRouter.self) private var router

    let store: StoreOf<ClipAdjustFeature>
    @State private var playback = ClipPlaybackController()
    @GestureState private var gestureScale: CGFloat = 1
    @GestureState private var gestureDrag: CGSize = .zero

    private static let render = CGSize(width: 1080, height: 1920)
    private static let minScale: CGFloat = 1.0
    private static let maxScale: CGFloat = 4.0

    private var clip: Clip? { session.clips.first { $0.id == store.clipID } }
    private var rotation: ClipRotation { session.rotation(for: store.clipID) }
    private var committed: ClipTransform { session.transform(for: store.clipID) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 0)
            canvas
            Spacer(minLength: 0)
            controls
        }
        .chalNaScreen()
        .onAppear {
            playback.load(clip: clip)
            playback.play()
        }
        .onDisappear { playback.pause() }
    }

    // MARK: - Top bar
    private var topBar: some View {
        HStack {
            Button {
                router.pop()
            } label: {
                HStack(spacing: 2) {
                    ChalNaIcon(.chevronLeft, size: 14)
                    Text("뒤로").font(ChalNaTypography.krBody(14, weight: .medium))
                }
                .foregroundColor(ChalNaColor.taupe)
            }
            .buttonStyle(.chalNaHeaderAction)
            Spacer()
            Text("조정").font(ChalNaTypography.krSemibold(15)).foregroundColor(ChalNaColor.ink)
            Spacer()
            Button {
                store.send(.doneTapped)
                router.pop()
            } label: {
                Text("완료").font(ChalNaTypography.krBody(14, weight: .semibold)).foregroundColor(ChalNaColor.coral)
            }
            .buttonStyle(.chalNaHeaderAction)
        }
        .padding(.horizontal, 16)
        .chalNaHeaderBar(scrollProgress: 1)
    }

    // MARK: - Canvas
    private var canvas: some View {
        GeometryReader { proxy in
            let box = LabelBoxGeometry.fittedBox(aspect: 9.0 / 16.0, in: proxy.size)
            let factor = box.width / Self.render.width
            let live = liveTransform(viewBox: box)
            let rrect = ClipFraming.resolvedRect(display: displaySize, rotation: rotation, render: Self.render, transform: live)

            ZStack {
                // 블러 배경
                if let clip {
                    clip.thumbnailView(contentMode: .fill)
                        .frame(width: box.width, height: box.height)
                        .clipped()
                        .blur(radius: 18)
                        .overlay(Color.black.opacity(0.18))
                }
                // 전경
                RotatableContent(rotation: rotation) {
                    foreground
                }
                .frame(width: rrect.width * factor, height: rrect.height * factor)
                .position(x: rrect.midX * factor, y: rrect.midY * factor)
            }
            .frame(width: box.width, height: box.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous))
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .updating($gestureScale) { v, s, _ in s = v }
                        .onEnded { v in commitScale(v) },
                    DragGesture()
                        .updating($gestureDrag) { v, s, _ in s = v.translation }
                        .onEnded { v in commitDrag(v.translation, viewBox: box) }
                )
            )
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var foreground: some View {
        if let clip {
            if clip.videoURL != nil && playback.hasVideo {
                PlayerLayerView(player: playback.player)
            } else {
                clip.thumbnailView(contentMode: .fill)
            }
        }
    }

    // MARK: - Controls
    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                session.cycleRotation(for: store.clipID)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Label("회전", systemImage: "")
                    .labelStyle(.titleOnly)
            }
            .buttonStyle(.chalNaOutlined)

            Button {
                session.resetTransform(for: store.clipID)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Text("맞춤으로 리셋")
            }
            .buttonStyle(.chalNaOutlined)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Geometry / commit
    private var displaySize: CGSize { clip?.displaySize ?? CGSize(width: 9, height: 16) }

    private func liveTransform(viewBox: CGSize) -> ClipTransform {
        let scale = min(max(committed.scale * gestureScale, Self.minScale), Self.maxScale)
        let fx = viewBox.width > 0 ? gestureDrag.width / viewBox.width : 0
        let fy = viewBox.height > 0 ? gestureDrag.height / viewBox.height : 0
        let offset = ClipFraming.clampedOffset(
            CGPoint(x: committed.offset.x + fx, y: committed.offset.y + fy),
            display: displaySize, rotation: rotation, render: Self.render, scale: scale
        )
        return ClipTransform(scale: scale, offset: offset)
    }

    private func commitScale(_ v: CGFloat) {
        let scale = min(max(committed.scale * v, Self.minScale), Self.maxScale)
        let offset = ClipFraming.clampedOffset(committed.offset, display: displaySize, rotation: rotation, render: Self.render, scale: scale)
        session.setTransform(ClipTransform(scale: scale, offset: offset), for: store.clipID)
    }

    private func commitDrag(_ t: CGSize, viewBox: CGSize) {
        let fx = viewBox.width > 0 ? t.width / viewBox.width : 0
        let fy = viewBox.height > 0 ? t.height / viewBox.height : 0
        let offset = ClipFraming.clampedOffset(
            CGPoint(x: committed.offset.x + fx, y: committed.offset.y + fy),
            display: displaySize, rotation: rotation, render: Self.render, scale: committed.scale
        )
        session.setTransform(ClipTransform(scale: committed.scale, offset: offset), for: store.clipID)
    }
}
```

> 주의: `.buttonStyle(.chalNaOutlined)` 와 `.buttonStyle(.chalNaHeaderAction)` 는 DesignSystem 제공(README/CLAUDE.md 의 버튼 스타일). 회전 버튼의 `Label(... systemImage:"")` 는 `.titleOnly` 라 텍스트만 표시 — `ChalNaIcon(.rotate)` 를 쓰고 싶으면 `HStack { ChalNaIcon(.rotate, size:16); Text("회전") }` 로 대체 가능.

- [ ] **Step 2: 빌드**

Run: `tuist generate && xcodebuild ... build`
Expected: BUILD SUCCEEDED (Task 11 라우트와 결합).

- [ ] **Step 3: 시각 검증(ios-build-run)**

`ChalNa Dev` 실행 → (Task 13 의 진입점이 아직이면 임시로 타임라인 회전 버튼을 push 로 바꿔 확인하거나 Task 13 후 검증) 조정 화면에서: 핀치로 확대/축소(1~4배), 드래그로 이동(여백 안 보이게 clamp), 회전, 맞춤 리셋, 완료/뒤로 동작. 배경 블러 표시. **export 결과와 화면이 일치**하는지 한 번 export 해서 대조.

- [ ] **Step 4: 커밋**

```bash
git add Modules/TimelineFeature/Sources/ClipAdjustView.swift
git commit -m "feat: ClipAdjustView(핀치 줌/드래그/회전/리셋, 블러 배경, WYSIWYG)"
```

---

### Task 13: 타임라인 진입점 — 회전 버튼 → 조정 화면

**Files:**
- Modify: `Modules/TimelineFeature/Sources/Components/EditToolbar.swift:13, 29, 55`
- Modify: `Modules/TimelineFeature/Sources/TimelineView.swift:273-301`

- [ ] **Step 1: EditToolbar 회전 → 조정 버튼**

`EditToolbar.swift`:

(a) 콜백 이름 변경(`:13`): `var onRotate: () -> Void = {}` → 

```swift
    var onAdjust: () -> Void = {}
```

(b) `rotationActive`(`:9`) 의미 유지(조정 적용 표시로 재사용) — 주석만 갱신. paper 항목(`:29`)·glass 항목(`:55`) 의 첫 item 을 교체:

```swift
            item(icon: .move, label: "조정", action: onAdjust, dotIndicator: rotationActive)
```
```swift
                glassItem(icon: .move, label: "조정", action: onAdjust, dotIndicator: rotationActive)
```

- [ ] **Step 2: TimelineView — 조정 화면 push, 회전 로직 제거**

`TimelineView.swift`:

(a) bottomBar 의 `EditToolbar(...)`(`:273-284`) 에서 `onRotate` → `onAdjust` 로 교체:

```swift
            EditToolbar(
                rotationActive: currentAdjustActive,
                labelActive: currentLabelActive,
                canSave: canSave,
                onAdjust: { openAdjust() },
                onLabel: { openLabelEditor() },
                onDelete: { store.send(.deleteCurrentRequested) },
                onSave: {
                    store.send(.saveTapped)
                    router.push(.export)
                }
            )
            .padding(.bottom, 16)
```

dimmed 분기(`:270`)의 `EditToolbar(dimmed: true, rotationActive: currentRotationActive, canSave: canSave)` 는 `rotationActive: currentAdjustActive` 로 교체.

(b) `// MARK: - Rotation` 블록(`:289-301`)을 아래로 교체(조정 진입 + 적용 표시):

```swift
    // MARK: - Adjust (조정 화면 진입)

    /// 회전 또는 줌/이동이 적용돼 있으면 툴바 점 표시.
    private var currentAdjustActive: Bool {
        guard let id = store.currentClip?.id else { return false }
        return session.rotation(for: id) != .r0 || session.transform(for: id) != .fit
    }

    private func openAdjust() {
        guard let id = store.currentClip?.id else { return }
        router.push(.clipAdjust(clipID: id))
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
```

> `rotateCurrentClip()`·`currentRotationActive` 는 제거(회전은 조정 화면으로 이동). `store.send(.rotateCurrentTapped)` 호출처가 사라지지만 TimelineFeature 의 `rotateCurrentTapped` 액션 자체는 다른 곳에서 안 쓰면 그대로 둬도 무방(제거는 선택; 본 계획에선 surgical 하게 View 만 수정).

- [ ] **Step 3: 빌드**

Run: `tuist generate && xcodebuild ... build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: 시각 검증(ios-build-run)**

타임라인 하단 "조정" 탭 → 조정 화면 push → 핀치/팬/회전/리셋/완료 → 타임라인 복귀, 점 표시(active) 확인. export 시 반영.

- [ ] **Step 5: 커밋**

```bash
git add Modules/TimelineFeature/Sources/Components/EditToolbar.swift Modules/TimelineFeature/Sources/TimelineView.swift
git commit -m "feat: 타임라인 회전 버튼 → 조정 화면 진입(회전 통합)"
```

---

### Task 14: 타임라인 프리뷰를 9:16 + 블러 + transform 반영 (WYSIWYG)

**Files:**
- Modify: `Modules/TimelineFeature/Sources/Components/PreviewPanel.swift:8-63`

- [ ] **Step 1: previewCard/thumbnail 을 9:16 캔버스 + 블러 + ClipFraming 으로 교체**

`PreviewPanel.swift` 의 `previewHeight`(`:9`) 와 `previewCard`(`:34-46`)·`thumbnail`(`:48-63`) 을 아래로 교체. (라벨 오버레이 `autoLabelsOverlay`/`labelOverlay` 는 클립 fit 박스 기준이라 그대로 유지 — placedRect 가 fit 사각형이므로 export 와 일치.)

```swift
    private static let previewHeight: CGFloat = 300
    private static let render = CGSize(width: 1080, height: 1920)
```

```swift
    private var previewCard: some View {
        GeometryReader { proxy in
            let box = LabelBoxGeometry.fittedBox(aspect: 9.0 / 16.0, in: proxy.size)
            ZStack {
                clipCanvas(box: box)
                    .overlay(autoLabelsOverlay)
                    .overlay(labelOverlay)
                    .frame(width: box.width, height: box.height)
                    .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous))
                    .overlay(hudOverlay)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(height: Self.previewHeight)
        .chalNaShadow(ChalNaShadow.md)
    }

    @ViewBuilder
    private func clipCanvas(box: CGSize) -> some View {
        ZStack {
            if let clip = store.currentClip {
                // 블러 배경
                clip.thumbnailView(contentMode: .fill)
                    .frame(width: box.width, height: box.height)
                    .clipped()
                    .blur(radius: 14)
                    .overlay(Color.black.opacity(0.18))
                // 전경 (줌/이동/회전 반영)
                let t = session.transform(for: clip.id)
                let rrect = ClipFraming.resolvedRect(display: clip.displaySize ?? CGSize(width: 9, height: 16),
                                                     rotation: currentRotation, render: Self.render, transform: t)
                let factor = box.width / Self.render.width
                RotatableContent(rotation: currentRotation) {
                    if clip.videoURL != nil && playback.hasVideo {
                        PlayerLayerView(player: playback.player)
                    } else {
                        clip.thumbnailView(contentMode: .fill)
                    }
                }
                .frame(width: rrect.width * factor, height: rrect.height * factor)
                .position(x: rrect.midX * factor, y: rrect.midY * factor)
            } else {
                ChalNaColor.ivory
            }
        }
        .frame(width: box.width, height: box.height)
        .clipped()
    }
```

> 기존 `thumbnail` computed property 는 `clipCanvas(box:)` 로 대체되므로 삭제. `autoLabelsOverlay`/`labelOverlay`/`hudOverlay`/`externalScrubBar` 등 나머지는 그대로 둔다. 라벨 오버레이의 GeometryReader `proxy.size` 는 이제 box(9:16) 크기를 받으므로 클립 fit 박스가 캔버스 기준으로 정확히 잡혀 export 와 일치.

- [ ] **Step 2: 빌드**

Run: `tuist generate && xcodebuild ... build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: 시각 검증(ios-build-run)**

타임라인 프리뷰가 **9:16 세로 + 블러 배경**으로 보이고, 조정 화면에서 줌/이동/회전한 결과가 **프리뷰에 즉시 반영**되며, 라벨(시간/날짜/커스텀)이 클립 위 올바른 위치에 뜨는지 확인. 프리뷰 ↔ export 결과 대조(동일해야 함). 패널 높이 300이 어색하면 `previewHeight` 조정.

- [ ] **Step 4: 커밋**

```bash
git add Modules/TimelineFeature/Sources/Components/PreviewPanel.swift
git commit -m "feat: 타임라인 프리뷰 9:16+블러+클립 transform 반영(WYSIWYG)"
```

---

### Task 15: 전체 회귀 + 통합 검증

- [ ] **Step 1: 전체 테스트**

Run: `xcodebuild ... test`
Expected: 모든 타겟 PASS (`AppCoreTests`·`CompositionServiceTests`·`PhotosServiceTests`·`TimelineFeatureTests`).

- [ ] **Step 2: 통합 시각 검증(ios-build-run)**

`ChalNa Dev` 로 전체 플로우: MediaPicker → Timeline(프리뷰 9:16/블러) → 조정(핀치/팬/회전/리셋) → 저장 → Export(1080×1920, 블러 필, 클립별 프레이밍 반영) → FilmDetail(세로 커버). 가로·세로·정사각·Live Photo 혼합으로 1회.

- [ ] **Step 3: 최종 확인 커밋(필요 시 미세 조정)**

```bash
git add -A && git commit -m "chore: 9:16 출력 + 클립 프레이밍 통합 검증 및 미세 조정"
```

---

## Self-Review 결과 (작성자 점검)

**Spec coverage:**
- 출력 9:16 고정 → Task 1. ✅
- 커버/저장본 비율 교정 → Task 2. ✅
- ClipTransform/ClipFraming(SSOT) → Task 3·4. ✅
- transform scale/offset + placedRect 분리(자막 결합 끊기) → Task 5. ✅
- EditSession.scales + replace/clear 초기화 → Task 6. ✅
- 클라이언트~buildComposition 관통 → Task 7. ✅
- Export 플로우 전달 → Task 8. ✅
- 블러 필 배경 + 게이팅 변경 → Task 9. ✅
- 조정 화면(라우트/Feature/View, 회전 통합) → Task 10·11·12·13. ✅
- 프리뷰 WYSIWYG → Task 14. ✅
- 테스트 전략(ClipFraming/transform/renderSize/EditSession) → Task 1·4·5·6. ✅

**Type consistency:** `ClipTransform(scale:offset:)`·`.fit`, `ClipFraming.{fitScale,clampedOffset,resolvedRect,orientedSize}`, `EditSession.{scales,transform(for:),setTransform(_:for:),resetTransform(for:)}`, `transform(...,framing:)`, `CompositionClient.export(_,_,scales,_,_)`, `Route.clipAdjust(clipID:)`·`AppFeature.routerPushedClipAdjust(clipID:)`·`Path.clipAdjust(ClipAdjustFeature)`·`ClipAdjustFeature.State(clipID:)`, `EditToolbar.onAdjust` — 전 태스크 일관. ✅

**리스크 메모:** 블러는 단위 테스트 불가 → 시각 검증 의존(Task 9·15). 프리뷰/조정 View 코드는 시뮬레이터에서 레이아웃 미세조정 가능(`previewHeight`, `coverWidth` clamp). transform `.fit` 회귀 케이스가 기존 기대값과 동일함을 Task 5 에서 강제. `resolveRenderSize` 시그니처 유지로 호출부(`:165`) 무변경.
