# 클립별 사용자 라벨 (Per-Clip Custom Label) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 타임라인의 모든 클립에 사용자가 텍스트 라벨(폰트·스타일·크기·자유 위치)을 붙이고, export 시 클립 구간에만 영상에 burn-in 한다.

**Architecture:** 회전(`ClipRotation`)과 동일하게 라벨도 per-clip 값 타입(`ClipLabel`)으로 `EditSession` 딕셔너리에 보관한다. 편집은 `TimelineView`에서 `.fullScreenCover`로 띄우는 `LabelEditorView`(자유 드래그)로 한다. 합성은 기존 `AVVideoCompositionCoreAnimationTool`/`CATextLayer` 파이프라인을 확장해 클립의 placedRect(캔버스 내 이미지 사각형) 기준으로 라벨을 그린다.

**Tech Stack:** Swift 6 / SwiftUI / TCA / AVFoundation(CATextLayer) / Tuist / Swift Testing.

**Spec:** `docs/superpowers/specs/2026-05-31-clip-label-design.md`

**사전 준비:** 워크스페이스가 이미 생성돼 있다고 가정(`tuist generate` 완료). 빌드/시뮬레이터 실행은 가능하면 `ios-build-run` 서브에이전트에 위임. 테스트는 `ChalNa` 스킴으로 실행.

**공통 빌드/테스트 명령:**
```bash
# 단위 테스트 (특정 타입)
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:AppCoreTests/ClipLabelTests

# 전체 앱 빌드(컴파일 검증)
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

> Sources/Tests 폴더는 Tuist `buildableFolders`(동기화 그룹)라 **새 .swift 파일 추가는 `tuist generate` 불필요**. `Project.swift` 변경(Task 4)만 재생성이 필요하다.

---

## File Structure

**신규**
- `Modules/Models/Sources/ClipLabel.swift` — per-clip 라벨 값 타입 + `LabelFont`/`LabelTextStyle` enum.
- `Modules/AppCore/Tests/ClipLabelTests.swift` — ClipLabel 모델 테스트.
- `Modules/AppCore/Tests/EditSessionLabelTests.swift` — EditSession 라벨 accessor 테스트.
- `Modules/CompositionService/Tests/CustomLabelLayoutTests.swift` — placedRect/customLabelOrigin 좌표 테스트.
- `Modules/TimelineFeature/Sources/LabelEditorView.swift` — 전체화면 라벨 에디터.

**변경**
- `Modules/AppCore/Sources/EditSession.swift`
- `Modules/DesignSystem/Sources/Icons/ChalNaIcon.swift`
- `Modules/DesignSystem/Sources/Tokens/ChalNaTypography.swift`
- `Project.swift`
- `Modules/CompositionService/Sources/CompositionService.swift`
- `Modules/CompositionService/Sources/CompositionClient.swift`
- `Modules/ExportFeature/Sources/ExportFeature.swift`
- `Modules/ExportFeature/Sources/ExportView.swift`
- `Modules/TimelineFeature/Sources/Components/EditToolbar.swift`
- `Modules/TimelineFeature/Sources/TimelineView.swift`

---

## Task 1: ClipLabel 모델 (Models)

**Files:**
- Create: `Modules/Models/Sources/ClipLabel.swift`
- Test: `Modules/AppCore/Tests/ClipLabelTests.swift`

> Models 전용 테스트 타겟이 없으므로(기존 `ClipRotationTests` 선례) 모델 테스트는 `AppCoreTests`(deps: Models)에 둔다.

- [ ] **Step 1: 실패하는 테스트 작성**

Create `Modules/AppCore/Tests/ClipLabelTests.swift`:
```swift
import Foundation
import Testing
import CoreGraphics
import Models

struct ClipLabelTests {

    @Test func defaultIsInvisibleAndCentered() {
        let l = ClipLabel.default
        #expect(l.isVisible == false)
        #expect(l.position == CGPoint(x: 0.5, y: 0.5))
        #expect(l.font == .memoment)
        #expect(l.style == .plain)
        #expect(l.sizeFraction == 0.10)
    }

    @Test func isVisibleIgnoresWhitespace() {
        #expect(ClipLabel(text: "   ").isVisible == false)
        #expect(ClipLabel(text: "\n ").isVisible == false)
        #expect(ClipLabel(text: "제주 바다").isVisible == true)
    }

    @Test func sizeFractionClamps() {
        #expect(ClipLabel(sizeFraction: 0.001).clampedSizeFraction == ClipLabel.minSizeFraction)
        #expect(ClipLabel(sizeFraction: 9).clampedSizeFraction == ClipLabel.maxSizeFraction)
        #expect(ClipLabel(sizeFraction: 0.1).clampedSizeFraction == 0.1)
    }

    @Test func displayNames() {
        #expect(LabelFont.memoment.displayName == "꾸꾸")
        #expect(LabelFont.system.displayName == "기본")
        #expect(LabelTextStyle.plain.displayName == "검정 글자")
        #expect(LabelTextStyle.boxed.displayName == "흰 글자 + 검정 배경")
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run:
```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:AppCoreTests/ClipLabelTests
```
Expected: 컴파일 실패 — "cannot find 'ClipLabel' in scope".

- [ ] **Step 3: 모델 구현**

Create `Modules/Models/Sources/ClipLabel.swift`:
```swift
import CoreGraphics
import Foundation

/// 편집 세션 동안 클립별로 사용자가 붙이는 텍스트 라벨. 회전(`ClipRotation`)과 같은 per-clip 메타로,
/// 불변 `Clip` 이 아니라 `EditSession` 의 딕셔너리에 담는다.
public struct ClipLabel: Equatable, Sendable {
    /// 라벨 문구. 빈/공백 문자열이면 라벨 없음으로 취급.
    public var text: String
    /// 글꼴. `.memoment`("꾸꾸") 또는 `.system`(기본).
    public var font: LabelFont
    /// 표시 스타일. `.plain`(검정 글자, 배경 없음) 또는 `.boxed`(흰 글자 + 검정 배경).
    public var style: LabelTextStyle
    /// 클립 이미지 높이 대비 글자 크기 비율. `clampedSizeFraction` 으로 0.04...0.25 클램프해 사용.
    public var sizeFraction: CGFloat
    /// 클립 이미지 사각형 기준 정규화 위치(라벨 중심). x,y ∈ 0...1, y는 위(0)→아래(1) 스크린 방향.
    public var position: CGPoint

    public init(
        text: String = "",
        font: LabelFont = .memoment,
        style: LabelTextStyle = .plain,
        sizeFraction: CGFloat = 0.10,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) {
        self.text = text
        self.font = font
        self.style = style
        self.sizeFraction = sizeFraction
        self.position = position
    }

    /// 화면/영상에 그릴 라벨이 있는지.
    public var isVisible: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 슬라이더 허용 범위.
    public static let minSizeFraction: CGFloat = 0.04
    public static let maxSizeFraction: CGFloat = 0.25

    /// 클램프된 크기 비율.
    public var clampedSizeFraction: CGFloat {
        min(max(sizeFraction, Self.minSizeFraction), Self.maxSizeFraction)
    }

    public static let `default` = ClipLabel()
}

/// 라벨 글꼴 선택.
public enum LabelFont: String, Sendable, CaseIterable, Codable {
    case memoment
    case system
    public var displayName: String { self == .memoment ? "꾸꾸" : "기본" }
}

/// 라벨 표시 스타일.
public enum LabelTextStyle: String, Sendable, CaseIterable, Codable {
    case plain   // 검정 글자, 배경 없음
    case boxed   // 흰 글자 + 검정 배경
    public var displayName: String { self == .plain ? "검정 글자" : "흰 글자 + 검정 배경" }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: (Step 2 명령 동일)
Expected: PASS (4 tests).

- [ ] **Step 5: 커밋**

```bash
git add Modules/Models/Sources/ClipLabel.swift Modules/AppCore/Tests/ClipLabelTests.swift
git commit -m "✨ feat: 클립별 라벨 값 타입 ClipLabel 추가"
```

---

## Task 2: EditSession 라벨 통합 (AppCore)

**Files:**
- Modify: `Modules/AppCore/Sources/EditSession.swift`
- Test: `Modules/AppCore/Tests/EditSessionLabelTests.swift`

- [ ] **Step 1: 실패하는 테스트 작성**

Create `Modules/AppCore/Tests/EditSessionLabelTests.swift`:
```swift
import Foundation
import Testing
import CoreGraphics
import Models
import AppCore

struct EditSessionLabelTests {

    @Test func defaultLabelOnMiss() {
        let session = EditSession()
        let id = UUID()
        #expect(session.label(for: id) == .default)
        #expect(session.label(for: id).isVisible == false)
    }

    @Test func setAndReadLabel() {
        let session = EditSession()
        let id = UUID()
        var l = ClipLabel(text: "성산일출봉", font: .system, style: .boxed)
        l.position = CGPoint(x: 0.2, y: 0.8)
        session.setLabel(l, for: id)
        #expect(session.label(for: id) == l)
        #expect(session.label(for: id).isVisible == true)
    }

    @Test func replaceResetsLabels() {
        let session = EditSession()
        let id = UUID()
        session.setLabel(ClipLabel(text: "x"), for: id)
        session.replace(clips: [], title: "새 필름")
        #expect(session.label(for: id) == .default)
    }

    @Test func clearResetsLabels() {
        let session = EditSession()
        let id = UUID()
        session.setLabel(ClipLabel(text: "x"), for: id)
        session.clear()
        #expect(session.label(for: id) == .default)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run:
```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:AppCoreTests/EditSessionLabelTests
```
Expected: 컴파일 실패 — "value of type 'EditSession' has no member 'label'".

- [ ] **Step 3: EditSession 구현**

In `Modules/AppCore/Sources/EditSession.swift`:

3a. 저장 프로퍼티 추가 — `rotations` 선언(11번 줄 부근) 바로 아래에:
```swift
    /// 클립별 사용자 라벨. dict miss = `.default`(빈 라벨).
    public var labels: [Clip.ID: ClipLabel]
```

3b. `init` 시그니처/본문 갱신 — 기존 init을 다음으로 교체:
```swift
    public init(
        title: String = "",
        clips: [Clip] = [],
        rotations: [Clip.ID: ClipRotation] = [:],
        labels: [Clip.ID: ClipLabel] = [:]
    ) {
        self.title = title
        self.clips = clips
        self.rotations = rotations
        self.labels = labels
    }
```

3c. `replace(clips:title:)` 에 `labels = [:]` 추가:
```swift
    public func replace(clips: [Clip], title: String) {
        self.clips = clips
        self.title = title
        self.rotations = [:]
        self.labels = [:]
    }
```

3d. `clear()` 에 `labels = [:]` 추가:
```swift
    public func clear() {
        clips = []
        title = ""
        rotations = [:]
        labels = [:]
    }
```

3e. accessor 추가 — `cycleRotation(for:)` 아래(파일 끝 `}` 직전)에:
```swift
    // MARK: - Label

    public func label(for id: Clip.ID) -> ClipLabel {
        labels[id] ?? .default
    }

    public func setLabel(_ label: ClipLabel, for id: Clip.ID) {
        labels[id] = label
    }
```

- [ ] **Step 4: 테스트 통과 확인**

Run: (Step 2 명령 동일)
Expected: PASS (4 tests). 기존 `ClipRotationTests`/`ClipLabelTests` 도 깨지지 않음.

- [ ] **Step 5: 커밋**

```bash
git add Modules/AppCore/Sources/EditSession.swift Modules/AppCore/Tests/EditSessionLabelTests.swift
git commit -m "✨ feat: EditSession 에 per-clip 라벨 상태 추가"
```

---

## Task 3: DesignSystem — textLabel 아이콘 + memoment 폰트

**Files:**
- Modify: `Modules/DesignSystem/Sources/Icons/ChalNaIcon.swift`
- Modify: `Modules/DesignSystem/Sources/Tokens/ChalNaTypography.swift`

> 단위 테스트 없음(렌더). 빌드 컴파일로 검증.

- [ ] **Step 1: 아이콘 케이스 추가**

In `Modules/DesignSystem/Sources/Icons/ChalNaIcon.swift`:

1a. enum 에 케이스 추가(`case rotate` 줄 아래):
```swift
    case rotate
    case textLabel
```

1b. body 의 SF Symbol 분기를 `.rotate`/`.textLabel` 둘 다 처리하도록 교체:
```swift
    public var body: some View {
        if kind == .rotate || kind == .textLabel {
            Image(systemName: kind == .rotate ? "rotate.left" : "textformat")
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.monochrome)
                .frame(width: size, height: size)
        } else {
            LucideShape(kind: kind)
                .stroke(style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
                .frame(width: size, height: size)
        }
    }
```

1c. `subpaths(for:)` switch 의 exhaustiveness 를 위해 `.rotate` 처리 옆에 `.textLabel` 추가 — `case .rotate: return []` 을 다음으로 교체:
```swift
        case .rotate, .textLabel:
            return []
```

- [ ] **Step 2: memoment 폰트 함수 추가**

In `Modules/DesignSystem/Sources/Tokens/ChalNaTypography.swift`, `keris(...)` 함수 + `kerisFontName` 블록(48~75줄) **아래**에 추가:
```swift
    // MARK: - Memoment(꾸꾸) — 사용자 라벨용 커스텀 폰트
    // UIAppFonts 로 등록된 MemomentKkukkukk 패밀리를 런타임 탐색(이름은 EUC 인코딩이라 하드코딩 금지).
    // 매칭 실패 시 시스템 폰트 fallback. 영상 합성쪽 overlayCustomUIFont 와 동일 family 를 쓴다.
    public static func memoment(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        #if canImport(UIKit)
        if let name = memomentFontName, UIFont(name: name, size: size) != nil {
            return Font.custom(name, size: size)
        }
        #endif
        return Font.system(size: size, weight: weight, design: .default)
    }

    #if canImport(UIKit)
    private static let memomentFontName: String? = {
        let families = UIFont.familyNames.filter { $0.localizedCaseInsensitiveContains("Memoment") }
        for family in families {
            let names = UIFont.fontNames(forFamilyName: family)
            if let any = names.first { return any }
        }
        return nil
    }()
    #endif
```

- [ ] **Step 3: 빌드 컴파일 확인**

Run:
```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: 커밋**

```bash
git add Modules/DesignSystem/Sources/Icons/ChalNaIcon.swift Modules/DesignSystem/Sources/Tokens/ChalNaTypography.swift
git commit -m "✨ feat: DesignSystem 에 textLabel 아이콘·memoment 폰트 헬퍼 추가"
```

---

## Task 4: 폰트 번들 등록 (Project.swift + tuist generate)

**Files:**
- Modify: `Project.swift:127-129`

- [ ] **Step 1: UIAppFonts 에 폰트 추가**

In `Project.swift`, `UIAppFonts` 배열을 교체:
```swift
                    "UIAppFonts": [
                        "KERISKEDU_Line.otf",
                        "MemomentKkukkukk.ttf",
                    ],
```

- [ ] **Step 2: 프로젝트 재생성**

Run:
```bash
tuist generate
```
Expected: 성공. `Derived/InfoPlists/ChalNa-Info.plist` 의 `UIAppFonts` 에 `MemomentKkukkukk.ttf` 포함됨.

- [ ] **Step 3: 등록 검증(빌드 + 진단 로그)**

Run:
```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: BUILD SUCCEEDED.

> 런타임 폰트 매칭은 Task 11 의 시뮬레이터 실행에서 콘솔의 `[CompositionService] Memoment families:` 로그로 확인(빈 배열이면 등록 실패 — fallback 동작은 정상이나 폰트 미적용).

- [ ] **Step 4: 커밋**

```bash
git add Project.swift
git commit -m "✨ feat: MemomentKkukkukk 폰트 UIAppFonts 등록"
```

---

## Task 5: 합성 좌표 헬퍼 (CompositionService 순수 함수)

**Files:**
- Modify: `Modules/CompositionService/Sources/CompositionService.swift`
- Test: `Modules/CompositionService/Tests/CustomLabelLayoutTests.swift`

- [ ] **Step 1: 실패하는 테스트 작성**

Create `Modules/CompositionService/Tests/CustomLabelLayoutTests.swift`:
```swift
import Foundation
import Testing
import CoreGraphics
import Models
@testable import CompositionService

struct CustomLabelLayoutTests {

    // 1920x1080 가로 영상을 1080x1920 세로 캔버스에 aspectFit → 위아래 레터박스.
    @Test func placedRectLandscapeIntoPortrait() {
        let rect = AVFoundationCompositionService.placedRect(
            naturalSize: CGSize(width: 1920, height: 1080),
            preferredTransform: .identity,
            rotation: .r0,
            renderSize: CGSize(width: 1080, height: 1920)
        )
        #expect(rect.origin.x == 0)
        #expect(rect.origin.y == 656.25)
        #expect(rect.size.width == 1080)
        #expect(rect.size.height == 607.5)
    }

    // 같은 비율(1080x1920)은 캔버스를 꽉 채운다.
    @Test func placedRectSameAspectFills() {
        let rect = AVFoundationCompositionService.placedRect(
            naturalSize: CGSize(width: 1080, height: 1920),
            preferredTransform: .identity,
            rotation: .r0,
            renderSize: CGSize(width: 1080, height: 1920)
        )
        #expect(rect == CGRect(x: 0, y: 0, width: 1080, height: 1920))
    }

    // 정중앙(0.5,0.5) 라벨의 좌하단 origin (CoreAnimation y-up).
    @Test func customLabelOriginCenter() {
        let placed = CGRect(x: 0, y: 656.25, width: 1080, height: 607.5)
        let origin = AVFoundationCompositionService.customLabelOrigin(
            placedRect: placed,
            position: CGPoint(x: 0.5, y: 0.5),
            textSize: CGSize(width: 200, height: 80),
            renderSize: CGSize(width: 1080, height: 1920)
        )
        // 중심 top-down=(540,960) → y-up center=960 → origin=(440,920)
        #expect(origin.x == 440)
        #expect(origin.y == 920)
    }

    // 상단(0.5,0.1) — 화면 위쪽이면 y-up origin 이 커진다.
    @Test func customLabelOriginTopArea() {
        let placed = CGRect(x: 0, y: 0, width: 1080, height: 1920)
        let origin = AVFoundationCompositionService.customLabelOrigin(
            placedRect: placed,
            position: CGPoint(x: 0.5, y: 0.1),
            textSize: CGSize(width: 300, height: 100),
            renderSize: CGSize(width: 1080, height: 1920)
        )
        // 중심 top-down=(540,192) → y-up center=1728 → origin=(390,1678)
        #expect(origin.x == 390)
        #expect(origin.y == 1678)
    }

    // 정규화 좌표는 0...1 로 클램프된다.
    @Test func customLabelOriginClamps() {
        let placed = CGRect(x: 0, y: 0, width: 1000, height: 2000)
        let origin = AVFoundationCompositionService.customLabelOrigin(
            placedRect: placed,
            position: CGPoint(x: 2.0, y: -1.0),  // → (1, 0)
            textSize: CGSize(width: 100, height: 40),
            renderSize: CGSize(width: 1000, height: 2000)
        )
        // 중심 top-down=(1000,0) → y-up center=2000 → origin=(950,1980)
        #expect(origin.x == 950)
        #expect(origin.y == 1980)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run:
```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:CompositionServiceTests/CustomLabelLayoutTests
```
Expected: 컴파일 실패 — "type 'AVFoundationCompositionService' has no member 'placedRect'".

- [ ] **Step 3: 순수 헬퍼 구현**

In `Modules/CompositionService/Sources/CompositionService.swift`, `// MARK: - Transform helper` 섹션의 `transform(...)` 함수 **아래**(`minDisplayDimension` 은 이미 같은 타입에 존재)에 추가:
```swift
    /// 한 클립이 renderSize 안에서 aspectFit + 가운데 정렬됐을 때 차지하는 사각형.
    /// `transform()` 과 동일한 fit-scale·center 계산을 공유한다. 가운데 정렬이라 y-up/y-down 무관.
    public static func placedRect(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        rotation: ClipRotation,
        renderSize: CGSize
    ) -> CGRect {
        let displayRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let displaySize = CGSize(width: abs(displayRect.width), height: abs(displayRect.height))
        let postRotationSize: CGSize = rotation.swapsAxes
            ? CGSize(width: displaySize.height, height: displaySize.width)
            : displaySize
        let safeW = max(postRotationSize.width, minDisplayDimension)
        let safeH = max(postRotationSize.height, minDisplayDimension)
        let fitScaleRaw = min(renderSize.width / safeW, renderSize.height / safeH)
        let fitScale: CGFloat = (fitScaleRaw.isFinite && fitScaleRaw > 0) ? fitScaleRaw : 1.0
        let scaledSize = CGSize(
            width: postRotationSize.width * fitScale,
            height: postRotationSize.height * fitScale
        )
        let origin = CGPoint(
            x: (renderSize.width - scaledSize.width) / 2,
            y: (renderSize.height - scaledSize.height) / 2
        )
        return CGRect(origin: origin, size: scaledSize)
    }

    /// 클립 이미지 사각형 기준 정규화 위치(라벨 중심, y=위→아래)를
    /// CoreAnimation 좌하단 origin 으로 변환. 텍스트 박스의 좌측 하단 좌표를 돌려준다.
    public static func customLabelOrigin(
        placedRect: CGRect,
        position: CGPoint,
        textSize: CGSize,
        renderSize: CGSize
    ) -> CGPoint {
        let nx = min(max(position.x, 0), 1)
        let ny = min(max(position.y, 0), 1)
        let centerXTopDown = placedRect.minX + nx * placedRect.width
        let centerYTopDown = placedRect.minY + ny * placedRect.height
        let centerYUp = renderSize.height - centerYTopDown
        return CGPoint(x: centerXTopDown - textSize.width / 2, y: centerYUp - textSize.height / 2)
    }
```

> `minDisplayDimension` 은 `private static let minDisplayDimension: CGFloat = 1.0` 으로 이미 같은 타입에 정의돼 있어 접근 가능하다.

- [ ] **Step 4: 테스트 통과 확인**

Run: (Step 2 명령 동일)
Expected: PASS (5 tests).

- [ ] **Step 5: 커밋**

```bash
git add Modules/CompositionService/Sources/CompositionService.swift Modules/CompositionService/Tests/CustomLabelLayoutTests.swift
git commit -m "✨ feat: 라벨 배치용 placedRect·customLabelOrigin 좌표 헬퍼 추가"
```

---

## Task 6: 합성에 커스텀 라벨 burn-in (CompositionService)

**Files:**
- Modify: `Modules/CompositionService/Sources/CompositionService.swift`

> 이 Task 까지는 `CompositionClient` 가 3-인자 편의 오버로드를 쓰므로 앱이 계속 컴파일된다.

- [ ] **Step 1: 프로토콜 + 편의 오버로드 갱신**

`CompositionServicing` 프로토콜(37~40줄)과 그 extension(42~51줄)을 교체:
```swift
public protocol CompositionServicing: Sendable {
    /// 클립 배열·회전·자동 라벨 설정·클립별 사용자 라벨을 받아 mp4를 만들고 진행률/완료/실패를 스트림으로 흘려보낸다.
    func export(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        labelSettings: LabelSettings,
        clipLabels: [Clip.ID: ClipLabel]
    ) -> AsyncStream<ExportEvent>
}

public extension CompositionServicing {
    /// 사용자 라벨 없는 호출 → 빈 라벨(현행 동작).
    func export(clips: [Clip], rotations: [Clip.ID: ClipRotation], labelSettings: LabelSettings) -> AsyncStream<ExportEvent> {
        export(clips: clips, rotations: rotations, labelSettings: labelSettings, clipLabels: [:])
    }
    /// 라벨 설정 없는 호출 → 기본값.
    func export(clips: [Clip], rotations: [Clip.ID: ClipRotation]) -> AsyncStream<ExportEvent> {
        export(clips: clips, rotations: rotations, labelSettings: .default, clipLabels: [:])
    }
    /// 회전·라벨 설정 없는 호출.
    func export(clips: [Clip]) -> AsyncStream<ExportEvent> {
        export(clips: clips, rotations: [:], labelSettings: .default, clipLabels: [:])
    }
}
```

- [ ] **Step 2: actor export/run 시그니처 갱신**

`AVFoundationCompositionService` 의 `export(...)`(57~72줄)와 `run(...)`(76~127줄) 시그니처에 `clipLabels` 추가:

2a. `export`:
```swift
    public nonisolated func export(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        labelSettings: LabelSettings,
        clipLabels: [Clip.ID: ClipLabel]
    ) -> AsyncStream<ExportEvent> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                await self.run(clips: clips, rotations: rotations, labelSettings: labelSettings, clipLabels: clipLabels, continuation: continuation)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
```

2b. `run` 시그니처 + `buildComposition` 호출:
```swift
    private func run(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        labelSettings: LabelSettings,
        clipLabels: [Clip.ID: ClipLabel],
        continuation: AsyncStream<ExportEvent>.Continuation
    ) async {
        do {
            let built = try await buildComposition(clips: clips, rotations: rotations, labelSettings: labelSettings, clipLabels: clipLabels)
```
(이하 `run` 본문은 그대로)

- [ ] **Step 3: buildComposition — entries 확장 + 라벨 가드**

3a. `buildComposition` 시그니처(137~141줄)에 `clipLabels` 추가:
```swift
    private func buildComposition(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        labelSettings: LabelSettings,
        clipLabels: [Clip.ID: ClipLabel]
    ) async throws -> BuiltComposition {
```

3b. `layerInstructions` 튜플 타입(157줄)을 교체:
```swift
        var layerInstructions: [(timeRange: CMTimeRange, transform: CGAffineTransform, capturedAt: Date, clipID: Clip.ID, placedRect: CGRect)] = []
```

3c. 클립 루프 안 `layerInstructions.append(...)`(202~203줄)를 교체 — placedRect 계산 추가:
```swift
            let placedRange = CMTimeRange(start: cursor, duration: clipDuration)
            let pRect = Self.placedRect(
                naturalSize: naturalSize,
                preferredTransform: preferredTransform,
                rotation: userRotation,
                renderSize: renderSize
            )
            layerInstructions.append((placedRange, transform, clip.capturedAt, clip.id, pRect))
```

3d. videoComposition.instructions 매핑(214~221줄)은 `entry.timeRange`/`entry.transform` 만 쓰므로 **변경 불필요**(추가 필드 무시됨).

3e. 라벨 오버레이 가드/호출(223~230줄)을 교체:
```swift
        // 4) 각 클립 placedRange 동안 라벨 오버레이 (자동 시간/날짜 + 사용자 커스텀 라벨).
        let hasVisibleCustomLabel = clipLabels.values.contains { $0.isVisible }
        if hasContent && (labelSettings.timeEnabled || labelSettings.dateEnabled || hasVisibleCustomLabel) {
            videoComposition.animationTool = Self.makeDateLabelAnimationTool(
                renderSize: renderSize,
                entries: layerInstructions.map { ($0.timeRange, $0.capturedAt, $0.clipID, $0.placedRect) },
                labelSettings: labelSettings,
                clipLabels: clipLabels
            )
        }
```

- [ ] **Step 4: makeDateLabelAnimationTool 갱신**

4a. 시그니처(309~313줄) 교체:
```swift
    private static func makeDateLabelAnimationTool(
        renderSize: CGSize,
        entries: [(timeRange: CMTimeRange, capturedAt: Date, clipID: Clip.ID, placedRect: CGRect)],
        labelSettings: LabelSettings,
        clipLabels: [Clip.ID: ClipLabel]
    ) -> AVVideoCompositionCoreAnimationTool {
```

4b. `for entry in entries { ... }` 루프 **끝(385줄 닫는 `}` 직전, 시간/날짜 레이어 추가 코드 다음)** 에 커스텀 라벨 렌더 추가:
```swift
            #if canImport(UIKit)
            let custom = clipLabels[entry.clipID] ?? .default
            if custom.isVisible {
                for layer in makeCustomLabelLayers(
                    label: custom,
                    placedRect: entry.placedRect,
                    renderSize: renderSize,
                    timeRange: entry.timeRange
                ) {
                    parentLayer.addSublayer(layer)
                }
            }
            #endif
```

- [ ] **Step 5: 커스텀 라벨 레이어/폰트/측정 헬퍼 추가**

`makeOverlayTextLayer(...)` 함수(477줄 닫는 `}`) **아래**, `// MARK: - RenderSize` **위**에 추가:
```swift
    #if canImport(UIKit)
    /// 커스텀 라벨용 UIFont. `.memoment` 는 등록된 MemomentKkukkukk family 런타임 탐색(첫 호출 1회 진단 print),
    /// 실패하거나 `.system` 이면 시스템 semibold.
    private static let memomentLabelFontName: String = {
        let families = UIFont.familyNames.filter { $0.localizedCaseInsensitiveContains("Memoment") }
        print("[CompositionService] Memoment families: \(families)")
        for family in families {
            let names = UIFont.fontNames(forFamilyName: family)
            print("[CompositionService] family=\(family) names=\(names)")
            if let any = names.first { return any }
        }
        return ""
    }()

    private static func overlayCustomUIFont(font: LabelFont, fontSize: CGFloat) -> UIFont {
        if font == .memoment, !memomentLabelFontName.isEmpty,
           let f = UIFont(name: memomentLabelFontName, size: fontSize) {
            return f
        }
        return .systemFont(ofSize: fontSize, weight: .semibold)
    }

    /// 커스텀 라벨 텍스트 실측(선택 폰트 기준).
    private static func measureCustomText(_ text: String, font: LabelFont, fontSize: CGFloat) -> CGSize {
        let attributed = NSAttributedString(
            string: text,
            attributes: [.font: overlayCustomUIFont(font: font, fontSize: fontSize)]
        )
        let m = attributed.size()
        return CGSize(width: ceil(m.width), height: ceil(m.height))
    }

    /// 사용자 라벨 한 개를 그릴 레이어들(배경 박스가 있으면 [bg, text], 없으면 [text]).
    /// 모두 클립 `timeRange` 동안만 보인다.
    private static func makeCustomLabelLayers(
        label: ClipLabel,
        placedRect: CGRect,
        renderSize: CGSize,
        timeRange: CMTimeRange
    ) -> [CALayer] {
        let fontSize = max(8, label.clampedSizeFraction * placedRect.height)
        let textSize = measureCustomText(label.text, font: label.font, fontSize: fontSize)
        let textColor: UIColor = (label.style == .plain) ? .black : .white
        let origin = customLabelOrigin(placedRect: placedRect, position: label.position, textSize: textSize, renderSize: renderSize)

        let textLayer = CATextLayer()
        textLayer.string = NSAttributedString(
            string: label.text,
            attributes: [
                .font: overlayCustomUIFont(font: label.font, fontSize: fontSize),
                .foregroundColor: textColor,
            ]
        )
        textLayer.contentsScale = 2.0
        textLayer.isWrapped = false
        textLayer.alignmentMode = .center
        textLayer.frame = CGRect(origin: origin, size: textSize)
        textLayer.opacity = 0
        addShowAnimation(to: textLayer, timeRange: timeRange)

        guard label.style == .boxed else { return [textLayer] }

        let padX = fontSize * 0.35
        let padY = fontSize * 0.22
        let bgLayer = CALayer()
        bgLayer.frame = CGRect(
            x: origin.x - padX,
            y: origin.y - padY,
            width: textSize.width + padX * 2,
            height: textSize.height + padY * 2
        )
        bgLayer.backgroundColor = UIColor.black.cgColor
        bgLayer.cornerRadius = min(bgLayer.frame.height * 0.18, 12)
        bgLayer.opacity = 0
        addShowAnimation(to: bgLayer, timeRange: timeRange)
        return [bgLayer, textLayer]
    }

    /// 레이어를 클립 `timeRange` 동안만 opacity=1 로 보이게 하는 애니메이션(그 외엔 model value 0).
    private static func addShowAnimation(to layer: CALayer, timeRange: CMTimeRange) {
        let show = CABasicAnimation(keyPath: "opacity")
        show.fromValue = 1.0
        show.toValue = 1.0
        show.beginTime = AVCoreAnimationBeginTimeAtZero + CMTimeGetSeconds(timeRange.start)
        show.duration = max(0.01, CMTimeGetSeconds(timeRange.duration))
        show.fillMode = .removed
        show.isRemovedOnCompletion = false
        layer.add(show, forKey: "show")
    }
    #endif
```

- [ ] **Step 6: 컴파일 확인**

Run:
```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: BUILD SUCCEEDED. (CompositionClient 는 아직 3-인자 편의 오버로드 사용 → 정상.)

- [ ] **Step 7: 커밋**

```bash
git add Modules/CompositionService/Sources/CompositionService.swift
git commit -m "✨ feat: 영상 합성에 클립별 사용자 라벨 burn-in 추가"
```

---

## Task 7: Export 배선 — clipLabels 전달 (Client → Feature → View)

**Files:**
- Modify: `Modules/CompositionService/Sources/CompositionClient.swift`
- Modify: `Modules/ExportFeature/Sources/ExportFeature.swift`
- Modify: `Modules/ExportFeature/Sources/ExportView.swift`

> 세 파일이 한 시그니처 변경을 공유한다. 셋 다 고친 뒤 한 번에 빌드/커밋한다.

- [ ] **Step 1: CompositionClient 시그니처 확장**

`Modules/CompositionService/Sources/CompositionClient.swift` 전체 교체:
```swift
import Foundation
import ComposableArchitecture
import Models

/// AVFoundationCompositionService 를 TCA @DependencyClient 로 노출한 형태.
@DependencyClient
public struct CompositionClient: Sendable {
    public var export: @Sendable (
        _ clips: [Clip],
        _ rotations: [Clip.ID: ClipRotation],
        _ labelSettings: LabelSettings,
        _ clipLabels: [Clip.ID: ClipLabel]
    ) -> AsyncStream<ExportEvent> = { _, _, _, _ in
        AsyncStream { $0.finish() }
    }
}

extension CompositionClient: DependencyKey {
    public static let liveValue: CompositionClient = {
        let service = AVFoundationCompositionService()
        return CompositionClient(
            export: { clips, rotations, labelSettings, clipLabels in
                service.export(clips: clips, rotations: rotations, labelSettings: labelSettings, clipLabels: clipLabels)
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

- [ ] **Step 2: ExportFeature 액션/리듀서 갱신**

`Modules/ExportFeature/Sources/ExportFeature.swift`:

2a. `Action` 의 startExport/retryTapped(66, 71줄)에 `clipLabels` 추가:
```swift
        case startExport(clips: [Clip], rotations: [Clip.ID: ClipRotation], clipLabels: [Clip.ID: ClipLabel])
```
```swift
        case retryTapped(clips: [Clip], rotations: [Clip.ID: ClipRotation], clipLabels: [Clip.ID: ClipLabel])
```

2b. `.startExport` 케이스(100줄) 패턴/호출 갱신:
```swift
            case let .startExport(clips, rotations, clipLabels):
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
                    for await event in compositionClient.export(clips, rotations, labelSettings, clipLabels) {
                        switch event {
                        case let .progress(p):
                            await send(.exportProgress(p))
                        case let .completed(url):
                            await send(.exportCompleted(url))
                        case let .failed(msg):
                            await send(.exportFailed(msg))
                        }
                    }
                }
                .cancellable(id: CancelID.exportStream, cancelInFlight: true)
```

2c. `.retryTapped` 케이스(154줄) 갱신:
```swift
            case let .retryTapped(clips, rotations, clipLabels):
                return .send(.startExport(clips: clips, rotations: rotations, clipLabels: clipLabels))
```

- [ ] **Step 3: ExportView 호출부 갱신**

`Modules/ExportFeature/Sources/ExportView.swift` — 3곳:

3a. `.onAppear`(51줄):
```swift
            store.send(.startExport(clips: session.clips, rotations: session.rotations, clipLabels: session.labels))
```

3b. paperFailedCTAs 의 다시 시도(444줄):
```swift
                store.send(.retryTapped(clips: session.clips, rotations: session.rotations, clipLabels: session.labels))
```

3c. liquidGlassFailedCTAs 의 다시 시도(465줄):
```swift
                    store.send(.retryTapped(clips: session.clips, rotations: session.rotations, clipLabels: session.labels))
```

- [ ] **Step 4: 빌드 확인**

Run:
```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: 커밋**

```bash
git add Modules/CompositionService/Sources/CompositionClient.swift Modules/ExportFeature/Sources/ExportFeature.swift Modules/ExportFeature/Sources/ExportView.swift
git commit -m "✨ feat: export 파이프라인에 클립 라벨(clipLabels) 전달"
```

---

## Task 8: EditToolbar 에 '라벨' 항목 추가 (TimelineFeature)

**Files:**
- Modify: `Modules/TimelineFeature/Sources/Components/EditToolbar.swift`

> 새 파라미터는 기본값을 줘서 기존 `TimelineView` 호출이 깨지지 않게 한다(Task 10 에서 실제 값 전달).

- [ ] **Step 1: 프로퍼티 추가**

`EditToolbar` 프로퍼티(9~13줄) 영역에 추가:
```swift
    /// 현재 클립에 라벨이 있을 때 라벨 아이콘 우상단 coral dot.
    var labelActive: Bool = false
    var onLabel: () -> Void = {}
```

- [ ] **Step 2: paperToolbar 에 라벨 항목 추가**

`paperToolbar` 의 HStack(25~29줄)에서 회전 다음에 라벨 항목 삽입:
```swift
        HStack(spacing: 0) {
            item(icon: .rotate, label: "회전", action: onRotate, dotIndicator: rotationActive)
            item(icon: .textLabel, label: "라벨", action: onLabel, dotIndicator: labelActive)
            item(icon: .trash, label: "삭제", action: onDelete, tone: .destructive)
            item(icon: .check, label: "저장", action: onSave, disabled: !canSave)
        }
```

- [ ] **Step 3: liquidGlassToolbar 에 라벨 항목 추가**

`liquidGlassToolbar` 의 HStack(50~54줄)에서:
```swift
            HStack(spacing: 8) {
                glassItem(icon: .rotate, label: "회전", action: onRotate, dotIndicator: rotationActive)
                glassItem(icon: .textLabel, label: "라벨", action: onLabel, dotIndicator: labelActive)
                glassItem(icon: .trash, label: "삭제", action: onDelete, tone: .destructive)
                glassItem(icon: .check, label: "저장", action: onSave, disabled: !canSave)
            }
```

- [ ] **Step 4: 빌드 확인**

Run:
```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: 커밋**

```bash
git add Modules/TimelineFeature/Sources/Components/EditToolbar.swift
git commit -m "✨ feat: 편집 툴바에 라벨 항목 추가"
```

---

## Task 9: LabelEditorView (TimelineFeature)

**Files:**
- Create: `Modules/TimelineFeature/Sources/LabelEditorView.swift`

- [ ] **Step 1: 에디터 뷰 작성**

Create `Modules/TimelineFeature/Sources/LabelEditorView.swift`:
```swift
import SwiftUI
import Models
import DesignSystem

/// 전체화면 라벨 에디터. 클립 이미지 위에서 라벨을 자유 드래그로 배치하고
/// 폰트·스타일·크기를 고른다. "저장" 시 편집 결과 ClipLabel 을 onCommit 으로 돌려준다.
struct LabelEditorView: View {
    let clip: Clip
    let rotation: ClipRotation
    let onCommit: (ClipLabel) -> Void
    let onCancel: () -> Void

    @State private var label: ClipLabel
    @GestureState private var dragTranslation: CGSize = .zero

    init(
        clip: Clip,
        rotation: ClipRotation,
        initialLabel: ClipLabel,
        onCommit: @escaping (ClipLabel) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.clip = clip
        self.rotation = rotation
        self.onCommit = onCommit
        self.onCancel = onCancel
        _label = State(initialValue: initialLabel)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            canvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
            controls
        }
        .chalNaScreen()
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                ChalNaIcon(.close, size: 20).foregroundColor(ChalNaColor.ink)
            }
            .chalNaHitTarget()
            .accessibilityLabel("취소")

            Spacer()
            Text("라벨")
                .font(ChalNaTypography.krSemibold(15))
                .foregroundColor(ChalNaColor.ink)
            Spacer()

            Button("저장") { onCommit(label) }
                .font(ChalNaTypography.krBody(15, weight: .semibold))
                .foregroundColor(ChalNaColor.coral)
                .chalNaHitTarget()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Canvas (드래그 캔버스)

    /// 클립의 표시 비율(회전 반영) width/height.
    private var displayAspect: CGFloat {
        let base = clip.displaySize ?? CGSize(width: 9, height: 16)
        let oriented = rotation.swapsAxes ? CGSize(width: base.height, height: base.width) : base
        return max(oriented.width, 1) / max(oriented.height, 1)
    }

    /// 가용 영역 안에 displayAspect 로 fit 되는 박스 크기.
    private func fittedBox(in available: CGSize) -> CGSize {
        guard available.width > 0, available.height > 0 else { return .zero }
        let byWidth = CGSize(width: available.width, height: available.width / displayAspect)
        if byWidth.height <= available.height { return byWidth }
        return CGSize(width: available.height * displayAspect, height: available.height)
    }

    private var canvas: some View {
        GeometryReader { proxy in
            let box = fittedBox(in: proxy.size)
            ZStack {
                clip.thumbnailView(contentMode: .fill)
                    .frame(width: box.width, height: box.height)
                    .clipped()
                    .overlay(labelOverlay(boxSize: box))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func labelOverlay(boxSize: CGSize) -> some View {
        let fontPx = label.clampedSizeFraction * boxSize.height
        let centerX = label.position.x * boxSize.width + dragTranslation.width
        let centerY = label.position.y * boxSize.height + dragTranslation.height
        return labelText(fontPx: fontPx)
            .position(x: centerX, y: centerY)
            .gesture(
                DragGesture()
                    .updating($dragTranslation) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        guard boxSize.width > 0, boxSize.height > 0 else { return }
                        let nx = (label.position.x * boxSize.width + value.translation.width) / boxSize.width
                        let ny = (label.position.y * boxSize.height + value.translation.height) / boxSize.height
                        label.position = CGPoint(x: min(max(nx, 0), 1), y: min(max(ny, 0), 1))
                    }
            )
    }

    @ViewBuilder
    private func labelText(fontPx: CGFloat) -> some View {
        let isEmpty = label.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let display = isEmpty ? "라벨 입력" : label.text
        let base = Text(display)
            .font(label.font == .memoment
                  ? ChalNaTypography.memoment(fontPx)
                  : ChalNaTypography.krBody(fontPx, weight: .semibold))
            .lineLimit(1)
            .fixedSize()

        switch label.style {
        case .plain:
            base.foregroundColor(isEmpty ? Color.white.opacity(0.7) : Color.black)
        case .boxed:
            base.foregroundColor(.white)
                .padding(.horizontal, fontPx * 0.35)
                .padding(.vertical, fontPx * 0.22)
                .background(
                    RoundedRectangle(cornerRadius: min(fontPx * 0.4, 12), style: .continuous)
                        .fill(Color.black)
                )
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 16) {
            ChalNaTextField(placeholder: "라벨 문구를 입력하세요", text: $label.text)

            HStack(spacing: 12) {
                segmented(title: "폰트",
                          options: LabelFont.allCases.map { ($0.displayName, $0) },
                          selection: $label.font)
                segmented(title: "스타일",
                          options: LabelTextStyle.allCases.map { ($0.displayName, $0) },
                          selection: $label.style)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("크기")
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.small, weight: .medium))
                    .foregroundColor(ChalNaColor.ink)
                Slider(
                    value: $label.sizeFraction,
                    in: ClipLabel.minSizeFraction...ClipLabel.maxSizeFraction
                )
                .tint(ChalNaColor.coral)
            }
        }
        .padding(16)
    }

    private func segmented<T: Equatable>(
        title: String,
        options: [(String, T)],
        selection: Binding<T>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.small, weight: .medium))
                .foregroundColor(ChalNaColor.ink)
            HStack(spacing: 8) {
                ForEach(options.indices, id: \.self) { i in
                    let opt = options[i]
                    let isOn = selection.wrappedValue == opt.1
                    Button {
                        selection.wrappedValue = opt.1
                    } label: {
                        Text(opt.0)
                            .font(ChalNaTypography.krBody(13, weight: .medium))
                            .foregroundColor(isOn ? .white : ChalNaColor.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: ChalNaRadius.button, style: .continuous)
                                    .fill(isOn ? ChalNaColor.coral : ChalNaColor.ivory)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    LabelEditorView(
        clip: SampleData.jejuTimeline[0],
        rotation: .r0,
        initialLabel: ClipLabel(text: "제주 바다", font: .memoment, style: .boxed),
        onCommit: { _ in },
        onCancel: {}
    )
}
```

- [ ] **Step 2: 빌드 확인**

Run:
```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: BUILD SUCCEEDED.

> `SampleData`/`ClipLabel`/`ChalNaTextField`/`ChalNaIcon(.textLabel)`/`ChalNaTypography.memoment` 가 모두 앞 Task 에서 준비됐는지 확인. `chalNaHitTarget()`·`chalNaScreen()` 은 DesignSystem 모디파이어.

- [ ] **Step 3: 커밋**

```bash
git add Modules/TimelineFeature/Sources/LabelEditorView.swift
git commit -m "✨ feat: 전체화면 라벨 에디터(LabelEditorView) 추가"
```

---

## Task 10: TimelineView 에 라벨 에디터 배선 (TimelineFeature)

**Files:**
- Modify: `Modules/TimelineFeature/Sources/TimelineView.swift`

- [ ] **Step 1: 에디터 표시 상태 추가**

`TimelineView` 의 `@State` 영역(13~14줄 부근)에 추가:
```swift
    @State private var labelEditorClipID: Clip.ID?
```

- [ ] **Step 2: 라벨 활성 여부 + 진입 핸들러 추가**

`// MARK: - Rotation` 섹션(274줄 부근)의 `rotateCurrentClip()` **아래**에 추가:
```swift
    // MARK: - Label

    private var currentLabelActive: Bool {
        guard let id = store.currentClip?.id else { return false }
        return session.label(for: id).isVisible
    }

    private func openLabelEditor() {
        guard let id = store.currentClip?.id else { return }
        labelEditorClipID = id
    }
```

- [ ] **Step 3: 툴바에 라벨 콜백 연결**

`bottomBar` 의 비재생(else) 분기 `EditToolbar(...)`(260~269줄)에 `labelActive`/`onLabel` 추가:
```swift
            EditToolbar(
                rotationActive: currentRotationActive,
                labelActive: currentLabelActive,
                canSave: canSave,
                onRotate: { rotateCurrentClip() },
                onLabel: { openLabelEditor() },
                onDelete: { store.send(.deleteCurrentRequested) },
                onSave: {
                    store.send(.saveTapped)
                    router.push(.export)
                }
            )
            .padding(.bottom, 16)
```

- [ ] **Step 4: fullScreenCover 연결**

`body` 의 `.confirmationDialog(...)` 모디파이어(78~87줄) **아래**에 추가:
```swift
        .fullScreenCover(item: $labelEditorClipID) { clipID in
            if let clip = store.clips.first(where: { $0.id == clipID }) {
                LabelEditorView(
                    clip: clip,
                    rotation: session.rotation(for: clipID),
                    initialLabel: session.label(for: clipID),
                    onCommit: { newLabel in
                        session.setLabel(newLabel, for: clipID)
                        labelEditorClipID = nil
                    },
                    onCancel: { labelEditorClipID = nil }
                )
            }
        }
```

> `Clip.ID`(=`UUID`)는 `Identifiable`/`Hashable` 이므로 `.fullScreenCover(item:)` 에 직접 쓸 수 있다(UUID 는 Identifiable 아님 → 아래 Step 5 의 작은 래퍼 필요). **Step 5 확인 필수.**

- [ ] **Step 5: item 바인딩용 Identifiable 보장**

`UUID` 는 기본적으로 `Identifiable` 이 아니다. 파일 하단(마지막 `}` 뒤, `PulseDot` 정의 아래)에 추가:
```swift
extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
```

> 이미 다른 곳에서 같은 확장을 했다면 중복 정의 에러가 난다 — 그 경우 이 Step 을 생략한다. 빌드 에러(`redundant conformance`) 시 기존 정의를 재사용.

- [ ] **Step 6: 빌드 확인**

Run:
```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 7: 커밋**

```bash
git add Modules/TimelineFeature/Sources/TimelineView.swift
git commit -m "✨ feat: 타임라인에서 라벨 에디터 진입 배선"
```

---

## Task 11: 통합 검증 (devMock 실행 + 실제 export)

**Files:** 없음(검증).

- [ ] **Step 1: 전체 테스트 통과**

Run:
```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test \
  -only-testing:AppCoreTests -only-testing:CompositionServiceTests
```
Expected: 모든 테스트 PASS (ClipLabelTests/EditSessionLabelTests/CustomLabelLayoutTests + 기존).

- [ ] **Step 2: devMock 시각 검증 (`ios-build-run` 서브에이전트 위임 권장)**

`ChalNa Dev` 스킴으로 빌드/실행 후 수동 체크:
- [ ] 미디어 선택 → 타임라인 진입.
- [ ] 클립 선택 → 툴바 **라벨** 탭 → 전체화면 에디터 진입.
- [ ] 텍스트 입력 → 캔버스 라벨에 즉시 반영.
- [ ] 폰트 토글(꾸꾸/기본) 전환 시 글꼴 바뀜.
- [ ] 스타일 토글(검정 글자/흰 글자+검정 배경) 전환.
- [ ] 크기 슬라이더로 글자 크기 변화.
- [ ] 라벨을 드래그해 위치 이동(기본 정중앙에서).
- [ ] **저장** → 타임라인 복귀, 툴바 라벨 아이콘에 coral dot(활성) 표시.
- [ ] 다른 클립도 독립적으로 라벨 지정 가능.

- [ ] **Step 3: 실제 export burn-in 검증**

- [ ] 저장 → Export 진행 → 완성된 mp4 재생.
- [ ] 각 클립 구간에 라벨이 **에디터에서 본 위치/크기/스타일대로** 표시됨.
- [ ] 자동 시간/날짜 라벨과 공존(설정이 켜져 있으면).
- [ ] Xcode 콘솔 `[CompositionService] Memoment families:` 로그 확인 — family 가 잡히면 꾸꾸 폰트 적용, 빈 배열이면 시스템 폰트 fallback(크래시 없음).

- [ ] **Step 4: (선택) 회귀 — 라벨 없이 export**

- [ ] 라벨을 하나도 지정하지 않고 export → 기존 동작과 동일(자동 시간/날짜 라벨만).

---

## Self-Review 결과 (작성자 점검)

**Spec 커버리지:** 모델(Task1)·세션(Task2)·DS 아이콘/폰트(Task3)·폰트 등록(Task4)·좌표 헬퍼(Task5)·합성 burn-in(Task6)·export 배선(Task7)·툴바(Task8)·에디터(Task9)·타임라인 배선(Task10)·검증(Task11) — 스펙 11~14절 항목 모두 매핑됨.

**플레이스홀더:** 없음. 모든 step 에 실제 코드/명령 포함.

**타입 일관성 점검:**
- `ClipLabel`(text/font/style/sizeFraction/position, clampedSizeFraction, isVisible, .default, min/maxSizeFraction) — Task1 정의 ↔ Task5/6/9 사용 일치.
- `LabelFont`/`LabelTextStyle`(.memoment/.system, .plain/.boxed, displayName) 일치.
- `EditSession.label(for:)`/`setLabel(_:for:)`/`labels` — Task2 정의 ↔ Task7/10 사용 일치.
- `CompositionServicing.export(clips:rotations:labelSettings:clipLabels:)` — Task6 정의 ↔ CompositionClient(Task7) liveValue 호출 일치.
- `placedRect(naturalSize:preferredTransform:rotation:renderSize:)`/`customLabelOrigin(placedRect:position:textSize:renderSize:)` — Task5 정의 ↔ Task5 테스트·Task6 사용 일치.
- `ChalNaIconKind.textLabel`(Task3) ↔ EditToolbar(Task8) 사용 일치.
- `ChalNaTypography.memoment(_:)`(Task3) ↔ LabelEditorView(Task9) 사용 일치.
- `Action.startExport(clips:rotations:clipLabels:)`/`retryTapped(...clipLabels:)`(Task7 Feature) ↔ ExportView 호출(Task7 View) 일치.

**주의(실행 중 확인):** Task10 Step5 의 `UUID: Identifiable` 확장은 코드베이스에 이미 있으면 생략(중복 conformance 빌드 에러로 감지).
