# ChalNa 다크 시네마틱 리디자인 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ChalNa의 시각 언어를 커머스 DDS 이식 상태에서 다크 시네마틱으로 재정의하고, 감사된 UI 깨짐 24건을 모두 해소한다.

**Architecture:** DesignSystem 모듈에 다크 전용 **시맨틱 토큰**(역할 이름)을 신설하고 수치 스케일을 제거한다. 그 위에 컴포넌트 18종 + 모디파이어 2종을 올리고, 화면 14개를 이 컴포넌트만 쓰도록 재작성한다. TCA 리듀서·State·네비게이션과 영상 합성 파이프라인은 건드리지 않는다 — 순수 뷰·토큰 레이어 변경이다.

**Tech Stack:** Swift 6.0 / iOS 18+ / SwiftUI / The Composable Architecture 1.18+ / Swift Testing / Tuist

**설계 근거:** `docs/superpowers/specs/2026-07-28-app-redesign-design.md` — 이 계획의 모든 값·결정은 그 문서에서 왔다. 값이 충돌하면 스펙이 우선이다.

---

## Global Constraints

이 절의 요구사항은 **모든 태스크에 암묵적으로 포함된다.**

- **Swift 6.0+, iOS 18.0** deployment target (`Module.deploymentTargets = .iOS("18.0")`). 낮추지 않는다.
- **SwiftUI 전용.** UIKit은 이미 래핑된 곳(`PHPickerViewController`, `AVPlayerViewController`, `FilmStripCollectionView`, `PlayerLayerView`, 엣지 스와이프)만 유지. 새 UIKit 래핑을 만들지 않는다.
- **GCD 금지** (`DispatchQueue`/`DispatchGroup`). `async/await`·`Task`·`actor`·`AsyncStream`만.
- **`ObservableObject`/`@Published` 금지.** `@Observable` + TCA `@ObservableState`만.
- **테스트는 Swift Testing** (`import Testing`, `@Test`, `#expect`). XCTest는 UI 테스트(`ChalNa/UITests`)만 예외.
- **식별자는 영어, 주석·커밋 메시지는 한국어 허용.** 한 파일 = 한 타입 (긴밀히 결합된 small helper 는 예외).
- **Spacing/padding 은 토큰 없이 리터럴 숫자.** 리듬은 `4 / 8 / 12 / 16 / 20 / 24`. **화면 좌우 여백은 20 하나로 통일** (기존 헤더 16 / 본문 24 혼용을 없앤다).
- **색·타이포·라디우스·섀도우·모션은 토큰만 사용.** 아래 파일 안에서만 원시값을 쓴다:
  - `Modules/DesignSystem/Sources/Tokens/*.swift` — `Color(hex:)` 허용
  - `Modules/DesignSystem/Sources/Icons/ChalNaIcon.swift` — `.font(.system(size:))` 허용 (글리프 크기 지정)
  - `Modules/Models/Sources/ColorHex.swift`, `ThumbnailPreset.swift` — 콘텐츠 그라디언트 (비범위)
  - `Modules/TimelineFeature/Sources/Components/ClipLabelText.swift` 및 `Models/ClipLabel.swift` — **영상 출력과 픽셀 일치해야 하는 라벨 박스.** 다크 토큰 적용 예외 (스펙 §6.7)
- **`Module.bundleIdPrefix = "ios.inho.ChalNa"`**, 브랜드 prefix `ChalNa` 유지. 새 타입도 `ChalNa` 접두.
- **Feature 모듈끼리 직접 import 금지.** 화면 전환은 `delegate` 액션으로만.
- **`Project.swift` 수정 후에는 반드시 `tuist generate`.**
- **모든 사용자 노출 문자열은 로컬라이즈 대상.** `Text("한국어")`(LocalizedStringKey) 또는 `String(localized:)`. `Text(verbatim:)`은 브랜드명·숫자·타임코드에만.
- **접근성:** 터치 영역 최소 44pt(컴포넌트가 강제), 기존 `accessibilityLabel`/`Hint`/`Action` 전부 보존, 폰트 최소 12pt.
- **빌드 명령:**
  ```bash
  xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
             -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
  ```
- **시뮬레이터가 "Invalid device state" 로 잇달아 실패하면** 다음으로 복구한다:
  ```bash
  xcrun simctl shutdown all; killall Simulator 2>/dev/null; sleep 3
  open -a Simulator                     # ← 반드시 UI 를 띄운다
  sleep 8
  xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
  ```
  **`open -a Simulator` 가 빠지면 안 된다.** 헤드리스 `simctl boot` 만으로는 부팅 직후
  idle-shutdown 이 반복돼 복구가 안 된다(Task 11 에서 확인). Simulator.app UI 가 떠 있어야
  디바이스가 살아 있는다.
  Task 8·9 에서 두 번 발생했다. 원인은 `ChalNaIconTests` 가 콜드 런에서 간헐적으로 크래시하며
  `simctl diagnose` 를 트리거해 CoreSimulator 를 흔드는 것으로 보인다. 재실행하면 통과한다
  (16/16, 1초 내). **테스트 코드를 고치려 하지 말고 위 레시피로 복구한 뒤 재실행한다.**
- **각 태스크의 `git add` 예시 목록은 불완전할 수 있다.** 계획을 쓴 뒤 스텝이 덧붙여지면서
  목록이 갱신되지 않은 경우가 있다(Task 9·10 에서 실제 발생). **커밋 전에 `git status --short`
  로 자기가 바꾼 파일 전부를 확인하고, 그 태스크에 속한 것은 모두 한 커밋에 넣는다.**
  부분 `git add` 는 태스크를 반쪽만 커밋해 워킹트리에 잔여물을 남긴다.
  자기 태스크와 무관한 변경이 있으면 커밋하지 말고 보고한다.
- **`-derivedDataPath` 는 항상 `/tmp/chalna-build` 하나만 쓴다.** 태스크마다 다른 경로를 쓰면
  DerivedData 가 태스크당 ~2.2GB 씩 쌓여 `/tmp` 가 차고 빌드가 `lipo` 에러로 실패한다
  (Task 7 에서 실제 발생 — 잔여물 3.8GB). 새 경로를 만들지 말고 기존 것을 재사용한다.
- **테스트 명령 (전체):**
  ```bash
  xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa-Workspace \
             -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
  ```
- **작업 브랜치:** `feature/dark-redesign` (이미 생성됨, 스펙 커밋 `ae53e72` 포함).
- **커밋마다 빌드가 통과해야 한다.** P0~P4 동안 구 토큰은 `@available(*, deprecated)` 심으로 남겨 컴파일을 유지하고 P5에서 제거한다. deprecated 경고가 다수 발생하는 것은 **의도된 마이그레이션 체크리스트**다.

---

## File Structure

### 신규 생성

| 파일 | 책임 |
|---|---|
| `Modules/DesignSystem/Sources/Tokens/ChalNaMotion.swift` | 애니메이션 커브 3종 |
| `Modules/DesignSystem/Sources/Components/ChalNaNavBar.swift` | 헤더 컨테이너 (좌·타이틀·우 3슬롯) |
| `Modules/DesignSystem/Sources/Components/ChalNaNavAction.swift` | 헤더 좌·우 액션 단일 컴포넌트 |
| `Modules/DesignSystem/Sources/Components/ChalNaBottomBar.swift` | 하단 고정 액션 영역 (여백·배경·hairline) |
| `Modules/DesignSystem/Sources/Components/ChalNaCard.swift` | surface + border 컨테이너 |
| `Modules/DesignSystem/Sources/Components/ChalNaListRow.swift` | 리스트 행 5종 (navigate/toggle/slider/check/plain) |
| `Modules/DesignSystem/Sources/Components/ChalNaTag.swift` | 태그 4종 (live/video/neutral/accent) |
| `Modules/DesignSystem/Sources/Components/MediaThumb.swift` | 클립 썸네일 카드 6상태 |
| `Modules/DesignSystem/Sources/Components/ChalNaCanvas.swift` | 9:16 미디어 캔버스 컨테이너 |
| `Modules/DesignSystem/Sources/Components/ChalNaProgressBar.swift` | 진행률 바 |
| `Modules/DesignSystem/Sources/Components/ChalNaEmptyState.swift` | 빈 상태 |
| `Modules/DesignSystem/Sources/Components/ChalNaNotice.swift` | 정보 안내 카드 |
| `Modules/DesignSystem/Sources/Components/ChalNaToast.swift` | 토스트 |
| `Modules/DesignSystem/Sources/Components/ChalNaBlockingOverlay.swift` | 작업 차단 오버레이 |
| `Modules/DesignSystem/Sources/Components/ChalNaTextArea.swift` | 멀티라인 입력 |
| `Modules/DesignSystem/Sources/Components/ChalNaSlider.swift` | 다크 슬라이더 |
| `Modules/DesignSystem/Sources/Modifiers/View+ChalNaScrollHairline.swift` | 스크롤 시 헤더 hairline |
| `Modules/DesignSystem/Tests/ChalNaColorContrastTests.swift` | 대비 규칙 테스트 |
| `Modules/DesignSystem/Tests/ChalNaTypographyTests.swift` | 역할↔텍스트스타일 매핑 잠금 |
| `Modules/DesignSystem/Tests/ChalNaIconTests.swift` | SF Symbol 존재 검증 |
| `scripts/design-lint.sh` | 정적 검사 5종 |
| `ChalNa/UITests/TimelineLayoutUITests.swift` | SE 세로 예산 실측 검증 |

### 수정

| 파일 | 변경 |
|---|---|
| `Modules/DesignSystem/Sources/Tokens/ChalNaColor.swift` | 시맨틱 토큰 추가, 스케일 deprecated → P5 삭제 |
| `Modules/DesignSystem/Sources/Tokens/ChalNaTypography.swift` | 역할 6종 + mono + keris, 구 API deprecated → P5 삭제 |
| `Modules/DesignSystem/Sources/Tokens/ChalNaRadius.swift` | `xs/sm/md/lg/pill` 로 교체 |
| `Modules/DesignSystem/Sources/Tokens/ChalNaShadow.swift` | `.floating` 단일화 |
| `Modules/DesignSystem/Sources/Icons/ChalNaIcon.swift` | SF Symbols 전환, 커스텀 패스 제거, `.settings/.livePhoto/.video` 추가 |
| `Modules/DesignSystem/Sources/Components/ChalNaButton.swift` | variant 3종 + `destructive` |
| `Modules/DesignSystem/Sources/Components/ChalNaTextField.swift` | 다크 재스타일 |
| `Modules/DesignSystem/Sources/Modifiers/View+ChalNaScreen.swift` | `bg` 토큰 |
| `Modules/DesignSystem/Sources/Showcase/DesignSystemShowcaseView.swift` | 신규 인벤토리로 재작성 |
| 화면 14개 (`HomeView`, `MediaPickerView`, `MediaPreviewSheet`, `TimelineView`, `ClipAdjustView`, `LabelEditorView`, `ExportView`, `FilmDetailView`, `SettingsView`, `LabelSettingsView`, `LabelPositionSettingsView`, `LanguageView`, `SupportView`, `SplashView`) | 토큰·컴포넌트 전환 + 레이아웃/위계 재설계 |
| Timeline 컴포넌트 6종 (`PreviewPanel`, `TransportControls`, `EditToolbar`, `FilmStripCollectionView`, `DaySprocket`, `AutoLabelsOverlay`) | 다크 전환 + 예산 축소 |
| `Project.swift` | `DesignSystemTests` 타겟 추가, `UIUserInterfaceStyle: Dark` |
| `ChalNa/Sources/App/RootView.swift` | 전역 `dynamicTypeSize` 상한 |
| `CLAUDE.md`, `AGENTS.md` | 디자인 시스템 절 전면 갱신 |

### 삭제

| 파일 | 근거 |
|---|---|
| `Modules/DesignSystem/Sources/Components/ChalNaBottomSheet.swift` | 실사용 0곳 |
| `Modules/DesignSystem/Sources/Components/LiveBadge.swift` | 실사용 1곳, `ChalNaTag(.live)`과 중복 |
| `Modules/DesignSystem/Sources/Components/ChalNaNavigationBar.swift` | `ChalNaNavBar` + `ChalNaNavAction`으로 대체 |
| `Modules/DesignSystem/Sources/Components/ChalNaHeaderActionButtonStyle.swift` | `ChalNaNavAction`에 흡수 |
| `Modules/DesignSystem/Sources/Components/ChalNaChip.swift` | `ChalNaTag`로 대체 |
| `Modules/DesignSystem/Sources/Components/ClipThumbCard.swift` | `MediaThumb`로 대체 |
| `Modules/DesignSystem/Sources/Modifiers/View+ChalNaTopBar.swift` | `View+ChalNaScrollHairline.swift`로 대체 |
| `Modules/DesignSystem/Resources/ChalNaColors.xcassets` (7 colorset) | 전부 dead |

---

# Phase P0 — 토큰 (Task 1–4)

## Task 1: ChalNaColor 시맨틱 토큰 + DesignSystemTests 타겟

**Files:**
- Modify: `Modules/DesignSystem/Sources/Tokens/ChalNaColor.swift`
- Modify: `Project.swift:225` (targets 배열 끝, `Module.unitTests(for: "SettingsFeature"...)` 뒤)
- Create: `Modules/DesignSystem/Tests/ChalNaColorContrastTests.swift`

**Interfaces:**
- Produces: `ChalNaColor.bg`, `.surface`, `.surfaceRaised`, `.canvas`, `.border`, `.borderStrong`, `.textPrimary`, `.textSecondary`, `.textTertiary`, `.accent`, `.accentFill`, `.accentPressed`, `.onAccent`, `.danger`, `.success`, `.brandDeep`, `.scrim` — 전부 `public static let ... : Color`.
- Produces: 구 `ChalNaColor.Purple`/`.Blue`/`.Gray`/`.Chip` 은 **그대로 남지만 `@available(*, deprecated)`** — Task 2~25 동안 컴파일 유지용, Task 26에서 삭제.
- Consumes: 없음 (첫 태스크).

- [ ] **Step 1: `DesignSystemTests` 타겟을 Project.swift 에 추가**

`Project.swift` 의 `targets:` 배열에서 `Module.unitTests(for: "SettingsFeature", ...)` 블록 **바로 뒤**(닫는 `),` 다음, `],` 앞)에 삽입한다:

```swift
        Module.unitTests(for: "DesignSystem"),
```

`DesignSystem` 은 다른 모듈에 의존하지 않으므로 추가 `dependencies` 가 필요 없다.

- [ ] **Step 2: 실패하는 대비 테스트를 작성**

`Modules/DesignSystem/Tests/ChalNaColorContrastTests.swift`:

```swift
import Testing
import SwiftUI
import UIKit
import DesignSystem

/// 다크 토큰의 WCAG 대비 규칙을 잠근다.
/// 값 근거: docs/superpowers/specs/2026-07-28-app-redesign-design.md §4.1
struct ChalNaColorContrastTests {

    // MARK: - WCAG 2.1 상대 휘도 / 대비비

    private func luminance(_ color: Color) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    private func contrast(_ a: Color, _ b: Color) -> Double {
        let l1 = luminance(a), l2 = luminance(b)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    // MARK: - 본문 텍스트: 4.5:1 이상

    @Test func testTextPrimaryPassesEnhancedContrast() {
        let ratio = contrast(ChalNaColor.textPrimary, ChalNaColor.bg)
        #expect(ratio >= 7.0, "textPrimary/bg 는 AAA(7:1) 이상이어야 한다 — 실제 \(ratio)")
    }

    @Test func testTextSecondaryPassesBodyContrast() {
        let ratio = contrast(ChalNaColor.textSecondary, ChalNaColor.bg)
        #expect(ratio >= 4.5, "textSecondary/bg 는 본문 기준(4.5:1) 이상 — 실제 \(ratio)")
    }

    @Test func testAccentPassesBodyContrastOnBackground() {
        let ratio = contrast(ChalNaColor.accent, ChalNaColor.bg)
        #expect(ratio >= 4.5, "accent 는 텍스트·아이콘에 쓰이므로 4.5:1 이상 — 실제 \(ratio)")
    }

    @Test func testOnAccentPassesOnAccentFill() {
        let ratio = contrast(ChalNaColor.onAccent, ChalNaColor.accentFill)
        #expect(ratio >= 4.5, "면형 버튼 라벨은 4.5:1 이상 — 실제 \(ratio)")
    }

    // MARK: - 설계상 대비가 낮은 토큰: 오용 방지를 규칙으로 고정

    @Test func testTextTertiaryIsDisabledOnly() {
        let ratio = contrast(ChalNaColor.textTertiary, ChalNaColor.bg)
        #expect(ratio >= 3.0, "비활성 텍스트도 형태 식별은 되어야 한다 — 실제 \(ratio)")
        #expect(ratio < 4.5, "본문 기준을 넘으면 disabled 전용이라는 의미가 흐려진다 — 실제 \(ratio)")
    }

    @Test func testBrandDeepIsNotUsableForInteraction() {
        let ratio = contrast(ChalNaColor.brandDeep, ChalNaColor.bg)
        #expect(ratio < 3.0,
                "brandDeep 은 Splash·브랜드 면 전용. 이 값이 3:1 을 넘으면 인터랙션 금지 근거가 무너진다 — 실제 \(ratio)")
    }

    // MARK: - 서피스 위계

    @Test func testSurfaceLuminanceOrder() {
        let bg = luminance(ChalNaColor.bg)
        let surface = luminance(ChalNaColor.surface)
        let raised = luminance(ChalNaColor.surfaceRaised)
        #expect(bg < surface, "surface 는 bg 보다 밝아야 한다")
        #expect(surface < raised, "surfaceRaised 는 surface 보다 밝아야 한다")
    }

    @Test func testCanvasIsIndistinguishableFromBackground() {
        let ratio = contrast(ChalNaColor.canvas, ChalNaColor.bg)
        #expect(ratio < 1.2,
                "영상 캔버스와 화면 배경이 눈에 띄게 다르면 '검은 섬' 문제가 남는다 — 실제 \(ratio)")
    }
}
```

- [ ] **Step 3: 프로젝트 재생성 후 테스트가 실패하는 것을 확인**

```bash
tuist generate
xcodebuild -workspace ChalNa.xcworkspace -scheme DesignSystem \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -30
```

> **스킴명 주의.** Tuist 는 테스트 타겟을 별도 스킴으로 만들지 않고 베이스 모듈 스킴
> (`DesignSystem`)의 test action 에 붙인다. `-scheme DesignSystemTests` 는 존재하지 않는다.
> 다른 모듈(`AppCore` 등)도 같은 패턴이다.

Expected: 컴파일 실패 — `ChalNaColor` 에 `bg`, `surface` 등의 멤버가 없음
(`value of type 'ChalNaColor' has no member 'bg'`).

- [ ] **Step 4: 시맨틱 토큰을 추가하고 구 스케일에 deprecated 표시**

`Modules/DesignSystem/Sources/Tokens/ChalNaColor.swift` 전체를 교체한다:

```swift
import SwiftUI

/// 다크 전용 시맨틱 색 토큰.
///
/// 화면은 **역할 이름만** 쓴다. 수치 스케일(`Purple`/`Blue`/`Gray`)은 마이그레이션
/// 기간 동안만 deprecated 로 남아 있고 P5 에서 삭제된다.
///
/// 값·대비 근거: `docs/superpowers/specs/2026-07-28-app-redesign-design.md` §4.1
public enum ChalNaColor {

    // MARK: - Surfaces

    /// 화면 배경. 무채색이 아니라 아주 옅은 인디고 캐스트.
    public static let bg            = Color(hex: 0x0B0A10)
    /// 카드 · 리스트 행.
    public static let surface       = Color(hex: 0x16151D)
    /// 바텀시트 · 플로팅 툴바.
    public static let surfaceRaised = Color(hex: 0x201F29)
    /// 영상 · 크롭 캔버스. 출력과 동일한 진짜 검정을 유지한다.
    /// `bg` 와 거의 같은 밝기라 화면 위에 '검은 섬'으로 뜨지 않는다.
    public static let canvas        = Color.black

    // MARK: - Lines

    /// 1px hairline.
    public static let border       = Color(hex: 0x2C2A38)
    /// 입력 필드 · 강조 경계.
    public static let borderStrong = Color(hex: 0x3D3A4D)

    // MARK: - Text

    /// 순백이 아니다 — 다크에서 순백은 헐레이션을 만든다.
    public static let textPrimary   = Color(hex: 0xF5F4F7)
    public static let textSecondary = Color(hex: 0xA3A0AE)
    /// **disabled 전용.** `bg` 대비 3.7:1 로 본문 기준(4.5)에 미달한다.
    /// 활성 텍스트에 쓰지 않는다.
    public static let textTertiary  = Color(hex: 0x6B6878)

    // MARK: - Accent

    /// 텍스트 · 아이콘 · 스트로크용 액센트.
    public static let accent        = Color(hex: 0x8B7BFF)
    /// 면형 버튼 배경.
    public static let accentFill    = Color(hex: 0x5B45E8)
    public static let accentPressed = Color(hex: 0xA091FF)
    /// `accentFill` 위의 라벨 색.
    public static let onAccent      = Color.white

    // MARK: - Status

    /// 파괴적 액션 · LIVE dot. 다크용으로 밝힌 레드.
    public static let danger  = Color(hex: 0xFF6B66)
    /// `danger` 의 눌림 톤. `accentPressed` 가 `accent` 에 대해 하는 역할과 동일.
    /// 이게 없으면 파괴적 ghost 버튼이 눌린 동안 보라(`accentPressed`)로 바뀐다.
    public static let dangerPressed = Color(hex: 0xFF8F8B)
    public static let success = Color(hex: 0x3DD9A0)

    // MARK: - Brand

    /// 앱 아이콘 색 그 자체. `bg` 대비 2.4:1 이므로
    /// **인터랙션(버튼·텍스트)에 쓰지 않는다.** Splash · 브랜드 면 전용.
    public static let brandDeep = Color(hex: 0x462DE2)

    // MARK: - Overlay

    public static let scrim = Color.black.opacity(0.6)

    // MARK: - Deprecated: 커머스 DDS 수치 스케일 (P5 에서 삭제)

    @available(*, deprecated, message: "시맨틱 토큰을 사용하세요 (accent/accentFill/textPrimary 등). P5 에서 삭제됩니다.")
    public enum Purple {
        public static let p100 = Color(hex: 0xE0D1FF)
        public static let p200 = Color(hex: 0xBFA0FF)
        public static let p300 = Color(hex: 0xAA82FF)
        public static let p400 = Color(hex: 0x9868FC)
        public static let p500 = Color(hex: 0x9849FD)
        public static let p600 = Color(hex: 0x8B38E5)
        public static let p700 = Color(hex: 0x693DE8)
        public static let p800 = Color(hex: 0x553DE8)
        public static let p900 = Color(hex: 0x462DE2)
    }

    @available(*, deprecated, message: "시맨틱 토큰을 사용하세요. P5 에서 삭제됩니다.")
    public enum Blue {
        public static let b50  = Color(hex: 0xF7FAFF)
        public static let b100 = Color(hex: 0xEBF3FF)
        public static let b200 = Color(hex: 0xDDEBFF)
        public static let b300 = Color(hex: 0x7EB2FF)
        public static let b400 = Color(hex: 0x448FFF)
        public static let b500 = Color(hex: 0x2070EB)
        public static let b600 = Color(hex: 0x0E68F0)
        public static let b700 = Color(hex: 0x005BE4)
        public static let b800 = Color(hex: 0x094FE5)
        public static let b900 = Color(hex: 0x0B3EAB)
    }

    @available(*, deprecated, message: "시맨틱 토큰을 사용하세요 (bg/surface/textPrimary 등). P5 에서 삭제됩니다.")
    public enum Gray {
        public static let g50  = Color(hex: 0xF8F8F8)
        public static let g100 = Color(hex: 0xEFEFEF)
        public static let g200 = Color(hex: 0xD9D9D9)
        public static let g300 = Color(hex: 0xBDBDBD)
        public static let g400 = Color(hex: 0xA0A0A0)
        public static let g500 = Color(hex: 0x919191)
        public static let g600 = Color(hex: 0x6E6E6E)
        public static let g700 = Color(hex: 0x4F4F4F)
        public static let g800 = Color(hex: 0x2C2C2C)
        public static let g900 = Color(hex: 0x1A1A1A)
    }

    @available(*, deprecated, message: "ChalNaTag 를 사용하세요. P5 에서 삭제됩니다.")
    public enum Chip {
        public static let liveBackground  = Color(hex: 0xFADAD9)
        public static let liveForeground  = Color(hex: 0xE53B38)
        public static let videoBackground = Color(hex: 0xE0D1FF)
        public static let videoForeground = Color(hex: 0x8B38E5)
        public static let filmBackground  = Color(hex: 0xDDEBFF)
        public static let filmForeground  = Color(hex: 0x2070EB)
    }

    @available(*, deprecated, renamed: "danger", message: "P5 에서 삭제됩니다.")
    public static let info = Color(hex: 0x02B8D3)
}

extension Color {
    /// 토큰 정의 전용 hex 이니셜라이저. 화면에서 직접 호출하지 않는다.
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
```

> 주의: `ChalNaColor.success` 는 스펙에서 `#3DD9A0` 이고 구 `success #06B87F` 를 대체한다.
> 구 `success`/`danger` 는 같은 이름이라 값만 바뀐다 — deprecated 로 남기지 않는다.

- [ ] **Step 5: 테스트가 통과하는 것을 확인**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme DesignSystem \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -30
```

Expected: 8개 테스트 전부 PASS.

- [ ] **Step 6: 앱 전체가 여전히 빌드되는지 확인**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`. deprecated 경고 다수 발생 — **의도된 마이그레이션 체크리스트**이므로 무시한다.

- [ ] **Step 7: 커밋**

```bash
git add Project.swift Modules/DesignSystem/Sources/Tokens/ChalNaColor.swift \
        Modules/DesignSystem/Tests/ChalNaColorContrastTests.swift
git commit -m "$(cat <<'EOF'
✨ feat(DesignSystem): 다크 전용 시맨틱 색 토큰 + 대비 테스트

- ChalNaColor 에 역할 기반 토큰 17종 추가 (bg/surface/accent/text* 등)
- 구 수치 스케일(Purple/Blue/Gray/Chip)은 deprecated 로 남겨 컴파일 유지, P5 삭제
- DesignSystemTests 타겟 신설
- 대비 규칙 8건을 테스트로 고정: 본문 4.5:1 하한, textTertiary 는 disabled 전용,
  brandDeep 은 인터랙션 금지, canvas 와 bg 는 구별되지 않아야 함

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: ChalNaTypography 역할 토큰

**Files:**
- Modify: `Modules/DesignSystem/Sources/Tokens/ChalNaTypography.swift`
- Create: `Modules/DesignSystem/Tests/ChalNaTypographyTests.swift`

**Interfaces:**
- Consumes: 없음.
- Produces: `ChalNaTypography.display`, `.title`, `.headline`, `.body`, `.label`, `.caption` — 전부 `public static var ... : Font` (인자 없음).
- Produces: `ChalNaTypography.mono(_ style: Font.TextStyle = .footnote, weight: Font.Weight = .regular) -> Font`
- Produces: `ChalNaTypography.keris(_ size: CGFloat) -> Font`, `ChalNaTypography.kerisUIFont(_ size: CGFloat) -> UIFont` (기존 유지 — 영상 라벨 WYSIWYG 용).
- Produces: `ChalNaTypography.Tracking.title/.body` — `CGFloat`.
- Produces: 구 API(`displayKR`/`krBody`/`krSemibold`/`title(_:weight:)`/`Size`/`displayEN`/`serifFallback`/`hand`/`handFallback`/`monoFallback`, `Text.tagLabel()`)는 deprecated 로 유지 → Task 26 삭제.

- [ ] **Step 1: 실패하는 매핑 잠금 테스트를 작성**

역할 6종이 **표준 iOS 텍스트 스타일에 정확히 대응**한다는 것이 이 스케일의 근거다
(display 28=`.title`, title 22=`.title2`, headline 17=`.headline`, body 16=`.callout`,
label 13=`.footnote`, caption 12=`.caption`). 이 매핑이 실수로 바뀌는 것을 막는다.

`Modules/DesignSystem/Tests/ChalNaTypographyTests.swift`:

```swift
import Testing
import SwiftUI
import UIKit
import DesignSystem

/// 역할 토큰 ↔ 표준 텍스트 스타일 매핑을 잠근다.
/// 근거: docs/superpowers/specs/2026-07-28-app-redesign-design.md §4.3
struct ChalNaTypographyTests {

    @Test func testRolesMapToStandardTextStyles() {
        #expect(ChalNaTypography.display  == Font.system(.title,    design: .default, weight: .bold))
        #expect(ChalNaTypography.title    == Font.system(.title2,   design: .default, weight: .semibold))
        #expect(ChalNaTypography.headline == Font.system(.headline, design: .default, weight: .semibold))
        #expect(ChalNaTypography.body     == Font.system(.callout,  design: .default, weight: .regular))
        #expect(ChalNaTypography.label    == Font.system(.footnote, design: .default, weight: .medium))
        #expect(ChalNaTypography.caption  == Font.system(.caption,  design: .default, weight: .regular))
    }

    @Test func testMonoUsesMonospacedDesign() {
        #expect(ChalNaTypography.mono() == Font.system(.footnote, design: .monospaced, weight: .regular))
        #expect(ChalNaTypography.mono(.body, weight: .semibold)
                == Font.system(.body, design: .monospaced, weight: .semibold))
    }

    /// 역할이 대응하는 텍스트 스타일의 기본 크기가 스펙의 pt 값과 일치해야 한다.
    /// (다르면 스케일 근거가 무너진 것 — 스펙 §4.3 을 다시 봐야 한다)
    @Test func testDefaultPointSizesMatchSpec() {
        let traits = UITraitCollection(preferredContentSizeCategory: .large)
        func size(_ style: UIFont.TextStyle) -> CGFloat {
            UIFont.preferredFont(forTextStyle: style, compatibleWith: traits).pointSize
        }
        #expect(size(.title1)      == 28, "display")
        #expect(size(.title2)      == 22, "title")
        #expect(size(.headline)    == 17, "headline")
        #expect(size(.callout)     == 16, "body")
        #expect(size(.footnote)    == 13, "label")
        #expect(size(.caption1)    == 12, "caption")
    }

    /// 최소 12pt 규칙: 가장 작은 역할(caption)이 기본 설정에서 12pt 이상이어야 한다.
    @Test func testSmallestRoleIsAtLeast12Points() {
        let traits = UITraitCollection(preferredContentSizeCategory: .large)
        let caption = UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: traits)
        #expect(caption.pointSize >= 12, "8pt·11pt 폰트 금지 규칙의 하한")
    }

    @Test func testKerisFontResolvesToConcreteFont() {
        let font = ChalNaTypography.kerisUIFont(48)
        #expect(font.pointSize == 48)
    }
}
```

- [ ] **Step 2: 테스트가 실패하는 것을 확인**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme DesignSystem \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -30
```

Expected: 컴파일 실패 — `ChalNaTypography` 에 `display`/`title`(인자 없는 var)/`headline`/`body`/`label`/`caption`/`mono()` 멤버가 없음.

- [ ] **Step 3: 역할 토큰을 추가하고 구 API 에 deprecated 표시**

`Modules/DesignSystem/Sources/Tokens/ChalNaTypography.swift` 전체를 교체한다:

```swift
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 역할 기반 타이포 토큰.
///
/// 6개 역할이 **표준 iOS 텍스트 스타일에 정확히 대응**한다 —
/// display 28=`.title`, title 22=`.title2`, headline 17=`.headline`,
/// body 16=`.callout`, label 13=`.footnote`, caption 12=`.caption`.
/// 그래서 별도 스케일링 코드 없이 Dynamic Type 을 그대로 따른다.
///
/// 앱 전역 상한은 `RootView` 의 `.dynamicTypeSize(...DynamicTypeSize.accessibility1)`.
///
/// 근거: `docs/superpowers/specs/2026-07-28-app-redesign-design.md` §4.3
public enum ChalNaTypography {

    // MARK: - Roles

    /// 화면 대제목 (28pt bold 상당).
    public static var display: Font  { .system(.title,    design: .default, weight: .bold) }
    /// 섹션 제목 (22pt semibold 상당).
    public static var title: Font    { .system(.title2,   design: .default, weight: .semibold) }
    /// 카드 제목 · 버튼 라벨 (17pt semibold 상당).
    public static var headline: Font { .system(.headline, design: .default, weight: .semibold) }
    /// 본문 (16pt 상당).
    public static var body: Font     { .system(.callout,  design: .default, weight: .regular) }
    /// 메타 · 태그 (13pt medium 상당). 구 `tagLabel()` 대체.
    public static var label: Font    { .system(.footnote, design: .default, weight: .medium) }
    /// 캡션 · 힌트 (12pt 상당). 최소 크기.
    public static var caption: Font  { .system(.caption,  design: .default, weight: .regular) }

    // MARK: - Mono (타임코드 · 퍼센트 등 순수 숫자 전용)

    /// **한글에 쓰지 않는다.** SF Mono 에 한글 글리프가 없어 폴백되며 자간이 어긋난다.
    public static func mono(_ style: Font.TextStyle = .footnote,
                            weight: Font.Weight = .regular) -> Font {
        .system(style, design: .monospaced, weight: weight)
    }

    // MARK: - Tracking

    public enum Tracking {
        /// 제목류 자간.
        public static let title: CGFloat = -0.20
        /// 본문류 자간.
        public static let body: CGFloat  = -0.30
    }

    // MARK: - KERISKEDU (브랜드 순간 · 영상 라벨 WYSIWYG 전용)

    /// Splash 브랜드 라벨과 영상 오버레이 미리보기에만 쓴다.
    /// 영상 출력과 픽셀 일치해야 하므로 **여기만 pt 를 직접 받는다**(Dynamic Type 비적용).
    public static func keris(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        #if canImport(UIKit)
        if let name = kerisFontName, UIFont(name: name, size: size) != nil {
            return Font.custom(name, size: size)
        }
        #endif
        return .system(size: size, weight: weight, design: .default)
    }

    #if canImport(UIKit)
    private static let kerisFontName: String? = {
        let families = UIFont.familyNames.filter { $0.localizedCaseInsensitiveContains("KERIS") }
        for family in families {
            let names = UIFont.fontNames(forFamilyName: family)
            if let line = names.first(where: {
                let upper = $0.uppercased()
                return upper.contains("LINE") || upper.contains("OUTLINE")
            }) {
                return line
            }
            if let any = names.first { return any }
        }
        return nil
    }()

    /// 측정·합성용 UIFont — `keris()` 와 같은 family. 실패 시 시스템 bold.
    public static func kerisUIFont(_ size: CGFloat) -> UIFont {
        if let name = kerisFontName, let f = UIFont(name: name, size: size) { return f }
        return .systemFont(ofSize: size, weight: .bold)
    }
    #endif

    // MARK: - Deprecated (P5 에서 삭제)

    @available(*, deprecated, message: "역할 토큰(display/title/headline/body/label/caption)을 사용하세요.")
    public static func displayKR(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    @available(*, deprecated, message: "역할 토큰을 사용하세요.")
    public static func krSemibold(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    @available(*, deprecated, message: "역할 토큰을 사용하세요.")
    public static func krBody(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    @available(*, deprecated, message: "역할 토큰(display/title)을 사용하세요.")
    public static func title(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    @available(*, deprecated, message: "mono(_:weight:) 를 사용하세요.")
    public static func monoFallback(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    @available(*, deprecated, message: "역할 토큰을 사용하세요.")
    public static func displayEN(_ size: CGFloat, italic: Bool = false, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    @available(*, deprecated, message: "역할 토큰을 사용하세요.")
    public static func serifFallback(_ size: CGFloat, italic: Bool = false) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    @available(*, deprecated, message: "역할 토큰을 사용하세요.")
    public static func hand(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    @available(*, deprecated, message: "역할 토큰(label)을 사용하세요.")
    public static func handFallback(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    @available(*, deprecated, message: "역할 토큰을 사용하세요. 고정 pt 스케일은 P5 에서 삭제됩니다.")
    public enum Size {
        public static let tag: CGFloat      = 12
        public static let caption: CGFloat  = 12
        public static let small: CGFloat    = 14
        public static let body2: CGFloat    = 15
        public static let body: CGFloat     = 16
        public static let bodyLg: CGFloat   = 18
        public static let header: CGFloat   = 19
        public static let h2: CGFloat       = 20
        public static let big: CGFloat      = 22
        public static let h1: CGFloat       = 24
        public static let displayS: CGFloat = 28
        public static let displayL: CGFloat = 32
    }
}

// MARK: - Deprecated tag label helper

public extension Text {
    @available(*, deprecated, message: "ChalNaTypography.label + ChalNaColor.textSecondary 를 직접 쓰세요. mono 는 한글에 쓰지 않습니다.")
    func tagLabel(color: Color = ChalNaColor.textSecondary) -> Text {
        self.font(ChalNaTypography.label).foregroundColor(color)
    }
}
```

> `Tracking` 의 구 멤버(`titleKR`/`bodyKR`/`priceKR`/`displayEN`/`displayKR`/`h2KR`/`tagLabel`)를
> 새 `title`/`body` 두 개로 줄였다. 호출처는 Task 6~25 에서 교체된다. 컴파일이 깨지는
> 곳이 있으면 `ChalNaTypography.Tracking.title`(제목류) 또는 `.body`(본문류)로 바꾼다.

- [ ] **Step 4: 테스트가 통과하는 것을 확인**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme DesignSystem \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -30
```

Expected: Task 1 의 8개 + Task 2 의 5개 = 13개 PASS.

- [ ] **Step 5: 앱 빌드가 통과하도록 Tracking 호출처를 수정**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 \
  | grep -E "error:" | sort -u
```

`Tracking.titleKR` → `Tracking.title`, `Tracking.bodyKR` → `Tracking.body` 로 치환한다.
실사용처는 **`ChalNaButton.swift:61` 한 곳뿐**이다 (확인됨):

```swift
            .tracking(ChalNaTypography.Tracking.title)
```

에러가 더 나오면 그 위치도 같은 규칙으로 바꾼다.

- [ ] **Step 6: 커밋**

```bash
git add Modules/DesignSystem/Sources/Tokens/ChalNaTypography.swift \
        Modules/DesignSystem/Tests/ChalNaTypographyTests.swift \
        Modules/DesignSystem/Sources/Components/
git commit -m "$(cat <<'EOF'
✨ feat(DesignSystem): 역할 기반 타이포 토큰 + Dynamic Type 개방

- display/title/headline/body/label/caption 6종. 각각 표준 텍스트 스타일
  (.title/.title2/.headline/.callout/.footnote/.caption)에 정확히 대응해
  별도 스케일링 코드 없이 Dynamic Type 을 따른다
- mono(_:weight:) 는 design: .monospaced 로 전환, 한글 사용 금지 주석 명시
- Tracking 을 title/body 2종으로 축약
- 구 API(krBody/displayKR/Size/legacy stub 4종/tagLabel)는 deprecated, P5 삭제
- 매핑·기본 pt·최소 12pt 규칙을 테스트로 고정

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Radius · Shadow · Motion + Info.plist Dark + dead colorset 삭제

**Files:**
- Modify: `Modules/DesignSystem/Sources/Tokens/ChalNaRadius.swift`
- Modify: `Modules/DesignSystem/Sources/Tokens/ChalNaShadow.swift`
- Create: `Modules/DesignSystem/Sources/Tokens/ChalNaMotion.swift`
- Modify: `Modules/DesignSystem/Sources/Modifiers/View+ChalNaScreen.swift`
- Modify: `Project.swift:127`
- Delete: `Modules/DesignSystem/Resources/ChalNaColors.xcassets` (7 colorset 전체)

**Interfaces:**
- Consumes: `ChalNaColor.bg` (Task 1).
- Produces: `ChalNaRadius.xs/.sm/.md/.lg/.pill` — `CGFloat`. 구 `film/button/card/sheet` 는 deprecated.
- Produces: `ChalNaShadow.floating` — `[ChalNaShadowLayer]`. 구 `sm/md/lg` 는 deprecated. `View.chalNaShadow(_:)` 시그니처 유지.
- Produces: `ChalNaMotion.fast/.standard/.spring` — `Animation`.

- [ ] **Step 1: 라디우스 토큰 교체**

`Modules/DesignSystem/Sources/Tokens/ChalNaRadius.swift`:

```swift
import CoreGraphics

/// 라디우스 토큰. 커머스 카드용 4px 단위를 버리고 미디어 카드에 맞게 키웠다.
/// 근거: docs/superpowers/specs/2026-07-28-app-redesign-design.md §4.4
public enum ChalNaRadius {
    /// 태그 · 작은 썸네일.
    public static let xs: CGFloat = 6
    /// 버튼 · 입력 필드.
    public static let sm: CGFloat = 10
    /// 카드 · 프리뷰 캔버스.
    public static let md: CGFloat = 14
    /// 바텀시트 · 플로팅 툴바.
    public static let lg: CGFloat = 20
    /// 칩 · 토글.
    public static let pill: CGFloat = 999

    // MARK: - Deprecated (P5 에서 삭제)

    @available(*, deprecated, renamed: "xs")
    public static let film: CGFloat = 6
    @available(*, deprecated, renamed: "sm")
    public static let button: CGFloat = 10
    @available(*, deprecated, renamed: "md")
    public static let card: CGFloat = 14
    @available(*, deprecated, renamed: "lg")
    public static let sheet: CGFloat = 20
}
```

- [ ] **Step 2: 섀도우를 `.floating` 하나로 축약**

`Modules/DesignSystem/Sources/Tokens/ChalNaShadow.swift`:

```swift
import SwiftUI

public struct ChalNaShadowLayer {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat

    public init(_ color: Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}

/// 섀도우 토큰.
///
/// 다크에서는 그림자가 거의 보이지 않으므로 깊이는
/// `bg → surface → surfaceRaised` 3단 밝기 + 1px hairline 으로 표현한다.
/// 그림자는 **떠 있는 툴바 하나**에만 쓴다.
///
/// 근거: docs/superpowers/specs/2026-07-28-app-redesign-design.md §4.2
public enum ChalNaShadow {

    /// 유일한 그림자. 플로팅 툴바 전용.
    public static let floating: [ChalNaShadowLayer] = [
        .init(Color.black.opacity(0.5), radius: 24, y: 8),
    ]

    // MARK: - Deprecated (P5 에서 삭제)

    @available(*, deprecated, message: "다크에서는 밝기 단계로 깊이를 표현합니다. 필요하면 .floating 만 쓰세요.")
    public static let sm: [ChalNaShadowLayer] = []
    @available(*, deprecated, message: "다크에서는 밝기 단계로 깊이를 표현합니다. 필요하면 .floating 만 쓰세요.")
    public static let md: [ChalNaShadowLayer] = [.init(Color.black.opacity(0.5), radius: 24, y: 8)]
    @available(*, deprecated, message: "다크에서는 밝기 단계로 깊이를 표현합니다. 필요하면 .floating 만 쓰세요.")
    public static let lg: [ChalNaShadowLayer] = [.init(Color.black.opacity(0.5), radius: 24, y: 8)]
}

public extension View {
    @ViewBuilder
    func chalNaShadow(_ layers: [ChalNaShadowLayer]) -> some View {
        layers.reduce(AnyView(self)) { partial, layer in
            AnyView(partial.shadow(color: layer.color,
                                   radius: layer.radius,
                                   x: layer.x,
                                   y: layer.y))
        }
    }
}
```

> 구 `sm` 을 빈 배열로 둔 것은 의도적이다 — 라이트용 미세 섀도우는 다크에서 아무 역할을
> 못 하므로 deprecated 기간 동안 **시각적으로 즉시 사라지게** 한다. `md`/`lg` 는 임시로
> `.floating` 과 같은 값을 준다.

- [ ] **Step 3: 모션 토큰 신설**

`Modules/DesignSystem/Sources/Tokens/ChalNaMotion.swift`:

```swift
import SwiftUI

/// 애니메이션 커브 토큰.
/// 근거: docs/superpowers/specs/2026-07-28-app-redesign-design.md §4.4
public enum ChalNaMotion {
    /// 상태 토글 (선택·눌림·표시/숨김).
    public static let fast: Animation = .easeOut(duration: 0.15)
    /// 레이아웃 이동 · 페이드.
    public static let standard: Animation = .easeInOut(duration: 0.24)
    /// 크롭 러버밴드 스냅백. 오버슛 없는 파라미터 — 기존 검증값을 그대로 유지한다.
    public static let spring: Animation = .spring(response: 0.35, dampingFraction: 0.85)
}
```

- [ ] **Step 4: 화면 배경을 `bg` 토큰으로 교체**

`Modules/DesignSystem/Sources/Modifiers/View+ChalNaScreen.swift`:

```swift
import SwiftUI

public extension View {
    /// 다크 시네마틱 표준 화면 배경.
    func chalNaScreen() -> some View {
        self.background(ChalNaColor.bg.ignoresSafeArea())
    }
}
```

- [ ] **Step 5: `Info.plist` 를 Dark 로 전환**

`Project.swift:127` 을 수정한다:

```swift
                    "UIUserInterfaceStyle": "Dark",
```

- [ ] **Step 6: dead colorset 삭제**

**사전 확인 완료:** `ChalNaColors.xcassets` 는 `Modules/DesignSystem/Resources` 의
**유일한 내용물**이다. 따라서 삭제하면 폴더가 비고, `hasResources: true` 도 함께 제거해야 한다
(Tuist `buildableFolders` 가 빈/없는 폴더를 가리키면 실패한다). 세 동작을 한 번에 한다:

```bash
git rm -r Modules/DesignSystem/Resources/ChalNaColors.xcassets
rmdir Modules/DesignSystem/Resources
```

그리고 `Project.swift` 의 DesignSystem 타겟에서 `hasResources: true` 줄을 **삭제**한다
(현재 7~11행):

```swift
        Module.framework(
            name: "DesignSystem",
            isDynamic: true
        ),
```

DesignSystem 은 이제 코드로 정의된 토큰만 쓰므로 리소스가 필요 없다.

`FilmStripCollectionView.swift:71` 이 `UIColor(named: "ChalNaInk")` 로 이 에셋을 참조하는
**유일한 곳**이지만(전수 확인 완료), colorset 이 DesignSystem.framework 번들에 있고
`UIColor(named:)` 의 기본 조회는 `Bundle.main` 이라 **항상 nil 을 반환**한다 → `.black` 으로 낙하.
따라서 삭제해도 동작 변화가 없다. 이 줄은 Task 21 에서 토큰으로 교체된다.

- [ ] **Step 7: 빌드 확인**

```bash
tuist generate
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`. 구 `ChalNaRadius.film` 등은 deprecated 경고만 낸다.

- [ ] **Step 8: 시뮬레이터로 실행해 다크 전환을 눈으로 확인**

```bash
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
open -a Simulator
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           -derivedDataPath /tmp/chalna-build build
xcrun simctl install "iPhone 17 Pro" \
  /tmp/chalna-dd/Build/Products/Debug-iphonesimulator/ChalNa.app
xcrun simctl launch "iPhone 17 Pro" ios.inho.ChalNa
sleep 3
xcrun simctl io "iPhone 17 Pro" screenshot /tmp/chalna-p0-home.png
open /tmp/chalna-p0-home.png
```

Expected: **화면이 아직 흉하다.** 배경만 어두워지고 `Color.white` 하드코딩 60곳은 흰 판으로
남아 있는 게 정상이다. 이것이 P2~P4 에서 지워야 할 대상 목록이다.
확인할 것: 시스템 다크 모드가 적용됐는지(상태바 글자가 흰색), 배경이 `#0B0A10` 인지.

- [ ] **Step 9: 커밋**

```bash
git add Project.swift Modules/DesignSystem/Sources/Tokens/ Modules/DesignSystem/Sources/Modifiers/View+ChalNaScreen.swift
git commit -m "$(cat <<'EOF'
✨ feat(DesignSystem): 라디우스·섀도우·모션 토큰 + 다크 모드 전환

- ChalNaRadius 를 xs/sm/md/lg/pill 로 교체 (커머스 4px 단위 폐기)
- ChalNaShadow 를 .floating 하나로 축약 — 다크에서는 밝기 3단으로 깊이 표현
- ChalNaMotion 신설 (fast/standard/spring)
- chalNaScreen() 배경을 ChalNaColor.bg 로
- Info.plist UIUserInterfaceStyle: Light → Dark
- dead colorset 7개 삭제 (UIColor(named:) 가 항상 nil 이었어 동작 변화 없음)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: 정적 검사 스크립트

**Files:**
- Create: `scripts/design-lint.sh`

**Interfaces:**
- Produces: `scripts/design-lint.sh` — 위반이 있으면 exit 1, 없으면 exit 0. 규칙별 위반 위치를 출력한다.
- 이 스크립트는 **P5(Task 26)까지 실패하는 것이 정상이다.** P2~P4 진행 중 진척 측정기로 쓴다.

- [ ] **Step 1: 스크립트 작성**

`scripts/design-lint.sh`:

```bash
#!/usr/bin/env bash
# 디자인 토큰 규율 정적 검사.
# 근거: docs/superpowers/specs/2026-07-28-app-redesign-design.md §8
#
# P0~P4 동안에는 실패하는 것이 정상이다(마이그레이션 진척 측정기).
# P5 에서 exit 0 이 되어야 한다.
set -uo pipefail
cd "$(dirname "$0")/.."

SCAN_DIRS=(ChalNa/Sources Modules)
FAIL=0

# $1 = 규칙 이름, $2 = grep 패턴, $3.. = 제외할 경로 조각
check() {
  local name="$1" pattern="$2"; shift 2
  local hits
  hits=$(grep -rnE "$pattern" --include='*.swift' "${SCAN_DIRS[@]}" 2>/dev/null | grep -v '/Tests/')
  for skip in "$@"; do
    hits=$(printf '%s\n' "$hits" | grep -v "$skip")
  done
  hits=$(printf '%s\n' "$hits" | grep -v '^$')
  local count
  count=$(printf '%s\n' "$hits" | grep -c . )
  if [ "$count" -gt 0 ]; then
    printf '\033[31m✗ %-28s %s건\033[0m\n' "$name" "$count"
    printf '%s\n' "$hits" | sed 's/^/    /'
    FAIL=1
  else
    printf '\033[32m✓ %-28s 0건\033[0m\n' "$name"
  fi
}

echo "── ChalNa design lint ──"

# 1. 시스템 폰트 직접 호출 — ChalNaIcon 은 글리프 크기 지정에 필요하므로 예외
check ".font(.system(" '\.font\(\.system\(' \
  'DesignSystem/Sources/Icons/ChalNaIcon.swift' \
  'DesignSystem/Sources/Tokens/'

# 2. hex 리터럴 색 — 토큰 정의와 콘텐츠 그라디언트만 예외
check "Color(hex:)" 'Color\(hex:' \
  'DesignSystem/Sources/Tokens/' \
  'Models/Sources/ColorHex.swift' \
  'Models/Sources/ThumbnailPreset.swift'

# 3. cornerRadius 숫자 리터럴 — 세 가지 형태를 모두 잡는다:
#      RoundedRectangle(cornerRadius: 8)   ← 콜론형
#      layer.cornerRadius = 16             ← UIKit 대입형
#      .cornerRadius(15)                   ← SwiftUI 베어 모디파이어 (CLAUDE.md 가 명시적으로 금지)
#    'cornerRadius: [0-9]' 만 쓰면 뒤 두 형태를 영구히 못 본다.
#    구분자 앞 공백을 반드시 허용해야 한다 — `layer.cornerRadius = 16` 은
#    cornerRadius 와 '=' 사이에 공백이 있어 'cornerRadius[:=(]' 로는 안 걸린다.
#    ChalNaRadius.md 처럼 토큰을 넘기는 경우는 숫자가 아니라 안 걸린다.
# 예외: 아이콘 Path 기하(반지름이 아님), FilmStripCollectionView(Task 21 이 토큰화하며 이 예외를 제거)
check "cornerRadius 리터럴" 'cornerRadius *[:=(] *[0-9]' \
  'DesignSystem/Sources/Icons/ChalNaIcon.swift' \
  'FilmStripCollectionView.swift'

# 4. 흰색 하드코딩 — 영상 출력 픽셀과 일치해야 하는 곳만 예외
#    회색조 이니셜라이저 형태(Color(white:) / UIColor(white:))도 반드시 포함한다.
#    이게 빠지면 Color.white 를 Color(white: 1.0) 으로 바꾸는 것만으로 규칙을 우회할 수 있어
#    Task 26 게이트가 무의미해진다 (Task 9 에서 실제로 이 형태가 들어왔다).
#    CompositionService: CLAUDE.md 가 "CompositionService 의 비디오 텍스트 오버레이는
#    불가피한 예외" 라고 명시하고, 스펙 §10 비범위에도 들어 있어 손댈 수 없다.
#    (UIColor.white 2곳: CompositionService.swift:488 라벨 전경, :566 배경 레이어)
#    이 예외가 없으면 규칙 4 는 Task 26 에서 결코 0 이 될 수 없다.
check "흰색 하드코딩" '(Color\.white|\.white\b|Color\(white:|UIColor\(white:)' \
  'DesignSystem/Sources/Tokens/' \
  'CompositionService/Sources/CompositionService.swift' \
  'TimelineFeature/Sources/Components/ClipLabelText.swift' \
  'TimelineFeature/Sources/LabelEditorView.swift' \
  'Models/Sources/ClipLabel.swift' \
  'Models/Sources/ThumbnailPreset.swift'

# 5. UIColor(named:) — 번들 조회가 조용히 실패하는 패턴
check "UIColor(named:)" 'UIColor\(named:'

echo "────────────────────────"
if [ "$FAIL" -eq 0 ]; then
  echo -e "\033[32m전부 통과\033[0m"
else
  echo -e "\033[33m위반 남음 (P5 까지 정상)\033[0m"
fi
exit "$FAIL"
```

- [ ] **Step 2: 실행 권한 부여 후 현재 상태를 측정**

```bash
chmod +x scripts/design-lint.sh
./scripts/design-lint.sh
```

Expected: exit 1. 대략 다음 규모의 위반이 보고된다 —
`.font(.system(` 18건, `Color(hex:)` 0건, `cornerRadius 리터럴` 2건, 흰색 하드코딩 64건, `UIColor(named:)` 1건.
(흰색은 CompositionService 2곳을 예외로 뺀 뒤의 수치다.)
**이 숫자를 커밋 메시지에 기록해 P5 에서 0 이 되는 것을 대조한다.**

- [ ] **Step 3: 커밋**

```bash
git add scripts/design-lint.sh
git commit -m "$(cat <<'EOF'
🔧 chore: 디자인 토큰 규율 정적 검사 스크립트 추가

5개 규칙: .font(.system( / Color(hex:) / cornerRadius 리터럴 /
흰색 하드코딩 / UIColor(named:)

예외 경로를 규칙별로 명시 — 토큰 정의, ChalNaIcon 글리프 크기,
ThumbnailPreset 콘텐츠 그라디언트, 영상 출력과 픽셀 일치해야 하는 라벨 박스.

P0 시점 위반: .font(.system( 18건 / 흰색 60건 / UIColor(named:) 1건.
P5 에서 전부 0 이 되어야 한다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# Phase P1 — 컴포넌트 (Task 5–12)

## Task 5: ChalNaIcon SF Symbols 전환

**Files:**
- Modify: `Modules/DesignSystem/Sources/Icons/ChalNaIcon.swift` (전체 교체, 커스텀 Lucide 패스 ~270줄 제거)
- Create: `Modules/DesignSystem/Tests/ChalNaIconTests.swift`

**Interfaces:**
- Consumes: 없음.
- Produces: `ChalNaIconKind` — 기존 21 케이스 유지 + `.settings`, `.livePhoto`, `.video` 추가. `CaseIterable`, `Sendable`, `String` raw value 유지.
- Produces: `ChalNaIconKind.systemName: String` (public) — 테스트가 검증한다.
- Produces: `ChalNaIcon(_ kind: ChalNaIconKind, size: CGFloat = 24, weight: Font.Weight = .regular)`.
  구 `strokeWidth:` 파라미터는 **호출처가 0곳이라 제거한다**(확인됨).

- [ ] **Step 1: 실패하는 심볼 존재 테스트를 작성**

`Modules/DesignSystem/Tests/ChalNaIconTests.swift`:

```swift
import Testing
import SwiftUI
import UIKit
import DesignSystem

/// 모든 아이콘이 실제 존재하는 SF Symbol 에 매핑되는지 검증한다.
/// 오타난 심볼 이름은 런타임에 조용히 빈 이미지가 되므로 컴파일로는 잡히지 않는다.
struct ChalNaIconTests {

    @Test func testEveryKindMapsToExistingSystemSymbol() {
        for kind in ChalNaIconKind.allCases {
            let name = kind.systemName
            #expect(!name.isEmpty, "\(kind.rawValue) 의 systemName 이 비었다")
            #expect(UIImage(systemName: name) != nil,
                    "\(kind.rawValue) → \"\(name)\" 심볼이 이 OS 에 없다")
        }
    }

    @Test func testNoTwoKindsShareTheSameSymbol() {
        var seen: [String: ChalNaIconKind] = [:]
        for kind in ChalNaIconKind.allCases {
            let name = kind.systemName
            if let previous = seen[name] {
                Issue.record("\(kind.rawValue) 와 \(previous.rawValue) 가 같은 심볼 \"\(name)\" 을 쓴다")
            }
            seen[name] = kind
        }
    }

    /// 화면에서 쓰이는 종류가 전부 정의돼 있는지 — 누락되면 컴파일 에러로 잡히지만
    /// 이 테스트는 '왜 필요한지'를 문서화한다.
    @Test func testRequiredKindsExist() {
        let required: [ChalNaIconKind] = [
            .play, .pause, .plus, .share, .download, .film,
            .chevronLeft, .chevronRight, .close, .check,
            .skipBack, .skipForward, .trash, .move, .rotate, .textLabel,
            .settings, .livePhoto, .video,
        ]
        for kind in required {
            #expect(ChalNaIconKind.allCases.contains(kind), "\(kind.rawValue) 누락")
        }
    }
}
```

- [ ] **Step 2: 테스트가 실패하는 것을 확인**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme DesignSystem \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -30
```

Expected: 컴파일 실패 — `ChalNaIconKind` 에 `systemName` 이 없고 `.settings`/`.livePhoto`/`.video` 케이스가 없음.

- [ ] **Step 3: ChalNaIcon 을 SF Symbols 로 전면 교체**

`Modules/DesignSystem/Sources/Icons/ChalNaIcon.swift` 전체를 교체한다 (기존 `LucideShape` 및 `subpaths(for:)` 전부 삭제):

```swift
import SwiftUI

/// 아이콘 종류. 내부 구현은 SF Symbols 로 통일돼 있다.
///
/// 이전에는 커스텀 Lucide 패스(1.5pt 고정 stroke) 20종 + SF Symbols 2종 + Chip 내부
/// SF Symbols 2종이 섞여 **같은 툴바에서 선 굵기가 다르게 보였다**. SF Symbols 로
/// 통일하면 optical sizing·weight 가 옆 텍스트와 자동으로 맞고 Dynamic Type 을 따른다.
///
/// 근거: `docs/superpowers/specs/2026-07-28-app-redesign-design.md` §5.4
public enum ChalNaIconKind: String, CaseIterable, Sendable {
    case play, pause, plus, share, download, heart, calendar, film
    case chevronLeft, chevronRight, close, check
    case skipBack, skipForward
    case scissors, reorderLines, trash, music
    case move
    case rotate
    case textLabel
    case settings
    case livePhoto
    case video

    /// 대응하는 SF Symbol 이름. `ChalNaIconTests` 가 존재 여부를 검증한다.
    public var systemName: String {
        switch self {
        case .play:         return "play.fill"
        case .pause:        return "pause.fill"
        case .plus:         return "plus"
        case .share:        return "square.and.arrow.up"
        case .download:     return "arrow.down.to.line"
        case .heart:        return "heart"
        case .calendar:     return "calendar"
        case .film:         return "film"
        case .chevronLeft:  return "chevron.left"
        case .chevronRight: return "chevron.right"
        case .close:        return "xmark"
        case .check:        return "checkmark"
        case .skipBack:     return "backward.end.fill"
        case .skipForward:  return "forward.end.fill"
        case .scissors:     return "scissors"
        case .reorderLines: return "line.3.horizontal"
        case .trash:        return "trash"
        case .music:        return "music.note"
        case .move:         return "arrow.up.and.down.and.arrow.left.and.right"
        case .rotate:       return "rotate.left"
        case .textLabel:    return "textformat"
        case .settings:     return "gearshape"
        case .livePhoto:    return "livephoto"
        case .video:        return "video"
        }
    }
}

/// SF Symbol 기반 아이콘.
///
/// `size` 는 기본 Dynamic Type 설정에서의 글리프 pt 이고, 사용자가 글씨를 키우면
/// `@ScaledMetric` 이 같은 비율로 확대한다.
public struct ChalNaIcon: View {
    /// Dynamic Type 배율. 값 1 을 `.body` 기준으로 스케일해 배율만 얻는다.
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    public let kind: ChalNaIconKind
    public var size: CGFloat
    public var weight: Font.Weight

    public init(_ kind: ChalNaIconKind, size: CGFloat = 24, weight: Font.Weight = .regular) {
        self.kind = kind
        self.size = size
        self.weight = weight
    }

    public var body: some View {
        Image(systemName: kind.systemName)
            .font(.system(size: size * typeScale, weight: weight))
            .symbolRenderingMode(.monochrome)
            .accessibilityHidden(true)   // 라벨은 감싸는 버튼이 제공한다
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 24) {
            ForEach(ChalNaIconKind.allCases, id: \.self) { kind in
                VStack(spacing: 8) {
                    ChalNaIcon(kind, size: 26)
                        .foregroundColor(ChalNaColor.textPrimary)
                    Text(verbatim: kind.rawValue)
                        .font(ChalNaTypography.caption)
                        .foregroundColor(ChalNaColor.textSecondary)
                }
            }
        }
        .padding(24)
    }
    .background(ChalNaColor.bg)
}
```

- [ ] **Step 4: 테스트가 통과하는 것을 확인**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme DesignSystem \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -30
```

Expected: 전부 PASS. **실패한다면** 그 심볼 이름이 iOS 18 에 없다는 뜻이므로,
Xcode 의 SF Symbols 앱에서 대체 이름을 찾아 `systemName` 을 수정한다
(예: `arrow.down.to.line` 이 없으면 `square.and.arrow.down`).

- [ ] **Step 5: `ChalNaChip` 의 글리프 크기 누락을 고친다 (SF Symbols 전환 부수 효과)**

`Modules/DesignSystem/Sources/Components/ChalNaChip.swift` 의 `leadingGlyph` default 분기가
**`size:` 인자 없이** `ChalNaIcon` 을 호출한다 — 즉 기본값 24pt 글리프를 10pt 프레임에 넣는다:

```swift
            default:
                ChalNaIcon(icon ?? .download).frame(width: 10, height: 10)
```

이를 다음으로 바꾼다:

```swift
            default:
                ChalNaIcon(icon ?? .download, size: 10)
```

> **왜 지금 고치는가.** 커스텀 Lucide 패스에서는 1.5pt 얇은 선이라 넘침이 눈에 잘 안 띄었지만,
> SF Symbols 는 채워진 글리프라 10pt 프레임 밖으로 확실히 삐져나온다.
> 도달 경로: `ExportView.swift:211`(DONE 칩 — 실사용자 노출), `MediaPickerView.swift:329`(DEV 칩),
> Showcase 3곳. `ChalNaChip` 은 Task 9 에서 `ChalNaTag` 로 대체되지만 그때까지 이 상태로 둘 수 없다.
> 바깥 `.frame(width: 10, height: 10)` 은 그대로 둔다(레이아웃 슬롯 역할).

- [ ] **Step 6: 앱 빌드 확인**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:" | sort -u
```

Expected: 에러 없음. `ChalNaIcon(...)` 호출 41곳은 `size:` 만 쓰므로 시그니처가 그대로다.

- [ ] **Step 7: 커밋**

```bash
git add Modules/DesignSystem/Sources/Icons/ChalNaIcon.swift \
        Modules/DesignSystem/Sources/Components/ChalNaChip.swift \
        Modules/DesignSystem/Tests/ChalNaIconTests.swift
git commit -m "$(cat <<'EOF'
♻️ refactor(DesignSystem): 아이콘을 SF Symbols 로 단일화

커스텀 Lucide 패스 20종을 제거하고 전부 SF Symbols 로 매핑.
호출처 41곳은 size: 만 쓰므로 변경 없음 (strokeWidth: 사용처 0곳 확인 후 제거).

- optical sizing·weight 가 옆 텍스트와 자동으로 맞음
- @ScaledMetric 으로 Dynamic Type 추종
- .settings/.livePhoto/.video 추가 → 화면의 systemName 직접 사용 8곳을 흡수할 준비
- 심볼 존재·중복 여부를 테스트로 검증 (오타는 런타임에 조용히 빈 이미지가 된다)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: ChalNaNavBar · ChalNaNavAction · chalNaScrollHairline

**Files:**
- Create: `Modules/DesignSystem/Sources/Components/ChalNaNavBar.swift`
- Create: `Modules/DesignSystem/Sources/Components/ChalNaNavAction.swift`
- Create: `Modules/DesignSystem/Sources/Modifiers/View+ChalNaScrollHairline.swift`
- Keep (아직 삭제하지 않음): `ChalNaNavigationBar.swift`, `ChalNaHeaderActionButtonStyle.swift`, `View+ChalNaTopBar.swift` — 화면 마이그레이션(Task 13~25)이 끝난 Task 26 에서 삭제한다.

**Interfaces:**
- Consumes: `ChalNaColor.bg/.surface/.border/.textPrimary/.textSecondary/.accent`, `ChalNaTypography.headline/.caption/.label`, `ChalNaIcon`, `ChalNaMotion.fast`, `ChalNaRadius.pill`.
- Produces: `ChalNaNavAction` — `.back(action:)`, `.close(action:)`, `.icon(_:accessibilityLabel:action:)`, `.text(_:action:)`, `.empty` 정적 생성자. 모두 44×44 히트, 글리프 20pt 고정.
- Produces:
  ```swift
  ChalNaNavBar(
      title: LocalizedStringKey | verbatimTitle: String,
      caption: String? = nil,
      leading: ChalNaNavAction = .empty,
      trailing: ChalNaNavAction = .empty,
      showsDivider: Bool = false
  )
  ```
  높이 `minHeight: 52`(고정 아님). 좌·우 슬롯 `minWidth: 56`(고정 아님).
- Produces: `View.chalNaScrollHairline(progress: Double)`.

- [ ] **Step 1: Showcase 도달 경로 추가 (P1 전체의 시각 검증 수단)**

**문제.** 계획은 P1 컴포넌트의 검증 수단으로 "Showcase 스크린샷"을 지정하지만,
`DesignSystemShowcaseView` 는 `ContentView.swift:32` 의 `#Preview` 에만 존재하고
**실행 중인 앱에서 도달할 방법이 없다**(사전 확인 완료). Xcode Canvas 는 헤드리스로 열 수 없으므로
지금 상태로는 Task 6~12 가 만드는 컴포넌트 18종을 눈으로 볼 수가 없다.

DEBUG 전용 환경변수 경로를 하나 만든다.

`ChalNa/Sources/App/AppMode.swift` 끝에 추가:

```swift
extension AppMode {
    /// DEBUG 전용. `CHALNA_APP_MODE=showcase` 로 실행하면 앱 대신
    /// 디자인 시스템 쇼케이스를 띄운다 — P1 컴포넌트의 시각 검증 경로.
    ///
    /// enum 케이스가 아니라 별도 플래그인 이유: `AppMode` 에 케이스를 더하면
    /// `AppFeature` 의 `.real`/`.devMock` switch 가 비망라가 되어 그쪽까지 손대야 한다.
    static var isShowcase: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["CHALNA_APP_MODE"] == "showcase"
        #else
        return false
        #endif
    }
}
```

`ChalNa/Sources/ContentView.swift` 의 `body` 를 분기한다 (기존 내용은 `mainContent` 로 추출):

```swift
    public var body: some View {
        if AppMode.isShowcase {
            DesignSystemShowcaseView()
        } else {
            mainContent
        }
    }

    private var mainContent: some View {
        ZStack {
            // RootView 를 스플래시 뒤에서 미리 생성 → 페이드아웃 시 홈이 이미 준비됨.
            RootView()

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeInOut(duration: 0.35)) { showSplash = false }
        }
    }
```

이후 **Task 6~12 는 모두 이 명령으로 컴포넌트를 실물 확인한다:**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           -derivedDataPath /tmp/chalna-build build
xcrun simctl install "iPhone 17 Pro" /tmp/chalna-dd/Build/Products/Debug-iphonesimulator/ChalNa.app
xcrun simctl terminate "iPhone 17 Pro" ios.inho.ChalNa 2>/dev/null || true
SIMCTL_CHILD_CHALNA_APP_MODE=showcase xcrun simctl launch "iPhone 17 Pro" ios.inho.ChalNa
sleep 3
xcrun simctl io "iPhone 17 Pro" screenshot \
  .superpowers/sdd/2026-07-28-dark-redesign/shot-t<N>-showcase.png
```

> **스크린샷은 반드시 위 SDD 워크스페이스 경로에 저장한다.** 세션 로컬 scratchpad 에 두면
> 리뷰어가 열 수 없어 시각 증거가 리뷰에서 빠진다(Task 7 에서 실제로 발생 —
> 리뷰어가 "Cannot verify from diff: 스크린샷을 열어볼 수 없음"으로 남겼다).

> Showcase 는 Task 12 에서 새 인벤토리로 재작성된다. Task 6~11 동안에는 구 Showcase 가
> 뜨므로 **새로 만든 컴포넌트는 아직 거기 없다.** 그래서 각 태스크는 자기가 만든 컴포넌트를
> 구 Showcase 하단에 임시 섹션으로 덧붙여 스크린샷을 찍고, Task 12 의 전면 재작성 때
> 그 임시 섹션들이 정식 구조로 흡수된다. 임시 섹션은 `// TEMP(T<N>):` 주석으로 표시한다.

- [ ] **Step 2: ChalNaNavAction 작성**

`Modules/DesignSystem/Sources/Components/ChalNaNavAction.swift`:

```swift
import SwiftUI

/// 헤더 좌·우 액션. **호출처가 글리프 크기를 지정할 수 없다** —
/// 같은 바에서 10pt chevron 과 33pt X 가 공존했던 문제를 구조적으로 막는다.
///
/// 근거: `docs/superpowers/specs/2026-07-28-app-redesign-design.md` §5.1
public struct ChalNaNavAction: View {

    /// 모든 아이콘 액션의 글리프 크기. 개별 조정 불가.
    private static let glyph: CGFloat = 20
    /// HIG 최소 터치 영역.
    private static let hit: CGFloat = 44

    private enum Kind {
        case icon(ChalNaIconKind)
        case text(LocalizedStringKey)
        case empty
    }

    private let kind: Kind
    private let action: () -> Void
    private let label: LocalizedStringKey?

    private init(kind: Kind, label: LocalizedStringKey?, action: @escaping () -> Void) {
        self.kind = kind
        self.label = label
        self.action = action
    }

    // MARK: - Factories

    public static func back(action: @escaping () -> Void) -> ChalNaNavAction {
        .init(kind: .icon(.chevronLeft), label: "뒤로", action: action)
    }

    public static func close(action: @escaping () -> Void) -> ChalNaNavAction {
        .init(kind: .icon(.close), label: "닫기", action: action)
    }
    // 주의: "닫기" 는 Localizable.xcstrings 에 아직 en/ja 번역이 없다(사전 확인 완료).
    // Step 6 에서 번역을 추가한다. "뒤로" 는 이미 Back/戻る 가 있다.

    public static func icon(
        _ kind: ChalNaIconKind,
        accessibilityLabel: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> ChalNaNavAction {
        .init(kind: .icon(kind), label: accessibilityLabel, action: action)
    }

    /// 우측 텍스트 액션("완료"/"저장"). accent 색 + headline.
    public static func text(_ title: LocalizedStringKey, action: @escaping () -> Void) -> ChalNaNavAction {
        .init(kind: .text(title), label: title, action: action)
    }

    public static var empty: ChalNaNavAction {
        .init(kind: .empty, label: nil, action: {})
    }

    // MARK: - Body

    public var body: some View {
        switch kind {
        case .empty:
            Color.clear.frame(width: Self.hit, height: Self.hit)
        case .icon(let iconKind):
            button {
                ChalNaIcon(iconKind, size: Self.glyph, weight: .semibold)
                    .foregroundColor(ChalNaColor.textPrimary)
            }
        case .text(let title):
            button {
                Text(title)
                    .font(ChalNaTypography.headline)
                    .foregroundColor(ChalNaColor.accent)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func button<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Button(action: action) {
            content()
                .padding(.horizontal, 8)
                .frame(minWidth: Self.hit, minHeight: Self.hit)
                .contentShape(Rectangle())
        }
        .buttonStyle(NavActionPressStyle())
        .accessibilityLabel(label ?? "")
    }
}

private struct NavActionPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1)
            .animation(ChalNaMotion.fast, value: configuration.isPressed)
    }
}
```

- [ ] **Step 3: ChalNaNavBar 작성**

`Modules/DesignSystem/Sources/Components/ChalNaNavBar.swift`:

```swift
import SwiftUI

/// 시스템 네비게이션 바를 숨긴 화면용 커스텀 헤더.
///
/// 좌·우 슬롯이 **고정 56pt** 라 타이틀이 물리적으로 액션 영역을 침범할 수 없다.
/// (구 `ChalNaNavigationBar` 는 타이틀을 ZStack 오버레이로 얹어 폭 제한이 없었고,
///  Timeline 의 사용자 입력 제목이 길면 back 버튼과 겹쳤다.)
///
/// 근거: `docs/superpowers/specs/2026-07-28-app-redesign-design.md` §5.1
public struct ChalNaNavBar: View {

    /// 좌·우 슬롯 **최소** 폭 = 44pt 액션 + 좌우 6pt 여백.
    ///
    /// 고정폭이 아니라 최소폭이다. `.text("완료")` 같은 텍스트 액션은 Dynamic Type 확대 시
    /// 56pt 를 넘길 수 있고(headline 17pt 에서 "Done" ≈ 38pt + 좌우 8pt 패딩 = 54pt,
    /// accessibility1 에서는 여유가 사라진다), 고정폭이면 그 글자가 잘린다.
    /// 최소폭으로 두면 슬롯이 필요한 만큼 늘어나 타이틀을 밀어낸다 —
    /// **타이틀이 살짝 비대칭이 되는 것이 글자가 잘리는 것보다 낫다.**
    /// 겹침 방지(감사 #20)는 HStack 이 공간을 배분하는 것으로 이미 보장된다.
    private static let slot: CGFloat = 56
    public static let height: CGFloat = 52

    private let titleText: Text
    private let caption: String?
    private let leading: ChalNaNavAction
    private let trailing: ChalNaNavAction
    private let showsDivider: Bool

    public init(
        title: LocalizedStringKey,
        caption: String? = nil,
        leading: ChalNaNavAction = .empty,
        trailing: ChalNaNavAction = .empty,
        showsDivider: Bool = false
    ) {
        self.titleText = Text(title)
        self.caption = caption
        self.leading = leading
        self.trailing = trailing
        self.showsDivider = showsDivider
    }

    /// 로컬라이즈하지 않는 타이틀(브랜드명·사용자 입력 제목)용.
    public init(
        verbatimTitle: String,
        caption: String? = nil,
        leading: ChalNaNavAction = .empty,
        trailing: ChalNaNavAction = .empty,
        showsDivider: Bool = false
    ) {
        self.titleText = Text(verbatim: verbatimTitle)
        self.caption = caption
        self.leading = leading
        self.trailing = trailing
        self.showsDivider = showsDivider
    }

    public var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(minWidth: Self.slot, alignment: .leading)

            VStack(spacing: 1) {
                titleText
                    .font(ChalNaTypography.headline)
                    .tracking(ChalNaTypography.Tracking.title)
                    .foregroundColor(ChalNaColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let caption {
                    Text(verbatim: caption)
                        .font(ChalNaTypography.caption)
                        .foregroundColor(ChalNaColor.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity)

            trailing
                .frame(minWidth: Self.slot, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .frame(minHeight: Self.height)
        .frame(maxWidth: .infinity)
        .background(ChalNaColor.bg.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(ChalNaColor.border)
                    .frame(height: 1)
            }
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        ChalNaNavBar(title: "설정", leading: .back {})
        ChalNaNavBar(
            verbatimTitle: "제주도에서 보낸 아주 긴 제목의 어느 봄날 기록",
            caption: "8 클립 · 01:40",
            leading: .back {},
            trailing: .text("저장") {},
            showsDivider: true
        )
        ChalNaNavBar(
            verbatimTitle: "ChalNa",
            trailing: .icon(.settings, accessibilityLabel: "설정") {}
        )
        Spacer()
    }
    .background(ChalNaColor.bg)
}
```

- [ ] **Step 4: chalNaScrollHairline 모디파이어 작성**

`Modules/DesignSystem/Sources/Modifiers/View+ChalNaScrollHairline.swift`:

```swift
import SwiftUI

public extension View {
    /// 본문이 스크롤되어 올라온 정도(0→1)에 따라 헤더 하단 hairline 이 나타난다.
    ///
    /// 구 `chalNaHeaderBar` 는 배경 흰색을 같이 페이드했지만, 다크에서는 헤더 배경이
    /// 이미 `bg` 라 페이드가 무의미하다. hairline 만 남긴다.
    func chalNaScrollHairline(progress: Double) -> some View {
        let clamped = max(0, min(1, progress))
        return overlay(alignment: .bottom) {
            Rectangle()
                .fill(ChalNaColor.border.opacity(clamped))
                .frame(height: 1)
        }
    }
}
```

- [ ] **Step 5: 빌드 확인**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:" | sort -u
```

Expected: 에러 없음 (신규 파일만 추가, 기존 헤더는 그대로 남아 있다).

- [ ] **Step 6: `닫기` 번역 추가**

`ChalNaNavAction.close` 의 `accessibilityLabel` 이 `"닫기"` 인데, `ChalNa/Resources/Localizable.xcstrings`
에 이 키의 en/ja 번역이 **없다**(사전 확인 완료 — `뒤로`/`저장`/`완료` 는 있다).
번역 없이 두면 영어·일본어 UI 에서 VoiceOver 가 "닫기" 를 그대로 읽는다.

`Localizable.xcstrings` 에 다음 항목을 추가한다 (기존 항목들과 같은 구조):

```json
    "닫기" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Close" } },
        "ja" : { "stringUnit" : { "state" : "translated", "value" : "閉じる" } }
      }
    },
```

> 구 `ChalNaHeaderCloseButton` 은 라벨로 `"취소"`(Cancel/キャンセル)를 썼는데, 닫기 버튼에
> "취소" 는 의미가 어긋난다. `"닫기"` 로 바꾸는 것이 맞고 그래서 새 키가 필요하다.

- [ ] **Step 7: Showcase 에 임시 섹션 추가 후 실물 스크린샷으로 긴 타이틀 충돌 확인**

`ChalNaNavBar.swift` 를 Xcode 에서 열고 Canvas 프리뷰를 실행한다.
확인할 것: 두 번째 바의 긴 제목이 **back 버튼·"저장" 위로 겹치지 않고 말줄임**되는지.
겹친다면 `slot` 폭 또는 `frame(maxWidth: .infinity)` 배치가 잘못된 것이다.

- [ ] **Step 8: 커밋**

```bash
git add ChalNa/Resources/Localizable.xcstrings \
        Modules/DesignSystem/Sources/Components/ChalNaNavBar.swift \
        Modules/DesignSystem/Sources/Components/ChalNaNavAction.swift \
        Modules/DesignSystem/Sources/Modifiers/View+ChalNaScrollHairline.swift
git commit -m "$(cat <<'EOF'
✨ feat(DesignSystem): ChalNaNavBar · ChalNaNavAction · chalNaScrollHairline

- NavBar: 좌·우 슬롯 고정 56pt HStack 3분할. 타이틀이 액션 영역을 물리적으로
  침범할 수 없어 긴 제목이 back 버튼과 겹치던 문제가 구조적으로 사라짐
- NavAction: 글리프 20pt 고정 · 히트 44pt. 호출처가 크기를 지정할 수 없어
  10pt chevron 과 33pt X 가 공존하던 문제 재발 불가
- chalNaScrollHairline: 다크에서 무의미한 배경 페이드를 제거하고 hairline 만

구 ChalNaNavigationBar 는 화면 마이그레이션이 끝나는 P5 에서 삭제한다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: ChalNaButton — variant 3종 + destructive · ChalNaBottomBar

**Files:**
- Modify: `Modules/DesignSystem/Sources/Components/ChalNaButton.swift` (전체 교체)
- Create: `Modules/DesignSystem/Sources/Components/ChalNaBottomBar.swift`

**Interfaces:**
- Consumes: `ChalNaColor`, `ChalNaTypography.headline/.body`, `ChalNaRadius.sm`, `ChalNaMotion.fast`.
- Produces: `ChalNaButtonVariant` — `.primary`, `.secondary`, `.ghost` (구 5종 대체).
- Produces: `ChalNaButtonSize` — `.lg`(52) / `.md`(44) / `.sm`(36).
- Produces:
  ```swift
  .buttonStyle(.chalNa(_ variant: ChalNaButtonVariant,
                       size: ChalNaButtonSize = .lg,
                       fillWidth: Bool = false,
                       destructive: Bool = false))
  ```
- Produces: 축약 `.chalNaPrimary`, `.chalNaSecondary`, `.chalNaGhost`.
- Produces: `ChalNaBottomBar { content }` — `safeAreaInset(edge: .bottom)` 에 넣는 하단 액션 영역. 여백·`bg` 배경·상단 hairline·세이프에어리어를 한 곳에서 처리.
- Produces: **구 별칭 deprecated 유지** — `.chalNaFilled`/`.chalNaOutlined`/`.chalNaText`/`.chalNaCoral`/`.chalNaOutline`, 그리고 구 variant 케이스 `.filled`/`.outlined`/`.standardFilled`/`.standardOutlined`/`.text` 와 구 size `.xl`. Task 13~25 가 호출처를 옮긴 뒤 Task 26 에서 삭제.

- [ ] **Step 1: ChalNaButton 전체 교체**

```swift
import SwiftUI

/// 버튼 변형. 3종으로 줄이고 파괴적 여부를 **플래그로** 분리했다.
///
/// 이전에는 각 호출처가 "삭제는 무슨 색?"을 스스로 판단해서
/// EditToolbar 는 Primary 보라, FilmDetail 은 danger 레드를 썼다.
/// `destructive: true` 하나로 결정을 컴포넌트가 가져간다.
///
/// 근거: `docs/superpowers/specs/2026-07-28-app-redesign-design.md` §5.2
public enum ChalNaButtonVariant {
    /// 면형. accentFill 배경 + onAccent 라벨.
    case primary
    /// 선형. surface 배경 + border.
    case secondary
    /// 텍스트만.
    case ghost

    // MARK: - Deprecated 별칭 (P5 삭제)
    @available(*, deprecated, renamed: "primary")
    public static var filled: ChalNaButtonVariant { .primary }
    @available(*, deprecated, renamed: "secondary")
    public static var outlined: ChalNaButtonVariant { .secondary }
    @available(*, deprecated, renamed: "primary")
    public static var standardFilled: ChalNaButtonVariant { .primary }
    @available(*, deprecated, renamed: "secondary")
    public static var standardOutlined: ChalNaButtonVariant { .secondary }
    @available(*, deprecated, renamed: "ghost")
    public static var text: ChalNaButtonVariant { .ghost }
}

public enum ChalNaButtonSize {
    case lg   // 52pt
    case md   // 44pt
    case sm   // 36pt

    @available(*, deprecated, renamed: "lg")
    public static var xl: ChalNaButtonSize { .lg }

    fileprivate var height: CGFloat {
        switch self {
        case .lg: return 52
        case .md: return 44
        case .sm: return 36
        }
    }

    fileprivate var horizontalPadding: CGFloat {
        switch self {
        case .lg, .md: return 20
        case .sm:      return 12
        }
    }

    fileprivate var font: Font {
        switch self {
        case .lg, .md: return ChalNaTypography.headline
        case .sm:      return ChalNaTypography.label
        }
    }
}

public struct ChalNaButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public let variant: ChalNaButtonVariant
    public let size: ChalNaButtonSize
    public let fillWidth: Bool
    public let destructive: Bool

    public init(
        _ variant: ChalNaButtonVariant,
        size: ChalNaButtonSize = .lg,
        fillWidth: Bool = false,
        destructive: Bool = false
    ) {
        self.variant = variant
        self.size = size
        self.fillWidth = fillWidth
        self.destructive = destructive
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .tracking(ChalNaTypography.Tracking.title)
            .foregroundColor(foreground(pressed: configuration.isPressed))
            .frame(minHeight: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: fillWidth ? .infinity : nil)
            .background(background(pressed: configuration.isPressed))
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.sm, style: .continuous))
            .animation(ChalNaMotion.fast, value: configuration.isPressed)
    }

    /// 강조색. `destructive` 면 danger 계열로 바뀐다.
    private var tint: Color { destructive ? ChalNaColor.danger : ChalNaColor.accent }
    private var tintFill: Color { destructive ? ChalNaColor.danger : ChalNaColor.accentFill }

    private func foreground(pressed: Bool) -> Color {
        guard isEnabled else { return ChalNaColor.textTertiary }
        switch variant {
        case .primary:
            return ChalNaColor.onAccent
        case .secondary:
            return destructive ? ChalNaColor.danger : ChalNaColor.textPrimary
        case .ghost:
            // pressed 도 destructive 계열을 유지해야 한다. accentPressed 를 무조건 쓰면
            // 파괴적 ghost 버튼이 눌린 동안 red -> 보라로 바뀐다(ChalNaMotion.fast 로 실제 보임).
            return pressed
                ? (destructive ? ChalNaColor.dangerPressed : ChalNaColor.accentPressed)
                : tint
        }
    }

    @ViewBuilder
    private func background(pressed: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: ChalNaRadius.sm, style: .continuous)
        if !isEnabled {
            switch variant {
            case .primary:            shape.fill(ChalNaColor.surface)
            case .secondary:          shape.fill(ChalNaColor.surface)
            case .ghost:              shape.fill(Color.clear)
            }
        } else {
            switch variant {
            case .primary:   shape.fill(pressed ? tint : tintFill)
            case .secondary: shape.fill(pressed ? ChalNaColor.surfaceRaised : ChalNaColor.surface)
            case .ghost:     shape.fill(Color.clear)
            }
        }
    }

    @ViewBuilder
    private var border: some View {
        let shape = RoundedRectangle(cornerRadius: ChalNaRadius.sm, style: .continuous)
        switch variant {
        case .secondary:
            shape.strokeBorder(isEnabled ? ChalNaColor.border : ChalNaColor.border.opacity(0.5), lineWidth: 1)
        case .primary, .ghost:
            Color.clear
        }
    }
}

public extension ButtonStyle where Self == ChalNaButtonStyle {
    static var chalNaPrimary: ChalNaButtonStyle   { .init(.primary) }
    static var chalNaSecondary: ChalNaButtonStyle { .init(.secondary) }
    static var chalNaGhost: ChalNaButtonStyle     { .init(.ghost) }

    static func chalNa(
        _ variant: ChalNaButtonVariant,
        size: ChalNaButtonSize = .lg,
        fillWidth: Bool = false,
        destructive: Bool = false
    ) -> ChalNaButtonStyle {
        .init(variant, size: size, fillWidth: fillWidth, destructive: destructive)
    }

    // MARK: - Deprecated 별칭 (P5 삭제)
    @available(*, deprecated, renamed: "chalNaPrimary")
    static var chalNaFilled: ChalNaButtonStyle { .init(.primary) }
    @available(*, deprecated, renamed: "chalNaSecondary")
    static var chalNaOutlined: ChalNaButtonStyle { .init(.secondary) }
    @available(*, deprecated, renamed: "chalNaGhost")
    static var chalNaText: ChalNaButtonStyle { .init(.ghost) }
    @available(*, deprecated, renamed: "chalNaPrimary")
    static var chalNaCoral: ChalNaButtonStyle { .init(.primary) }
    @available(*, deprecated, renamed: "chalNaSecondary")
    static var chalNaOutline: ChalNaButtonStyle { .init(.secondary) }
}

#Preview {
    VStack(spacing: 12) {
        Button("저장하기") {}.buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
        Button("공유") {}.buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))
        Button("홈으로") {}.buttonStyle(.chalNaGhost)
        Button("필름 삭제") {}.buttonStyle(.chalNa(.ghost, destructive: true))
        Button("전부 삭제") {}.buttonStyle(.chalNa(.secondary, size: .md, destructive: true))
        Button("비활성") {}.buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true)).disabled(true)
        Button("작은 버튼") {}.buttonStyle(.chalNa(.secondary, size: .sm))
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ChalNaColor.bg)
}
```

- [ ] **Step 2: ChalNaBottomBar 작성**

Home · MediaPicker · Export · LabelEditor 네 화면이 같은 하단 크롬
(여백 + `bg` 배경 + 상단 hairline + 세이프에어리어 처리)을 각자 인라인으로
쓰게 되므로 컴포넌트로 뺀다.

`Modules/DesignSystem/Sources/Components/ChalNaBottomBar.swift`:

```swift
import SwiftUI

/// 화면 하단 고정 액션 영역. `safeAreaInset(edge: .bottom)` 에 넣어 쓴다.
///
/// 여백·배경·상단 hairline·세이프에어리어 처리를 한 곳에서 결정한다 —
/// Home CTA · MediaPicker 확인바 · Export CTA · LabelEditor 슬라이더가 공유한다.
public struct ChalNaBottomBar<Content: View>: View {
    private let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(ChalNaColor.bg.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(ChalNaColor.border)
                    .frame(height: 1)
            }
    }
}

#Preview {
    VStack {
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ChalNaColor.bg)
    .safeAreaInset(edge: .bottom) {
        ChalNaBottomBar {
            HStack(spacing: 10) {
                Button("취소") {}.buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))
                Button("다음") {}.buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
            }
        }
    }
}
```

> **P3·P4 화면 태스크(17·18·20·25)에서 하단 크롬을 직접 쓰는 대신 이것을 쓴다.**
> 각 태스크의 코드에 나오는
> `.padding(.horizontal, 20).padding(.top, …).padding(.bottom, …).background(ChalNaColor.bg.ignoresSafeArea(edges: .bottom)).overlay(alignment: .top) { Rectangle()… }`
> 체인을 `ChalNaBottomBar { … }` 로 감싸는 것으로 대체한다.
> LabelEditor(Task 25)는 여기에 `.padding(.bottom, keyboard.height)` 를 덧붙인다.

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:" | sort -u
```

Expected: 에러 없음 — 구 호출(`.chalNaCoral`, `.chalNa(.filled, size: .xl, ...)`)은 deprecated 별칭으로 흡수된다.
에러가 나면 해당 호출처를 새 이름으로 바꾼다.

- [ ] **Step 4: 프리뷰로 7종 상태 확인**

Xcode Canvas 로 `ChalNaButton.swift` 프리뷰를 본다.
확인할 것: primary 의 라벨이 읽히는지, secondary 의 border 가 보이는지,
destructive ghost 가 레드인지, disabled 가 `textTertiary` 로 죽는지.
`ChalNaBottomBar.swift` 프리뷰에서 하단바가 세이프에어리어까지 배경을 채우는지도 본다.

- [ ] **Step 5: 커밋**

```bash
git add Modules/DesignSystem/Sources/Components/ChalNaButton.swift \
        Modules/DesignSystem/Sources/Components/ChalNaBottomBar.swift
git commit -m "$(cat <<'EOF'
♻️ refactor(DesignSystem): 버튼 variant 5종 → 3종 + destructive · ChalNaBottomBar

- primary / secondary / ghost. 사이즈 lg 52 / md 44 / sm 36
- destructive: Bool 로 파괴적 액션 색 결정을 컴포넌트가 가져감
  (EditToolbar=Primary보라, FilmDetail=danger레드 로 갈렸던 불일치 제거)
- 구 variant·size·별칭은 deprecated 로 남겨 호출처 컴파일 유지, P5 삭제
- ChalNaBottomBar: Home·MediaPicker·Export·LabelEditor 가 공유하는
  하단 크롬(여백+배경+hairline+세이프에어리어)을 한 곳으로

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: ChalNaCard · ChalNaListRow · ChalNaSlider

**Files:**
- Create: `Modules/DesignSystem/Sources/Components/ChalNaCard.swift`
- Create: `Modules/DesignSystem/Sources/Components/ChalNaListRow.swift`
- Create: `Modules/DesignSystem/Sources/Components/ChalNaSlider.swift`

**Interfaces:**
- Consumes: `ChalNaColor`, `ChalNaTypography`, `ChalNaRadius.md`, `ChalNaIcon`, `ChalNaMotion.fast`.
- Produces: `ChalNaCard { content }` — `surface` + `md` 라디우스 + 1px `border`. `padding:` 파라미터(기본 16), `showsBorder:`(기본 true).
- Produces: `ChalNaListRow` — 5개 정적 생성자:
  ```swift
  ChalNaListRow.navigate(title:subtitle:value:enabled:action:)
  ChalNaListRow.toggle(title:subtitle:isOn:onChange:)
  ChalNaListRow.slider(title:value:range:step:enabled:trailingText:onChange:)
  ChalNaListRow.check(verbatimTitle:isChecked:action:)
  ```
  모두 `minHeight: 56` (고정 높이 아님 — Dynamic Type 확대 시 밀려 커진다).
- Produces: **verbatim 변형 1종** — `ChalNaListRow.toggleVerbatim(title:subtitle:isOn:onChange:)`.
  `title`/`subtitle` 을 `String` 으로 받는다.
  **필요한 이유:** `LabelKind.title`·`.subtitle` 은 `String(localized:)` 로 **이미 해석된 `String`** 이다
  (`Models/Sources/LabelSettings.swift:86,93` 확인됨). 이를 `LocalizedStringKey` 로 넘기면 이중 조회가 되어
  번역 테이블에서 다시 찾다가 키 자체를 반환하는, 조용히 잘못된 동작이 된다.
- Produces: `ChalNaListDivider` — 행 사이 구분선 (좌측 16pt 인셋).
- Produces: `ChalNaSlider(value: Binding<Double>, range: ClosedRange<Double> = 0...1, step: Double? = nil, onEditingChanged: @escaping (Bool) -> Void = { _ in })`.

- [ ] **Step 1: 구 Showcase 배경을 다크로 전환 (P1 검증 정확도 수정)**

`Modules/DesignSystem/Sources/Showcase/DesignSystemShowcaseView.swift:23` 이 아직
`.background(Color.white.ignoresSafeArea())` 다. 이 상태로는 **다크 컴포넌트를 흰 페이지 위에서
판정**하게 되어, 이 리디자인의 핵심 판단이 무효가 된다 — `ChalNaCard` 의 `surface #16151D` 는
흰 배경에서는 "검은 박스"로 보이지만 `bg #0B0A10` 위에서는 의도한 미묘한 단계로 보인다.
정반대의 결론이 나온다.

한 줄 교체:

```swift
        .chalNaScreen()
```

> **부수 효과(수용).** 구 Showcase 자체의 섹션 제목·스와치 라벨은 아직 `Gray.g900`(거의 검정)
> 이라 다크 배경에서 흐려진다. Task 12 가 전면 재작성으로 정리한다. 우리가 스크린샷으로 보는 것은
> **TEMP 섹션의 새 컴포넌트**이므로, 라벨 가독성보다 대비 판정의 유효성이 우선이다.
> 이 교체로 lint 흰색 카운트도 1 줄어든다(59 → 58).

- [ ] **Step 2: ChalNaCard 작성**

`Modules/DesignSystem/Sources/Components/ChalNaCard.swift`:

```swift
import SwiftUI

/// surface + 1px border 컨테이너.
/// 화면 8곳에 복붙돼 있던 `RoundedRectangle().fill().overlay(strokeBorder())` 조합을 대체한다.
public struct ChalNaCard<Content: View>: View {
    private let padding: CGFloat
    private let showsBorder: Bool
    private let content: () -> Content

    public init(
        padding: CGFloat = 16,
        showsBorder: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.showsBorder = showsBorder
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ChalNaRadius.md, style: .continuous)
                    .fill(ChalNaColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChalNaRadius.md, style: .continuous)
                    .strokeBorder(showsBorder ? ChalNaColor.border : Color.clear, lineWidth: 1)
            )
    }
}

#Preview {
    VStack(spacing: 12) {
        ChalNaCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("제주도, 우리의 봄").font(ChalNaTypography.headline)
                    .foregroundColor(ChalNaColor.textPrimary)
                Text(verbatim: "8 클립 · 01:40").font(ChalNaTypography.label)
                    .foregroundColor(ChalNaColor.textSecondary)
            }
        }
        ChalNaCard(padding: 0) {
            Text("padding 0 · 리스트 행 컨테이너")
                .font(ChalNaTypography.body)
                .foregroundColor(ChalNaColor.textPrimary)
                .padding(16)
        }
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ChalNaColor.bg)
}
```

- [ ] **Step 3: ChalNaListRow 작성**

`Modules/DesignSystem/Sources/Components/ChalNaListRow.swift`:

```swift
import SwiftUI

/// 설정류 리스트 행. Settings · LabelSettings · Language 가 각자 손으로 쓰던
/// 행 빌더 4개를 대체한다. 최소 높이·터치 영역·비활성 톤이 여기서만 결정된다.
///
/// **고정 높이가 아니라 `minHeight`** 다 — Dynamic Type 확대 시 행이 밀려 커진다.
///
/// 근거: `docs/superpowers/specs/2026-07-28-app-redesign-design.md` §5.3
public struct ChalNaListRow: View {

    private static let minHeight: CGFloat = 56

    private enum Kind {
        case navigate(value: String?, action: () -> Void)
        case toggle(isOn: Bool, onChange: (Bool) -> Void)
        case slider(value: Double, range: ClosedRange<Double>, step: Double,
                    trailingText: String?, onChange: (Double) -> Void)
        case check(isChecked: Bool, action: () -> Void)
    }

    private let titleText: Text
    /// LocalizedStringKey 변형과 verbatim 변형이 같은 저장소를 쓰도록 `Text` 로 보관한다.
    private let subtitleText: Text?
    private let enabled: Bool
    private let kind: Kind

    private init(titleText: Text, subtitleText: Text?, enabled: Bool, kind: Kind) {
        self.titleText = titleText
        self.subtitleText = subtitleText
        self.enabled = enabled
        self.kind = kind
    }

    // MARK: - Factories

    public static func navigate(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        value: String? = nil,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> ChalNaListRow {
        .init(titleText: Text(title),
              subtitleText: subtitle.map { Text($0) },
              enabled: enabled,
              kind: .navigate(value: value, action: action))
    }

    public static func toggle(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        isOn: Bool,
        onChange: @escaping (Bool) -> Void
    ) -> ChalNaListRow {
        .init(titleText: Text(title),
              subtitleText: subtitle.map { Text($0) },
              enabled: true,
              kind: .toggle(isOn: isOn, onChange: onChange))
    }

    // MARK: - verbatim 변형
    //
    // `LabelKind.title`/`.subtitle` 처럼 `String(localized:)` 로 **이미 해석된 String** 을 받는 경우용.
    // Task 15 의 라벨 토글 행이 유일한 사용처다.
    // 이를 LocalizedStringKey 로 넘기면 번역 테이블에서 다시 찾는 이중 조회가 되어
    // 조용히 잘못된 동작이 된다.

    public static func toggleVerbatim(
        title: String,
        subtitle: String? = nil,
        isOn: Bool,
        onChange: @escaping (Bool) -> Void
    ) -> ChalNaListRow {
        .init(titleText: Text(verbatim: title),
              subtitleText: subtitle.map { Text(verbatim: $0) },
              enabled: true,
              kind: .toggle(isOn: isOn, onChange: onChange))
    }

    public static func slider(
        title: LocalizedStringKey,
        value: Double,
        range: ClosedRange<Double> = 0...1,
        step: Double = 0.05,
        enabled: Bool = true,
        trailingText: String? = nil,
        onChange: @escaping (Double) -> Void
    ) -> ChalNaListRow {
        .init(titleText: Text(title), subtitleText: nil, enabled: enabled,
              kind: .slider(value: value, range: range, step: step,
                            trailingText: trailingText, onChange: onChange))
    }

    /// 언어 선택처럼 목록에서 하나를 고르는 행. 제목은 이미 해석된 문자열이라 verbatim.
    public static func check(
        verbatimTitle: String,
        isChecked: Bool,
        action: @escaping () -> Void
    ) -> ChalNaListRow {
        .init(titleText: Text(verbatim: verbatimTitle), subtitleText: nil, enabled: true,
              kind: .check(isChecked: isChecked, action: action))
    }

    // MARK: - Body

    public var body: some View {
        switch kind {
        case .navigate(_, let action):
            Button(action: action) { rowContent.contentShape(Rectangle()) }
                .buttonStyle(ListRowPressStyle())
                .disabled(!enabled)
        case .check(_, let action):
            Button(action: action) { rowContent.contentShape(Rectangle()) }
                .buttonStyle(ListRowPressStyle())
        case .toggle, .slider:
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                titleText
                    .font(ChalNaTypography.body)
                    .foregroundColor(enabled ? ChalNaColor.textPrimary : ChalNaColor.textTertiary)
                    .multilineTextAlignment(.leading)

                if let subtitleText {
                    subtitleText
                        .font(ChalNaTypography.label)
                        .foregroundColor(enabled ? ChalNaColor.textSecondary : ChalNaColor.textTertiary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailingContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: Self.minHeight)
    }

    @ViewBuilder
    private var trailingContent: some View {
        switch kind {
        case .navigate(let value, _):
            HStack(spacing: 6) {
                if let value {
                    Text(verbatim: value)
                        .font(ChalNaTypography.label)
                        .foregroundColor(enabled ? ChalNaColor.textSecondary : ChalNaColor.textTertiary)
                        .lineLimit(1)
                }
                ChalNaIcon(.chevronRight, size: 14, weight: .semibold)
                    .foregroundColor(enabled ? ChalNaColor.textSecondary : ChalNaColor.textTertiary)
            }

        case .toggle(let isOn, let onChange):
            Toggle("", isOn: Binding(get: { isOn }, set: onChange))
                .labelsHidden()
                .tint(ChalNaColor.accentFill)

        case .slider(let value, let range, let step, let trailingText, let onChange):
            HStack(spacing: 10) {
                ChalNaSlider(
                    value: Binding(get: { value }, set: onChange),
                    range: range,
                    step: step
                )
                .frame(minWidth: 120)
                if let trailingText {
                    Text(verbatim: trailingText)
                        .font(ChalNaTypography.mono())
                        .foregroundColor(enabled ? ChalNaColor.textSecondary : ChalNaColor.textTertiary)
                        .frame(minWidth: 44, alignment: .trailing)
                }
            }
            .disabled(!enabled)

        case .check(let isChecked, _):
            ChalNaIcon(.check, size: 16, weight: .semibold)
                .foregroundColor(ChalNaColor.accent)
                .opacity(isChecked ? 1 : 0)

        }
    }
}

private struct ListRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? ChalNaColor.surfaceRaised : Color.clear)
            .animation(ChalNaMotion.fast, value: configuration.isPressed)
    }
}

/// 리스트 행 사이 구분선. 좌측 16pt 인셋으로 텍스트 시작선과 맞춘다.
public struct ChalNaListDivider: View {
    public init() {}
    public var body: some View {
        Rectangle()
            .fill(ChalNaColor.border)
            .frame(height: 1)
            .padding(.leading, 16)
    }
}
```

- [ ] **Step 4: ChalNaSlider 작성 (ListRow.slider 가 이걸 쓴다)**

`Modules/DesignSystem/Sources/Components/ChalNaSlider.swift`:

```swift
import SwiftUI

/// 다크용 슬라이더. LabelSettings 투명도 · LabelEditor 라벨 크기에 쓴다.
///
/// 시스템 `Slider` 를 감싸고 tint 만 지정한다 — 트랙·노브를 직접 그리면
/// 접근성(조절 제스처·VoiceOver adjustable)을 다시 구현해야 하는데
/// 그만한 시각적 이득이 없다.
public struct ChalNaSlider: View {
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let step: Double?
    private let onEditingChanged: (Bool) -> Void

    public init(
        value: Binding<Double>,
        range: ClosedRange<Double> = 0...1,
        step: Double? = nil,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        Group {
            if let step {
                Slider(value: $value, in: range, step: step, onEditingChanged: onEditingChanged)
            } else {
                Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
            }
        }
        .tint(ChalNaColor.accentFill)
    }
}
```

> `ChalNaListRow.slider` 는 `step` 을 `Double`(non-optional)로 받아 그대로 넘긴다.
> 연속 조절이 필요한 곳(LabelEditor 라벨 크기)은 `ChalNaSlider` 를 직접 쓰고 `step: nil` 로 둔다.

- [ ] **Step 5: 빌드 확인 후 프리뷰 점검**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:" | sort -u
```

Expected: 에러 없음. Xcode Canvas 에서 `ChalNaCard` 프리뷰 확인.

- [ ] **Step 6: 커밋**

```bash
git add Modules/DesignSystem/Sources/Components/ChalNaCard.swift \
        Modules/DesignSystem/Sources/Components/ChalNaListRow.swift \
        Modules/DesignSystem/Sources/Components/ChalNaSlider.swift
git commit -m "$(cat <<'EOF'
✨ feat(DesignSystem): ChalNaCard · ChalNaListRow · ChalNaListDivider

- Card: 화면 8곳에 복붙돼 있던 RoundedRectangle+fill+strokeBorder 조합 대체
- ListRow: navigate/toggle/slider/check/plain 5종. Settings·LabelSettings·
  Language 가 각자 쓰던 행 빌더 4개를 흡수
- 고정 높이가 아닌 minHeight 56 — Dynamic Type 확대 시 행이 밀려 커진다

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: ChalNaTag · MediaThumb

**Files:**
- Create: `Modules/DesignSystem/Sources/Components/ChalNaTag.swift`
- Create: `Modules/DesignSystem/Sources/Components/MediaThumb.swift`
- Keep: `ChalNaChip.swift`, `ClipThumbCard.swift` — Task 26 에서 삭제.

**Interfaces:**
- Consumes: `ChalNaColor`, `ChalNaTypography.label`, `ChalNaRadius.pill/.xs`, `ChalNaIcon`, `ChalNaMotion`.
- Produces: `ChalNaTagVariant` — `.live`, `.video`, `.neutral`, `.accent`.
- Produces: `ChalNaTag(_ label: String, variant: ChalNaTagVariant = .neutral, icon: ChalNaIconKind? = nil)`.
- Produces: `MediaThumbState` — `.normal`, `.selected`, `.playing`, `.lifted`, `.ghost`, `.dimmed` (구 `ClipThumbState` 와 동일 6종).
- Produces:
  ```swift
  MediaThumb(state: MediaThumbState = .normal,
             size: CGSize? = nil,          // nil = 가용 폭 채우고 9:16
             aspect: CGFloat = 9.0/16.0,
             content: () -> Content)
  ```

- [ ] **Step 1: ChalNaTag 작성**

`Modules/DesignSystem/Sources/Components/ChalNaTag.swift`:

```swift
import SwiftUI

/// 다크용 태그. 반투명 흰 필 + 선택적 글리프.
/// 구 `ChalNaChip` 이 내부에서 SF Symbols 를 직접 쓰며 만든 이중 아이콘 계통을 없앤다.
public enum ChalNaTagVariant {
    /// Live Photo. danger 계열 dot — Live Photo 의 붉은 계열 관례.
    case live
    /// 일반 영상.
    case video
    /// 정보성 (클립 수 · 길이 등).
    case neutral
    /// 선택 상태 · 강조.
    case accent
}

public struct ChalNaTag: View {
    public let label: String
    public let variant: ChalNaTagVariant
    public let icon: ChalNaIconKind?

    public init(_ label: String, variant: ChalNaTagVariant = .neutral, icon: ChalNaIconKind? = nil) {
        self.label = label
        self.variant = variant
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: 5) {
            leadingGlyph
            Text(verbatim: label)
                .font(ChalNaTypography.label)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .foregroundColor(foreground)
        .background(Capsule(style: .continuous).fill(background))
        .overlay(Capsule(style: .continuous).strokeBorder(borderColor, lineWidth: 1))
    }

    @ViewBuilder
    private var leadingGlyph: some View {
        switch variant {
        case .live:
            Circle()
                .fill(ChalNaColor.danger)
                .frame(width: 7, height: 7)
        default:
            if let icon {
                ChalNaIcon(icon, size: 11, weight: .semibold)
            }
        }
    }

    private var background: Color {
        switch variant {
        case .live, .video, .neutral: return Color.white.opacity(0.10)
        case .accent:                 return ChalNaColor.accentFill.opacity(0.22)
        }
    }

    private var foreground: Color {
        switch variant {
        case .live, .video, .neutral: return ChalNaColor.textPrimary
        case .accent:                 return ChalNaColor.accent
        }
    }

    private var borderColor: Color {
        switch variant {
        case .accent: return ChalNaColor.accent.opacity(0.45)
        default:      return Color.white.opacity(0.08)
        }
    }
}

#Preview {
    HStack(spacing: 8) {
        ChalNaTag("LIVE", variant: .live)
        ChalNaTag("VIDEO", variant: .video, icon: .video)
        ChalNaTag("8 CLIPS", variant: .neutral)
        ChalNaTag("선택됨", variant: .accent, icon: .check)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ChalNaColor.bg)
}
```

> `Color.white.opacity(...)` 는 다크 위 반투명 오버레이를 만드는 유일한 방법이라
> `design-lint.sh` 의 흰색 규칙 예외에 이 파일을 추가해야 한다 — Step 4 에서 처리한다.

- [ ] **Step 2: MediaThumb 작성**

`Modules/DesignSystem/Sources/Components/MediaThumb.swift`:

```swift
import SwiftUI

/// 클립 썸네일 카드 상태. 6종 전부 유지 —
/// `lifted`·`ghost` 는 필름스트립 long-press 드래그가 쓴다.
public enum MediaThumbState: Hashable, Sendable {
    case normal
    case selected
    case playing
    case lifted
    /// 드래그 중 원래 자리(빈 슬롯).
    case ghost
    case dimmed
}

/// 그리드·필름스트립 공용 클립 썸네일.
///
/// 선택 링은 `accent` **바깥선 + 어두운 안쪽선 이중 스트로크**다 —
/// 밝은 썸네일 위에서도 링이 사라지지 않게 한다.
public struct MediaThumb<Content: View>: View {

    public var state: MediaThumbState
    /// `nil` 이면 가용 폭을 채우고 `aspect` 비율로 높이를 잡는다.
    public var size: CGSize?
    public var aspect: CGFloat
    public var content: () -> Content

    public init(
        state: MediaThumbState = .normal,
        size: CGSize? = nil,
        aspect: CGFloat = 9.0 / 16.0,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.state = state
        self.size = size
        self.aspect = aspect
        self.content = content
    }

    public var body: some View {
        if state == .ghost {
            ghostSlot
        } else {
            card
        }
    }

    private var ghostSlot: some View {
        RoundedRectangle(cornerRadius: ChalNaRadius.xs, style: .continuous)
            .strokeBorder(ChalNaColor.accent.opacity(0.7), style: .init(lineWidth: 2, dash: [4, 3]))
            .background(
                RoundedRectangle(cornerRadius: ChalNaRadius.xs, style: .continuous)
                    .fill(ChalNaColor.accent.opacity(0.10))
            )
            .modifier(ThumbFrame(size: size, aspect: aspect))
    }

    private var card: some View {
        content()
            .modifier(ThumbFrame(size: size, aspect: aspect))
            .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.xs, style: .continuous))
            .overlay(selectionRing)
            .scaleEffect(scale, anchor: .bottom)
            .offset(y: offsetY)
            .opacity(opacity)
            .animation(ChalNaMotion.fast, value: state)
    }

    /// accent 바깥선 + 어두운 안쪽선 — 밝은 썸네일에서도 링이 보이게.
    @ViewBuilder
    private var selectionRing: some View {
        switch state {
        case .selected, .playing:
            ZStack {
                RoundedRectangle(cornerRadius: ChalNaRadius.xs, style: .continuous)
                    .strokeBorder(ChalNaColor.canvas.opacity(0.55), lineWidth: 3)
                RoundedRectangle(cornerRadius: ChalNaRadius.xs, style: .continuous)
                    .strokeBorder(ChalNaColor.accent, lineWidth: 2)
            }
        default:
            EmptyView()
        }
    }

    private var scale: CGFloat {
        switch state {
        case .playing: return 1.06
        case .lifted:  return 1.12
        default:       return 1.0
        }
    }

    private var offsetY: CGFloat { state == .playing ? -3 : 0 }

    private var opacity: Double { state == .dimmed ? 0.5 : 1.0 }
}

/// 고정 크기 / 비율 채우기 두 모드를 한 곳에서 처리한다.
private struct ThumbFrame: ViewModifier {
    let size: CGSize?
    let aspect: CGFloat

    func body(content: Content) -> some View {
        if let size {
            content.frame(width: size.width, height: size.height)
        } else {
            // 컨테이너를 9:16 박스로 확정하고, 그 안의 이미지는 호출처가
            // scaledToFill 로 넘치게 한 뒤 .clipped() 로 크롭한다.
            //
            // contentMode 는 반드시 .fit 이다. .fill 은 "제안된 공간을 채우도록" 크기를
            // 정하는데, LazyVGrid 셀의 높이 제안은 유연하므로 결과가 불확정해진다.
            // .fit 은 제안 안에 맞추므로 폭 = 열 폭, 높이 = 폭 × 16/9 로 확정된다.
            content
                .frame(maxWidth: .infinity)
                .aspectRatio(aspect, contentMode: .fit)
                .clipped()
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(alignment: .bottom, spacing: 12) {
            MediaThumb(size: CGSize(width: 46, height: 80)) {
                LinearGradient(colors: [.blue.opacity(0.6), .cyan], startPoint: .top, endPoint: .bottom)
            }
            MediaThumb(state: .selected, size: CGSize(width: 46, height: 80)) {
                LinearGradient(colors: [.white, .yellow], startPoint: .top, endPoint: .bottom)
            }
            MediaThumb(state: .playing, size: CGSize(width: 46, height: 80)) {
                LinearGradient(colors: [.orange, .pink], startPoint: .top, endPoint: .bottom)
            }
            MediaThumb(state: .lifted, size: CGSize(width: 46, height: 80)) {
                LinearGradient(colors: [.purple, .pink], startPoint: .top, endPoint: .bottom)
            }
            MediaThumb(state: .ghost, size: CGSize(width: 46, height: 80)) { Color.clear }
            MediaThumb(state: .dimmed, size: CGSize(width: 46, height: 80)) {
                LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
            }
        }

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(0..<3, id: \.self) { i in
                MediaThumb(state: i == 1 ? .selected : .normal) {
                    LinearGradient(colors: [.gray, .black], startPoint: .top, endPoint: .bottom)
                }
            }
        }
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ChalNaColor.bg)
}
```

- [ ] **Step 3: 그리드 모드 기하 + 밝은 썸네일 선택 링 확인**

`MediaThumb` 은 두 모드가 있고 **그리드 모드(`size: nil`)의 기하가 이 컴포넌트의 유일한 위험 지점**이다.
TEMP 섹션에 반드시 3열 `LazyVGrid` 안의 `MediaThumb(state:)`(size 미지정)을 넣고 스크린샷으로 확인한다.

확인할 것:
1. **셀이 9:16 세로 비율인가.** 정사각형이거나 화면을 벗어나거나 높이가 0 이면 `contentMode` 문제다.
   계획은 `.fit` 으로 지정돼 있다(제안 안에 맞춤 → 폭 = 열 폭, 높이 = 폭 × 16/9).
   만약 `.fit` 으로 셀이 이상하게 나오면 `.fill` 을 시도하고, **어느 쪽이 맞았는지 리포트에 적는다** —
   나중에 이 컴포넌트를 쓰는 Task 17(홈 2열 포스터 그리드)·Task 18(미디어 3열 그리드)이
   같은 판단을 반복하지 않게 하려는 것이다.
2. 3열 간격이 균일하고 셀 폭이 열 폭을 꽉 채우는가.
3. **밝은 썸네일에서도 선택 링이 보이는가** — 이게 이중 스트로크의 존재 이유다.
   흰→노랑 그라디언트 같은 아주 밝은 콘텐츠로 테스트한다.

Xcode Canvas 에서 `MediaThumb.swift` 프리뷰를 본다.
확인할 것: **두 번째 카드(흰→노랑 그라디언트, 아주 밝음)에서도 accent 링이 보이는지.**
안 보이면 이중 스트로크의 안쪽선 두께/투명도를 올린다 — 이게 이 컴포넌트의 존재 이유다.

- [ ] **Step 4: design-lint 예외 경로 추가**

`scripts/design-lint.sh` 의 "흰색 하드코딩" `check` 호출에 다음 두 줄을 예외로 추가한다:

```bash
  'DesignSystem/Sources/Components/ChalNaTag.swift' \
  'DesignSystem/Sources/Components/MediaThumb.swift' \
```

이유: 다크 위 반투명 오버레이(`Color.white.opacity(...)`)는 토큰으로 표현할 수 없는
합성 연산이다. 두 파일에 국한된다.

- [ ] **Step 5: 빌드 · lint 확인 후 커밋**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:" | sort -u
./scripts/design-lint.sh   # 아직 실패해도 정상 (화면 미마이그레이션)

git add Modules/DesignSystem/Sources/Components/ChalNaTag.swift \
        Modules/DesignSystem/Sources/Components/MediaThumb.swift \
        scripts/design-lint.sh
git commit -m "$(cat <<'EOF'
✨ feat(DesignSystem): ChalNaTag · MediaThumb

- Tag: 다크용 반투명 필 + 4종(live/video/neutral/accent).
  Chip 내부의 SF Symbols 직접 사용을 없애 아이콘 계통을 하나로
- MediaThumb: 6상태 유지(lifted/ghost 는 필름스트립 드래그가 쓴다).
  선택 링을 accent 바깥선 + 어두운 안쪽선 이중 스트로크로 바꿔
  밝은 썸네일에서도 링이 사라지지 않게 함
- 고정 크기 / 비율 채우기 두 모드 지원 (필름스트립 vs 그리드)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: ChalNaCanvas — 9:16 미디어 캔버스 통합

**Files:**
- Create: `Modules/DesignSystem/Sources/Components/ChalNaCanvas.swift`
- Modify: `Modules/TimelineFeature/Sources/Components/LabelBoxGeometry.swift` (DesignSystem 으로 위임)
- Create: `Modules/DesignSystem/Tests/ChalNaCanvasGeometryTests.swift`
- Modify: `scripts/design-lint.sh` (규칙 4 회색조 사각지대 차단)

**Interfaces:**
- Consumes: `ChalNaColor.canvas`, `ChalNaRadius.md`.
- Produces: `ChalNaCanvasGeometry.fittedBox(aspect: CGFloat, in available: CGSize) -> CGSize` (public static).
- Produces:
  ```swift
  ChalNaCanvas(aspect: CGFloat = 9.0/16.0,
               cornerRadius: CGFloat = ChalNaRadius.md,
               content: (CGSize) -> Content,   // 인자 = 확정된 box 크기
               overlay: (CGSize) -> Overlay)
  ```
  `overlay` 는 clip 밖에 그려진다(HUD·배지가 라운딩에 잘리지 않게).
- `LabelBoxGeometry.fittedBox` 는 시그니처 그대로 유지하고 내부에서 `ChalNaCanvasGeometry` 를 호출한다 — 기존 호출처 3곳 무변경.

- [ ] **Step 1: lint 규칙 4 의 회색조 사각지대 차단**

Task 9 에서 `Color(white: 0.97)` 이 Showcase 에 들어왔고 **lint 가 이를 보지 못했다**
(`DesignSystemShowcaseView.swift:404,424`). 사용 자체는 정당하다 — DEBUG 전용 데모
그라디언트로, 예외로 둔 `ThumbnailPreset` 콘텐츠 그라디언트와 같은 성격이다.
문제는 규칙이다: **`Color.white` 를 `Color(white: 1.0)` 으로 바꾸는 것만으로 규칙을
우회할 수 있으면 Task 26 게이트가 무의미해진다.** (Task 4 리뷰가 이 사각지대를 예고했다.)

`scripts/design-lint.sh` 의 규칙 4 패턴을 교체한다:

```bash
check "흰색 하드코딩" '(Color\.white|\.white\b|Color\(white:|UIColor\(white:)' \
```

그리고 그 위 주석에 한 줄 추가:

```bash
#    회색조 이니셜라이저 형태(Color(white:) / UIColor(white:))도 반드시 포함한다.
#    이게 빠지면 Color.white 를 Color(white: 1.0) 으로 바꾸는 것만으로 규칙을 우회할 수 있다.
```

**그리고 같은 스텝에서 그 2건을 토큰으로 교체한다.** Task 9 리뷰가 지적한 대로,
`Color(white: 0.97)` 자리에는 **이미 존재하는 근사 흰색 토큰 `ChalNaColor.textPrimary`(#F5F4F7)** 를
쓰면 된다 — 시각적으로 동일한 "아주 밝은 콘텐츠" 테스트가 되고, lint 노출도 0, 새 리터럴도 0,
예외도 필요 없다.

`DesignSystemShowcaseView.swift:404,424` 두 곳:

```swift
                        LinearGradient(colors: [ChalNaColor.textPrimary, .yellow],
                                       startPoint: .top, endPoint: .bottom)
```

**기대 결과: 흰색 카운트가 58 로 유지된다.** 패턴을 넓혀도(숨은 2건이 드러남) 같은 스텝에서
그 2건을 토큰으로 바꾸므로 순증이 0 이다. 사각지대는 닫히고 수치는 정직해진다.
Task 26 기준선은 여전히 "모든 규칙 0" 이다.

- [ ] **Step 2: ChalNaCanvas 작성**

`Modules/DesignSystem/Sources/Components/ChalNaCanvas.swift`:

```swift
import SwiftUI

/// 9:16 미디어 캔버스 기하.
///
/// Timeline 프리뷰 · ClipAdjust · LabelEditor 세 곳이 거의 똑같이 재구현하던
/// aspect-fit 계산을 한 곳으로 모은다. WYSIWYG(프리뷰 = 출력) 의 토대다.
public enum ChalNaCanvasGeometry {
    /// 주어진 비율을 가용 영역 안에 aspect-fit 시킨 박스 크기.
    public static func fittedBox(aspect: CGFloat, in available: CGSize) -> CGSize {
        guard available.width > 0, available.height > 0, aspect > 0 else { return .zero }
        let byWidth = CGSize(width: available.width, height: available.width / aspect)
        if byWidth.height <= available.height { return byWidth }
        return CGSize(width: available.height * aspect, height: available.height)
    }
}

/// 영상·사진을 출력 비율(기본 9:16)로 담는 캔버스 컨테이너.
///
/// 배경은 `ChalNaColor.canvas`(진짜 검정). `bg` 와 거의 같은 밝기라
/// 화면 위에 '검은 섬'으로 뜨지 않는다.
///
/// `content` 와 `overlay` 는 확정된 박스 크기를 인자로 받는다 —
/// 라벨 좌표 정규화가 이 크기를 renderSize 로 삼기 때문이다.
public struct ChalNaCanvas<Content: View, Overlay: View>: View {
    private let aspect: CGFloat
    private let cornerRadius: CGFloat
    private let content: (CGSize) -> Content
    private let overlay: (CGSize) -> Overlay

    public init(
        aspect: CGFloat = 9.0 / 16.0,
        cornerRadius: CGFloat = ChalNaRadius.md,
        @ViewBuilder content: @escaping (CGSize) -> Content,
        @ViewBuilder overlay: @escaping (CGSize) -> Overlay
    ) {
        self.aspect = aspect
        self.cornerRadius = cornerRadius
        self.content = content
        self.overlay = overlay
    }

    public init(
        aspect: CGFloat = 9.0 / 16.0,
        cornerRadius: CGFloat = ChalNaRadius.md,
        @ViewBuilder content: @escaping (CGSize) -> Content
    ) where Overlay == EmptyView {
        self.init(aspect: aspect, cornerRadius: cornerRadius, content: content) { _ in EmptyView() }
    }

    public var body: some View {
        GeometryReader { proxy in
            let box = ChalNaCanvasGeometry.fittedBox(aspect: aspect, in: proxy.size)
            ZStack {
                ChalNaColor.canvas
                content(box)
            }
            .frame(width: box.width, height: box.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay { overlay(box) }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ChalNaCanvas { box in
            LinearGradient(colors: [.indigo, .black], startPoint: .top, endPoint: .bottom)
                .frame(width: box.width, height: box.height)
        } overlay: { _ in
            ChalNaTag("3 / 8", variant: .neutral)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(12)
        }
        .frame(height: 320)
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ChalNaColor.bg)
}
```

- [ ] **Step 3: LabelBoxGeometry 를 위임으로 변경**

`Modules/TimelineFeature/Sources/Components/LabelBoxGeometry.swift` 전체를 교체한다:

```swift
import CoreGraphics
import DesignSystem

/// 라벨 위치 정규화에 쓰는 "클립 표시 박스" 기하.
/// 실제 계산은 `ChalNaCanvasGeometry` 가 단일 출처로 갖는다 —
/// 에디터·미리보기·합성이 같은 규칙을 공유해 WYSIWYG 가 어긋나지 않게 한다.
enum LabelBoxGeometry {
    static func fittedBox(aspect: CGFloat, in available: CGSize) -> CGSize {
        ChalNaCanvasGeometry.fittedBox(aspect: aspect, in: available)
    }
}
```

- [ ] **Step 4: `fittedBox` 기하 테스트 작성 (현재 커버리지 0)**

**사전 확인 결과 `fittedBox` 를 검사하는 테스트가 하나도 없다.** 기존 TimelineFeature 테스트는
`LabelAnchorMathTests`(박스 크기를 *입력으로 받는다*) · `TimelinePlaybackTests` ·
`TimelineReorderTests` 뿐이다. 따라서 "TimelineFeature 테스트가 통과하니 기하가 안 바뀌었다"는
주장은 성립하지 않는다. 프리뷰 · 크롭 조정 · 라벨 에디터 **세 화면의 WYSIWYG 가 이 함수에
걸려 있으므로** 잠금을 만든다.

`Modules/DesignSystem/Tests/ChalNaCanvasGeometryTests.swift`:

```swift
import Testing
import CoreGraphics
import DesignSystem

/// 9:16 캔버스 aspect-fit 기하를 잠근다.
/// 프리뷰·크롭 조정·라벨 에디터가 같은 박스를 renderSize 로 삼으므로,
/// 이 값이 바뀌면 세 화면의 WYSIWYG 가 동시에 어긋난다.
struct ChalNaCanvasGeometryTests {

    private let aspect: CGFloat = 9.0 / 16.0

    @Test func testWideAvailableIsConstrainedByHeight() {
        let box = ChalNaCanvasGeometry.fittedBox(aspect: aspect,
                                                in: CGSize(width: 1000, height: 320))
        #expect(box.height == 320)
        #expect(abs(box.width - 320 * 9 / 16) < 0.001)
    }

    @Test func testTallAvailableIsConstrainedByWidth() {
        let box = ChalNaCanvasGeometry.fittedBox(aspect: aspect,
                                                in: CGSize(width: 180, height: 4000))
        #expect(box.width == 180)
        #expect(abs(box.height - 180 * 16 / 9) < 0.001)
    }

    @Test func testExactRatioReturnsAvailableUnchanged() {
        let box = ChalNaCanvasGeometry.fittedBox(aspect: aspect,
                                                in: CGSize(width: 180, height: 320))
        #expect(abs(box.width - 180) < 0.001)
        #expect(abs(box.height - 320) < 0.001)
    }

    /// aspect-fit 의 정의: 어느 축도 가용 영역을 넘지 않는다. 실기 크기로 확인.
    @Test func testResultNeverExceedsAvailable() {
        for available in [CGSize(width: 393, height: 852),
                          CGSize(width: 375, height: 667),
                          CGSize(width: 440, height: 956),
                          CGSize(width: 100, height: 100)] {
            let box = ChalNaCanvasGeometry.fittedBox(aspect: aspect, in: available)
            #expect(box.width <= available.width + 0.001)
            #expect(box.height <= available.height + 0.001)
        }
    }

    @Test func testDegenerateInputsReturnZero() {
        #expect(ChalNaCanvasGeometry.fittedBox(aspect: aspect, in: .zero) == .zero)
        #expect(ChalNaCanvasGeometry.fittedBox(aspect: aspect,
                                              in: CGSize(width: 100, height: 0)) == .zero)
        #expect(ChalNaCanvasGeometry.fittedBox(aspect: 0,
                                              in: CGSize(width: 100, height: 100)) == .zero)
    }

    /// 위임 전 `LabelBoxGeometry` 산식을 재현해 값이 바뀌지 않았음을 직접 대조한다.
    /// TimelineFeature 는 별 모듈이라 여기서 그 타입을 호출할 수 없으므로 산식을 복제한다.
    @Test func testMatchesPreDelegationFormula() {
        func original(aspect: CGFloat, in available: CGSize) -> CGSize {
            guard available.width > 0, available.height > 0 else { return .zero }
            let byWidth = CGSize(width: available.width, height: available.width / aspect)
            if byWidth.height <= available.height { return byWidth }
            return CGSize(width: available.height * aspect, height: available.height)
        }
        for available in [CGSize(width: 393, height: 500),
                          CGSize(width: 393, height: 852),
                          CGSize(width: 200, height: 100)] {
            let new = ChalNaCanvasGeometry.fittedBox(aspect: aspect, in: available)
            let old = original(aspect: aspect, in: available)
            #expect(abs(new.width - old.width) < 0.001)
            #expect(abs(new.height - old.height) < 0.001)
        }
    }
}
```

- [ ] **Step 5: 빌드 + 테스트 확인**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme DesignSystem \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
xcodebuild -workspace ChalNa.xcworkspace -scheme TimelineFeature \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

Expected: DesignSystem **22개**(기존 16 + 신규 6) PASS, TimelineFeature 기존 테스트 전부 PASS.
TimelineFeature 쪽은 보조 증거일 뿐이고 **실제 잠금은 위 6개 테스트**다.

- [ ] **Step 6: 커밋**

```bash
git add Modules/DesignSystem/Sources/Components/ChalNaCanvas.swift \
        Modules/TimelineFeature/Sources/Components/LabelBoxGeometry.swift
git commit -m "$(cat <<'EOF'
✨ feat(DesignSystem): ChalNaCanvas — 9:16 미디어 캔버스 통합

Timeline 프리뷰 · ClipAdjust · LabelEditor 가 각각 재구현하던
aspect-fit + Color.black + clipShape 조합을 하나로 모음.

- ChalNaCanvasGeometry.fittedBox 가 기하 단일 출처
- LabelBoxGeometry 는 시그니처를 유지한 채 여기로 위임 (호출처 무변경)
- content/overlay 가 확정된 box 크기를 받아 라벨 좌표 정규화의 renderSize 로 씀
- overlay 는 clip 밖에 그려 HUD·배지가 라운딩에 잘리지 않게

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: 상태 컴포넌트 5종

**Files:**
- Create: `Modules/DesignSystem/Sources/Components/ChalNaProgressBar.swift`
- Create: `Modules/DesignSystem/Sources/Components/ChalNaEmptyState.swift`
- Create: `Modules/DesignSystem/Sources/Components/ChalNaNotice.swift`
- Create: `Modules/DesignSystem/Sources/Components/ChalNaToast.swift`
- Create: `Modules/DesignSystem/Sources/Components/ChalNaBlockingOverlay.swift`

**Interfaces:**
- Consumes: `ChalNaColor`, `ChalNaTypography`, `ChalNaRadius`, `ChalNaShadow.floating`, `ChalNaIcon`, `ChalNaMotion.standard`, `ChalNaCard` (Task 8), `ChalNaButton` (Task 7).
- Produces: `ChalNaProgressBar(progress: Double, tint: Color = ChalNaColor.accent, height: CGFloat = 5)`.
- Produces: `ChalNaEmptyState(icon: ChalNaIconKind, title: LocalizedStringKey, message: LocalizedStringKey, actionTitle: LocalizedStringKey? = nil, action: (() -> Void)? = nil)`.
- Produces: `ChalNaNotice(icon: ChalNaIconKind = .film, title: LocalizedStringKey, message: LocalizedStringKey)`.
- Produces: `View.chalNaToast(message: String?, onDismiss: () -> Void)` 모디파이어 + `ChalNaToast(message: String)`.
- Produces: `ChalNaBlockingOverlay(title: LocalizedStringKey, detail: LocalizedStringKey? = nil, progressText: String? = nil, accessibilityLabel: LocalizedStringKey)`.

- [ ] **Step 1: ChalNaProgressBar 작성**

```swift
// Modules/DesignSystem/Sources/Components/ChalNaProgressBar.swift
import SwiftUI

/// 진행률 바. Export 내보내기 진행률에 쓴다.
public struct ChalNaProgressBar: View {
    public let progress: Double
    public let tint: Color
    public let height: CGFloat

    public init(progress: Double, tint: Color = ChalNaColor.accent, height: CGFloat = 5) {
        self.progress = progress
        self.tint = tint
        self.height = height
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(ChalNaColor.border)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, proxy.size.width * clamped))
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("진행률")
        .accessibilityValue(Text(verbatim: "\(Int(clamped * 100))%"))
    }

    private var clamped: Double { max(0, min(1, progress)) }
}

#Preview {
    VStack(spacing: 20) {
        ChalNaProgressBar(progress: 0.0)
        ChalNaProgressBar(progress: 0.62)
        ChalNaProgressBar(progress: 1.0, tint: ChalNaColor.success)
        ChalNaProgressBar(progress: 0.4, tint: ChalNaColor.danger)
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ChalNaColor.bg)
}
```

- [ ] **Step 2: ChalNaEmptyState 작성**

```swift
// Modules/DesignSystem/Sources/Components/ChalNaEmptyState.swift
import SwiftUI

/// 빈 상태. Home 라이브러리 비었을 때 · FilmDetail 필름 없을 때.
public struct ChalNaEmptyState: View {
    private let icon: ChalNaIconKind
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?

    public init(
        icon: ChalNaIconKind = .film,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: 12) {
            ChalNaIcon(icon, size: 36, weight: .light)
                .foregroundColor(ChalNaColor.textTertiary)

            Text(title)
                .font(ChalNaTypography.title)
                .foregroundColor(ChalNaColor.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(ChalNaTypography.body)
                .foregroundColor(ChalNaColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.chalNa(.secondary, size: .md))
                    .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ChalNaEmptyState(
        title: "아직 만든 필름이 없어요",
        message: "Live Photo와 짧은 영상을 촬영일 순서로 이어 붙여\n한 편의 필름을 만들어 보세요.",
        actionTitle: "첫 Vlog 시작하기"
    ) {}
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ChalNaColor.bg)
}
```

- [ ] **Step 3: ChalNaNotice 작성**

```swift
// Modules/DesignSystem/Sources/Components/ChalNaNotice.swift
import SwiftUI

/// 정보 안내 카드. FilmDetail 의 "영상 파일을 찾을 수 없어요" 등.
public struct ChalNaNotice: View {
    private let icon: ChalNaIconKind
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey

    public init(
        icon: ChalNaIconKind = .film,
        title: LocalizedStringKey,
        message: LocalizedStringKey
    ) {
        self.icon = icon
        self.title = title
        self.message = message
    }

    public var body: some View {
        ChalNaCard {
            HStack(alignment: .top, spacing: 12) {
                ChalNaIcon(icon, size: 20)
                    .foregroundColor(ChalNaColor.textSecondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(ChalNaTypography.headline)
                        .foregroundColor(ChalNaColor.textPrimary)
                    Text(message)
                        .font(ChalNaTypography.label)
                        .foregroundColor(ChalNaColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ChalNaNotice(
        title: "영상 파일을 찾을 수 없어요",
        message: "앱을 다시 설치하셨거나 파일이 삭제되었어요. 재생과 공유는 불가능하고, 라이브러리에서 항목을 정리할 수 있어요."
    )
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ChalNaColor.bg)
}
```

- [ ] **Step 4: ChalNaToast 작성**

```swift
// Modules/DesignSystem/Sources/Components/ChalNaToast.swift
import SwiftUI

/// 하단 토스트. 2.2초 후 자동으로 사라진다.
public struct ChalNaToast: View {
    private let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        Text(verbatim: message)
            .font(ChalNaTypography.label)
            .foregroundColor(ChalNaColor.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(ChalNaColor.surfaceRaised))
            .overlay(Capsule().strokeBorder(ChalNaColor.border, lineWidth: 1))
            .chalNaShadow(ChalNaShadow.floating)
    }
}

public extension View {
    /// `message` 가 nil 이 아니면 하단에 토스트를 띄우고 2.2초 뒤 `onDismiss` 를 부른다.
    func chalNaToast(message: String?, onDismiss: @escaping () -> Void) -> some View {
        overlay(alignment: .bottom) {
            if let message {
                ChalNaToast(message: message)
                    .padding(.bottom, 64)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .task(id: message) {
                        try? await Task.sleep(nanoseconds: 2_200_000_000)
                        onDismiss()
                    }
            }
        }
        .animation(ChalNaMotion.standard, value: message)
    }
}

#Preview {
    Color.clear
        .chalNaToast(message: "사진 보관함에 저장했어요") {}
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChalNaColor.bg)
}
```

- [ ] **Step 5: ChalNaBlockingOverlay 작성**

```swift
// Modules/DesignSystem/Sources/Components/ChalNaBlockingOverlay.swift
import SwiftUI

/// 작업 중 하단 화면 조작을 막는 전체 오버레이.
/// MediaPicker 의 Live Photo·영상 추출 진행 표시에 쓴다.
public struct ChalNaBlockingOverlay: View {
    private let title: LocalizedStringKey
    private let detail: LocalizedStringKey?
    /// "05 / 12" 같은 숫자 진행 표시. 숫자 전용이라 mono 를 쓴다.
    private let progressText: String?
    private let a11yLabel: LocalizedStringKey

    public init(
        title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        progressText: String? = nil,
        accessibilityLabel: LocalizedStringKey
    ) {
        self.title = title
        self.detail = detail
        self.progressText = progressText
        self.a11yLabel = accessibilityLabel
    }

    public var body: some View {
        ZStack {
            ChalNaColor.scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { }   // 하단 화면 탭 차단

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(ChalNaColor.accent)

                VStack(spacing: 6) {
                    Text(title)
                        .font(ChalNaTypography.headline)
                        .foregroundColor(ChalNaColor.textPrimary)

                    if let progressText {
                        Text(verbatim: progressText)
                            .font(ChalNaTypography.mono(.title2, weight: .bold))
                            .foregroundColor(ChalNaColor.accent)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }

                    if let detail {
                        Text(detail)
                            .font(ChalNaTypography.caption)
                            .foregroundColor(ChalNaColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(minWidth: 220)
            .background(
                RoundedRectangle(cornerRadius: ChalNaRadius.lg, style: .continuous)
                    .fill(ChalNaColor.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChalNaRadius.lg, style: .continuous)
                    .strokeBorder(ChalNaColor.border, lineWidth: 1)
            )
            .chalNaShadow(ChalNaShadow.floating)
            .padding(.horizontal, 48)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel(a11yLabel)
    }
}

#Preview {
    Color.gray
        .overlay {
            ChalNaBlockingOverlay(
                title: "사진을 불러오는 중",
                detail: "Live Photo와 영상을 정성껏 추출하고 있어요",
                progressText: "05 / 12",
                accessibilityLabel: "사진을 불러오는 중이에요"
            )
        }
        .ignoresSafeArea()
}
```

- [ ] **Step 6: 빌드 확인 후 커밋**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:" | sort -u

git add Modules/DesignSystem/Sources/Components/ChalNaProgressBar.swift \
        Modules/DesignSystem/Sources/Components/ChalNaEmptyState.swift \
        Modules/DesignSystem/Sources/Components/ChalNaNotice.swift \
        Modules/DesignSystem/Sources/Components/ChalNaToast.swift \
        Modules/DesignSystem/Sources/Components/ChalNaBlockingOverlay.swift
git commit -m "$(cat <<'EOF'
✨ feat(DesignSystem): 상태 컴포넌트 5종

ProgressBar · EmptyState · Notice · Toast · BlockingOverlay.
화면에 인라인으로 박혀 있던 것들을 꺼내 재사용 가능하게 함.

- Toast 는 View.chalNaToast(message:onDismiss:) 모디파이어로 노출, 2.2초 자동 해제
- BlockingOverlay 의 진행 카운트만 mono (순수 숫자)
- 기존 접근성 처리(isModal, 결합 라벨) 승계

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: 입력 컴포넌트 2종 + Showcase 재작성

**Files:**
- Modify: `Modules/DesignSystem/Sources/Components/ChalNaTextField.swift`
- Create: `Modules/DesignSystem/Sources/Components/ChalNaTextArea.swift`
- Modify: `Modules/DesignSystem/Sources/Showcase/DesignSystemShowcaseView.swift` (전체 재작성)
- Delete: `Modules/DesignSystem/Sources/Components/ChalNaBottomSheet.swift` (실사용 0곳)

**Interfaces:**
- Consumes: 앞선 모든 컴포넌트.
- Produces: `ChalNaTextField(label:placeholder:helper:errorText:text:)` — 시그니처 유지, 다크 재스타일.
- Produces: `ChalNaTextArea(placeholder: String, minHeight: CGFloat = 180, text: Binding<String>)`.
- Produces: `DesignSystemShowcaseView()` — 토큰·컴포넌트 전수 확인 화면.

- [ ] **Step 1: `ChalNaCard` 콘텐츠 clip 추가 (Task 8 리뷰 지적)**

`ChalNaCard` 가 `content()` 를 카드 모양으로 clip 하지 않는다. `ChalNaListRow` 의 press
하이라이트(`ListRowPressStyle`)는 사각 `Rectangle` 배경이라, 정식 패턴인
`ChalNaCard(padding: 0) { rows }` 에서 **첫/마지막 행을 누르는 동안 사각 하이라이트가
카드의 `md`(14pt) 둥근 모서리 밖으로 삐져나온다.**

`Modules/DesignSystem/Sources/Components/ChalNaCard.swift` 의 `body` 에서 `content()` 다음,
`.padding(padding)` **앞**에 한 줄 추가:

```swift
            .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.md, style: .continuous))
```

> 순서가 중요하다. `padding` 뒤에 붙이면 패딩까지 clip 되어 내용이 잘린다.
> `content()` 직후에 붙여 **행 배경만** 카드 모양으로 가둔다.
>
> **왜 Task 12 인가.** 순수 코스메틱(150ms 프레스 중 14pt 영역)이라 Task 8 에 fix 라운드를
> 태울 값은 없지만, P2 화면 4개(Settings · Language · LabelSettings · LabelPosition)가 전부
> `ChalNaCard(padding: 0) { rows }` 패턴을 쓴다. Task 12 는 P2 보다 먼저 실행되므로
> 여기서 고치면 P2 스크린샷 4번에서 같은 지적이 반복되지 않는다.

- [ ] **Step 2: DS 프리미티브 견고성 2건 (Task 11 리뷰 지적)**

둘 다 한 줄이고, **화면 코드가 아니라 디자인 시스템 프리미티브**라서 지금 고친다 —
방치하면 앞으로 모든 호출자가 물려받는다.

**(a) `ChalNaToast` 의 dismiss 경쟁 상태.** `View.chalNaToast` 의 `.task(id: message)` 안에서
`try? await Task.sleep(...)` 이 `CancellationError` 를 삼키기 때문에, 메시지가 교체되며 이전
task 가 취소돼도 그 task 가 곧바로 `onDismiss()` 를 실행한다. 2.2초 안에 다른 토스트가 뜨면
**새 토스트가 0초 만에 사라진다.** `onDismiss()` 앞에 취소 확인을 넣는다:

```swift
                    .task(id: message) {
                        try? await Task.sleep(nanoseconds: 2_200_000_000)
                        guard !Task.isCancelled else { return }
                        onDismiss()
                    }
```

> 이 패턴은 `ExportView.swift:80-83` 에서 그대로 추출된 것이라 Task 11 의 잘못이 아니지만,
> Task 20 이 ExportView 를 마이그레이션할 때 이 컴포넌트를 쓰므로 그전에 고쳐 둔다.

**(b) `ChalNaProgressBar` 의 NaN.** `max(0, min(1, progress))` 는 `progress` 가 `.nan` 일 때
**1.0 을 반환**한다(NaN 비교가 항상 false 라 `min(1, .nan)` 이 `1` 을 돌려준다). 즉 NaN 진행률이
"가득 찬 바"로 그려진다. 현재 호출부(`AVAssetExportSession.progress`)는 나눗셈이 없어 무해하지만
범용 프리미티브로서 방어가 없다:

```swift
    private var clamped: Double {
        guard progress.isFinite else { return 0 }
        return max(0, min(1, progress))
    }
```

- [ ] **Step 3: ChalNaTextField 다크 재스타일**

`Modules/DesignSystem/Sources/Components/ChalNaTextField.swift` 에서 다음 값만 교체한다
(시그니처·구조는 유지):

| 기존 | 변경 |
|---|---|
| `ChalNaTypography.krBody(Size.small, weight: .medium)` (label) | `ChalNaTypography.label` |
| `ChalNaTypography.krBody(Size.body)` (입력 텍스트) | `ChalNaTypography.body` |
| `ChalNaTypography.krBody(Size.caption)` (helper/error) | `ChalNaTypography.caption` |
| `.foregroundColor(ChalNaColor.Gray.g900)` | `.foregroundColor(ChalNaColor.textPrimary)` |
| `.fill(Color.white)` | `.fill(ChalNaColor.surface)` |
| `ChalNaRadius.button` | `ChalNaRadius.sm` |
| border: `isFocused ? Purple.p600 : Gray.g200` | `isFocused ? ChalNaColor.accent : ChalNaColor.borderStrong` |
| helper 색 `Gray.g500` | `ChalNaColor.textSecondary` |

추가로 플레이스홀더가 다크에서 보이도록 `TextField` 에 다음을 붙인다:

```swift
            TextField("", text: $text, prompt: Text(verbatim: placeholder)
                .foregroundColor(ChalNaColor.textTertiary))
                .tint(ChalNaColor.accent)
```

- [ ] **Step 4: ChalNaTextArea 작성**

```swift
// Modules/DesignSystem/Sources/Components/ChalNaTextArea.swift
import SwiftUI

/// 멀티라인 입력. Support 화면의 `TextEditor` + 수동 플레이스홀더 오버레이를 대체한다.
public struct ChalNaTextArea: View {
    private let placeholder: String
    private let minHeight: CGFloat
    @Binding private var text: String
    @FocusState private var isFocused: Bool

    public init(placeholder: String, minHeight: CGFloat = 180, text: Binding<String>) {
        self.placeholder = placeholder
        self.minHeight = minHeight
        self._text = text
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(verbatim: placeholder)
                    .font(ChalNaTypography.body)
                    .foregroundColor(ChalNaColor.textTertiary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .font(ChalNaTypography.body)
                .foregroundColor(ChalNaColor.textPrimary)
                .tint(ChalNaColor.accent)
                .focused($isFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: minHeight)
        }
        .background(
            RoundedRectangle(cornerRadius: ChalNaRadius.sm, style: .continuous)
                .fill(ChalNaColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChalNaRadius.sm, style: .continuous)
                .strokeBorder(isFocused ? ChalNaColor.accent : ChalNaColor.borderStrong,
                              lineWidth: isFocused ? 1.5 : 1)
        )
        .animation(ChalNaMotion.fast, value: isFocused)
    }
}

#Preview {
    @Previewable @State var text = ""
    return ChalNaTextArea(placeholder: "불편한 점이나 제안을 자유롭게 적어주세요.", text: $text)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChalNaColor.bg)
}
```

- [ ] **Step 5: dead code 삭제**

```bash
git rm Modules/DesignSystem/Sources/Components/ChalNaBottomSheet.swift
```

실사용 0곳으로 확인됐다. `LiveBadge`·`ChalNaChip`·`ClipThumbCard`·`ChalNaNavigationBar`·
`ChalNaHeaderActionButtonStyle`·`View+ChalNaTopBar` 는 아직 호출처가 남아 있어 **Task 26 에서** 삭제한다.

- [ ] **Step 6: Showcase 전면 재작성**

`Modules/DesignSystem/Sources/Showcase/DesignSystemShowcaseView.swift` 전체를 교체한다:

```swift
import SwiftUI

/// 토큰·컴포넌트 전수 확인 화면. 이번 리디자인의 회귀 검증 수단이다.
/// Xcode Canvas 에서 Dynamic Type 을 xxxLarge 로 올려도 깨지지 않아야 한다.
public struct DesignSystemShowcaseView: View {
    @State private var toggleOn = true
    @State private var sliderValue: Double = 0.6
    @State private var fieldText = ""
    @State private var areaText = ""

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            ChalNaNavBar(
                verbatimTitle: "Design System",
                caption: "dark cinematic",
                leading: .back {},
                trailing: .icon(.settings, accessibilityLabel: "설정") {},
                showsDivider: true
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    section("색") { colorSwatches }
                    section("타이포") { typeSpecimens }
                    section("버튼") { buttons }
                    section("태그") { tags }
                    section("리스트 행") { listRows }
                    section("카드 · 안내") { cards }
                    section("상태") { states }
                    section("입력") { inputs }
                    section("썸네일") { thumbs }
                    section("캔버스") { canvas }
                    section("아이콘") { icons }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .chalNaScreen()
    }

    @ViewBuilder
    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: title)
                .font(ChalNaTypography.title)
                .foregroundColor(ChalNaColor.textPrimary)
            content()
        }
    }

    private var colorSwatches: some View {
        let entries: [(String, Color)] = [
            ("bg", ChalNaColor.bg), ("surface", ChalNaColor.surface),
            ("surfaceRaised", ChalNaColor.surfaceRaised), ("canvas", ChalNaColor.canvas),
            ("border", ChalNaColor.border), ("borderStrong", ChalNaColor.borderStrong),
            ("textPrimary", ChalNaColor.textPrimary), ("textSecondary", ChalNaColor.textSecondary),
            ("textTertiary", ChalNaColor.textTertiary), ("accent", ChalNaColor.accent),
            ("accentFill", ChalNaColor.accentFill), ("accentPressed", ChalNaColor.accentPressed),
            ("danger", ChalNaColor.danger), ("success", ChalNaColor.success),
            ("brandDeep", ChalNaColor.brandDeep),
        ]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(entries, id: \.0) { name, color in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: ChalNaRadius.xs, style: .continuous)
                        .fill(color)
                        .frame(height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: ChalNaRadius.xs, style: .continuous)
                                .strokeBorder(ChalNaColor.border, lineWidth: 1)
                        )
                    Text(verbatim: name)
                        .font(ChalNaTypography.caption)
                        .foregroundColor(ChalNaColor.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var typeSpecimens: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "display — 찰나의 순간").font(ChalNaTypography.display)
            Text(verbatim: "title — 최근 필름").font(ChalNaTypography.title)
            Text(verbatim: "headline — 제주도, 우리의 봄").font(ChalNaTypography.headline)
            Text(verbatim: "body — Live Photo와 짧은 영상을 이어 붙여요").font(ChalNaTypography.body)
            Text(verbatim: "label — 8 클립 · Live 5").font(ChalNaTypography.label)
            Text(verbatim: "caption — 클립을 탭해 편집").font(ChalNaTypography.caption)
            Text(verbatim: "mono — 00:12 / 01:40").font(ChalNaTypography.mono())
            Text(verbatim: "keris — 찰나").font(ChalNaTypography.keris(28))
        }
        .foregroundColor(ChalNaColor.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            Button("primary · lg") {}.buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
            Button("secondary · lg") {}.buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))
            HStack(spacing: 10) {
                Button("ghost") {}.buttonStyle(.chalNaGhost)
                Button("삭제") {}.buttonStyle(.chalNa(.ghost, destructive: true))
                Button("md") {}.buttonStyle(.chalNa(.secondary, size: .md))
                Button("sm") {}.buttonStyle(.chalNa(.secondary, size: .sm))
            }
            Button("disabled") {}.buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true)).disabled(true)
        }
    }

    private var tags: some View {
        HStack(spacing: 8) {
            ChalNaTag("LIVE", variant: .live)
            ChalNaTag("VIDEO", variant: .video, icon: .video)
            ChalNaTag("8 CLIPS", variant: .neutral)
            ChalNaTag("선택됨", variant: .accent, icon: .check)
            Spacer(minLength: 0)
        }
    }

    private var listRows: some View {
        ChalNaCard(padding: 0) {
            VStack(spacing: 0) {
                ChalNaListRow.navigate(title: "라벨", subtitle: "영상에 표시되는 시각·날짜 라벨") {}
                ChalNaListDivider()
                ChalNaListRow.navigate(title: "위치", value: "가운데 아래") {}
                ChalNaListDivider()
                ChalNaListRow.toggle(title: "시각 표시", isOn: toggleOn) { toggleOn = $0 }
                ChalNaListDivider()
                ChalNaListRow.slider(
                    title: "투명도",
                    value: sliderValue,
                    trailingText: "\(Int(sliderValue * 100))%"
                ) { sliderValue = $0 }
                ChalNaListDivider()
                ChalNaListRow.check(verbatimTitle: "한국어", isChecked: true) {}
                ChalNaListDivider()
                ChalNaListRow.navigate(title: "비활성 행", value: "off", enabled: false) {}
            }
        }
    }

    private var cards: some View {
        VStack(spacing: 12) {
            ChalNaCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: "제주도, 우리의 봄")
                        .font(ChalNaTypography.headline)
                        .foregroundColor(ChalNaColor.textPrimary)
                    Text(verbatim: "8 클립 · 01:40")
                        .font(ChalNaTypography.label)
                        .foregroundColor(ChalNaColor.textSecondary)
                }
            }
            ChalNaNotice(
                title: "영상 파일을 찾을 수 없어요",
                message: "앱을 다시 설치하셨거나 파일이 삭제되었어요."
            )
        }
    }

    private var states: some View {
        VStack(alignment: .leading, spacing: 16) {
            ChalNaProgressBar(progress: 0.62)
            ChalNaToast(message: "사진 보관함에 저장했어요")
            ChalNaEmptyState(
                title: "아직 만든 필름이 없어요",
                message: "첫 Vlog를 시작해 보세요.",
                actionTitle: "시작하기"
            ) {}
        }
    }

    private var inputs: some View {
        VStack(spacing: 12) {
            ChalNaTextField(label: "필름 제목", placeholder: "예: 제주도, 우리의 봄",
                            helper: "비워두면 자동으로 채워져요.", text: $fieldText)
            ChalNaTextArea(placeholder: "불편한 점이나 제안을 적어주세요.", minHeight: 100, text: $areaText)
        }
    }

    private var thumbs: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array([MediaThumbState.normal, .selected, .playing, .lifted, .ghost, .dimmed].enumerated()),
                    id: \.offset) { _, state in
                MediaThumb(state: state, size: CGSize(width: 44, height: 78)) {
                    LinearGradient(colors: [ChalNaColor.accentFill, ChalNaColor.canvas],
                                   startPoint: .top, endPoint: .bottom)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var canvas: some View {
        ChalNaCanvas { box in
            LinearGradient(colors: [ChalNaColor.brandDeep, ChalNaColor.canvas],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: box.width, height: box.height)
        } overlay: { _ in
            ChalNaTag("3 / 8", variant: .neutral)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(12)
        }
        .frame(height: 220)
    }

    private var icons: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 18) {
            ForEach(ChalNaIconKind.allCases, id: \.self) { kind in
                VStack(spacing: 6) {
                    ChalNaIcon(kind, size: 22)
                        .foregroundColor(ChalNaColor.textPrimary)
                    Text(verbatim: kind.rawValue)
                        .font(ChalNaTypography.caption)
                        .foregroundColor(ChalNaColor.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }
}

#Preview("Showcase") {
    DesignSystemShowcaseView()
}

#Preview("Showcase · xxxLarge") {
    DesignSystemShowcaseView()
        .environment(\.dynamicTypeSize, .xxxLarge)
}
```

- [ ] **Step 7: 빌드 확인 + TEMP 섹션 전멸 확인**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:" | sort -u
grep -c "TEMP(T" Modules/DesignSystem/Sources/Showcase/DesignSystemShowcaseView.swift || echo "0 ✓"
```

Expected: 에러 없음. `ChalNaBottomSheet` 를 삭제했는데 에러가 나면 어딘가 호출처가 있다는 뜻 —
그 경우 삭제를 되돌리고 Task 26 으로 미룬다.

**`TEMP(T` 는 반드시 0건이어야 한다.** Task 6~11 이 각자 만든 컴포넌트를 구 Showcase 하단에
`// TEMP(T<N>):` 임시 섹션으로 덧붙여 왔다(최대 6개). 이 태스크는 파일을 **전체 교체**하므로
임시 섹션이 전부 사라지는 것이 정상이다. 하나라도 남아 있으면 전체 교체가 아니라 부분 편집을
한 것이므로, Step 4 의 코드로 파일을 다시 통째로 덮어쓴다.

- [ ] **Step 8: Showcase 프리뷰를 두 크기로 확인 — 이 태스크의 핵심 검증**

Xcode 에서 `DesignSystemShowcaseView.swift` Canvas 를 열고 **두 프리뷰 모두** 확인한다.

확인 목록:
1. 색 스와치 15종이 서로 구별되는가 (특히 `bg`/`canvas` 가 거의 같고, `surface`/`surfaceRaised` 가 구별되는가)
2. 타이포 8종이 크기 순서대로 보이는가
3. 버튼 6종의 위계가 읽히는가 (primary > secondary > ghost, destructive 가 레드)
4. **아이콘 24종 전부가 그려지는가** — 빈 칸이 있으면 그 심볼 이름이 틀렸다
5. **`xxxLarge` 프리뷰에서 리스트 행·버튼이 잘리지 않는가** (행이 밀려 커져야 정상)
6. MediaThumb 6상태가 구별되는가

- [ ] **Step 9: 커밋**

```bash
git add Modules/DesignSystem/Sources/Components/ChalNaTextField.swift \
        Modules/DesignSystem/Sources/Components/ChalNaTextArea.swift \
        Modules/DesignSystem/Sources/Showcase/DesignSystemShowcaseView.swift
git commit -m "$(cat <<'EOF'
✨ feat(DesignSystem): 입력 컴포넌트 다크 전환 + Showcase 전면 재작성

- ChalNaTextField 다크 재스타일 (시그니처 유지), 플레이스홀더 prompt 색 지정
- ChalNaTextArea 신설 — Support 의 TextEditor + 수동 플레이스홀더 오버레이 대체
- ChalNaBottomSheet 삭제 (실사용 0곳)
- Showcase 를 신규 인벤토리 전수로 재작성 + xxxLarge 프리뷰 추가
  → 아이콘 심볼 누락과 Dynamic Type 파열을 한 화면에서 잡는 회귀 검증 수단

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# Phase P2 — 저위험 화면 (Task 13–16)

> **P2~P4 공통 마이그레이션 규칙.** 각 화면에서 아래 치환을 기계적으로 적용한다.
> 이 표는 매 태스크에서 다시 찾아보지 않도록 여기 한 번만 적는다.
>
> | 기존 | 변경 |
> |---|---|
> | `ChalNaColor.Gray.g900` (텍스트) | `ChalNaColor.textPrimary` |
> | `ChalNaColor.Gray.g500` (보조 텍스트) | `ChalNaColor.textSecondary` |
> | `ChalNaColor.Gray.g400`/`g300` (비활성) | `ChalNaColor.textTertiary` |
> | `ChalNaColor.Gray.g200`/`g100` (선) | `ChalNaColor.border` |
> | `ChalNaColor.Gray.g50` (면) | `ChalNaColor.surface` |
> | `Color.white` (카드·시트 면) | `ChalNaColor.surface` 또는 `.surfaceRaised` |
> | `Color.white` (accent 위 글자) | `ChalNaColor.onAccent` |
> | `ChalNaColor.Purple.p600` | `ChalNaColor.accent`(텍스트·선) / `.accentFill`(면) |
> | `ChalNaColor.Purple.p900` | `ChalNaColor.brandDeep` |
> | `ChalNaColor.info` | `ChalNaColor.success` (완료 상태) |
> | `ChalNaTypography.displayKR(26~32)` | `ChalNaTypography.display` |
> | `ChalNaTypography.title(Size.h1/.h2/.big)` | `.display` 또는 `.title` |
> | `ChalNaTypography.krSemibold(15~16)` · `krBody(16, .semibold)` | `.headline` |
> | `ChalNaTypography.krBody(15~16)` | `.body` |
> | `ChalNaTypography.krBody(13~14)` · `Size.small` | `.label` |
> | `ChalNaTypography.krBody(11~12)` · `Size.caption` | `.caption` |
> | `ChalNaTypography.monoFallback(n)` (숫자) | `ChalNaTypography.mono()` |
> | `Text(...).tagLabel()` | `.font(ChalNaTypography.label).foregroundColor(ChalNaColor.textSecondary)` |
> | `ChalNaRadius.card` | `ChalNaRadius.md` |
> | `ChalNaRadius.button` | `ChalNaRadius.sm` |
> | `ChalNaRadius.sheet` | `ChalNaRadius.lg` |
> | `ChalNaRadius.film` | `ChalNaRadius.xs` |
> | `chalNaShadow(ChalNaShadow.md/.lg/.sm)` | 제거 (밝기 단계로 대체) 또는 `.floating` |
> | `ChalNaChip(...)` | `ChalNaTag(...)` |
> | `ClipThumbCard(...)` | `MediaThumb(...)` |
> | `ChalNaNavigationBar(...)` + `.chalNaHeaderBar(...)` | `ChalNaNavBar(...)` (+ 필요시 `.chalNaScrollHairline(progress:)`) |
> | `ChalNaHeaderBackButton` | `ChalNaNavAction.back` |
> | `ChalNaHeaderCloseButton` | `ChalNaNavAction.close` |
> | `ChalNaHeaderTextAction("완료")` | `ChalNaNavAction.text("완료")` |
> | `Image(systemName: "...")` | `ChalNaIcon(...)` |
> | `.buttonStyle(.chalNaCoral)` | `.buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))` |
> | `.buttonStyle(.chalNaOutline)` | `.buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))` |
> | 화면 좌우 여백 `16`/`24` 혼용 | **`20` 통일** |
> | 하단 고정 영역의 여백+배경+hairline 인라인 체인 | `ChalNaBottomBar { … }` (Task 7) |
>
> **각 화면 작업 후 반드시:** 빌드 → 해당 화면 스크린샷 → 커밋.
>
> **하단 크롬 주의.** Task 17·18·20·25 의 코드 예시에는 하단 크롬이
> `.padding(...).background(ChalNaColor.bg.ignoresSafeArea(edges: .bottom)).overlay { Rectangle()… }`
> 형태로 펼쳐져 있다. **실제 구현에서는 그 체인을 `ChalNaBottomBar { … }` 로 감싼다** —
> 네 화면이 같은 크롬을 복붙하는 것을 막기 위해 Task 7 에서 컴포넌트로 뺐다.

## Task 13: SplashView

**Files:**
- Modify: `ChalNa/Sources/App/SplashView.swift`
- Modify: `ChalNa/Sources/App/RootView.swift` (전역 Dynamic Type 상한 추가)

**Interfaces:**
- Consumes: `ChalNaColor.bg/.brandDeep/.textPrimary`, `ChalNaTypography.keris/.label`.
- Produces: 없음 (화면).

- [ ] **Step 1: SplashView 를 글로우 방식으로 교체**

`ChalNa/Sources/App/SplashView.swift` 전체를 교체한다:

```swift
import SwiftUI
import DesignSystem

/// 앱 시작 시 앱 아이콘을 페이드+확대로 보여주는 스플래시.
/// 순수 표현·일회성이라 TCA 상태 없이 로컬 @State 로만 동작.
///
/// 배경은 `bg`(본문과 동일) + 아이콘 뒤 `brandDeep` 라디얼 글로우다.
/// brandDeep 풀배경이면 본문(bg)으로 넘어갈 때 밝기가 급변한다.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            // 브랜드 색 라디얼 글로우 — 스플래시가 이미 본문의 어둠 위에 있게 한다.
            RadialGradient(
                colors: [ChalNaColor.brandDeep.opacity(0.55), ChalNaColor.bg],
                center: .center,
                startRadius: 0,
                endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("splash_icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

                VStack(spacing: 2) {
                    Text(verbatim: "찰나")
                        .font(ChalNaTypography.keris(48))
                    Text(verbatim: "ChalNa")
                        .font(ChalNaTypography.keris(24))
                }
                .foregroundStyle(ChalNaColor.textPrimary)
            }
            .scaleEffect(scale)
            .opacity(appeared ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChalNaColor.bg.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }

    /// Reduce Motion 시 확대 생략(페이드만).
    private var scale: CGFloat {
        if reduceMotion { return 1 }
        return appeared ? 1.0 : 0.92
    }
}

#Preview {
    SplashView()
}
```

> 제거한 것: `shadow(color: .white, radius: 4)` — 아이콘 주변 흰 후광이 로고 외곽을 뭉갠다.
> 제거한 것: `Self.kerisFontName` 하드코딩 상수 — `ChalNaTypography.keris` 가 폰트 해석을
> 이미 담당하고, 하드코딩된 PostScript 이름은 폰트 파일이 바뀌면 조용히 시스템 폰트로 폴백한다.

- [ ] **Step 2: RootView 에 전역 Dynamic Type 상한 추가**

`ChalNa/Sources/App/RootView.swift` 의 `body` 에서 `.environment(\.locale, languageStore.locale)`
**바로 다음 줄**에 추가한다:

```swift
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
```

이유: Timeline/Export 는 9:16 캔버스가 레이아웃을 지배해 무제한 확대를 수용할 수 없다.
상한을 두고 그 안에서 실제로 동작하게 만드는 편이, 확대를 통째로 무시하는 현재보다 정직하다.

- [ ] **Step 3: 빌드 후 스플래시 스크린샷**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           -derivedDataPath /tmp/chalna-build build 2>&1 | tail -5
xcrun simctl install "iPhone 17 Pro" /tmp/chalna-dd/Build/Products/Debug-iphonesimulator/ChalNa.app
xcrun simctl terminate "iPhone 17 Pro" ios.inho.ChalNa 2>/dev/null || true
xcrun simctl launch "iPhone 17 Pro" ios.inho.ChalNa
xcrun simctl io "iPhone 17 Pro" screenshot /tmp/p2-splash.png
open /tmp/p2-splash.png
```

확인할 것: 글로우가 중앙에서 부드럽게 퍼지는가, 아이콘 외곽이 선명한가(후광 없음),
"찰나" 가 KERISKEDU 로 렌더되는가(시스템 폰트로 폴백되면 획이 굵고 속이 찬 모양이 된다).

- [ ] **Step 4: 커밋**

```bash
git add ChalNa/Sources/App/SplashView.swift ChalNa/Sources/App/RootView.swift
git commit -m "$(cat <<'EOF'
💄 style(Splash): brandDeep 풀배경 → bg + 라디얼 글로우

- 스플래시가 본문과 같은 어둠 위에 있어 전환 시 밝기 급변이 사라짐
- 아이콘 흰 후광(shadow color: .white) 제거 — 로고 외곽을 뭉개고 있었음
- 하드코딩된 KERISKEDU PostScript 이름 제거, ChalNaTypography.keris 로 위임
- RootView 에 전역 dynamicTypeSize 상한(accessibility1) 추가

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: SettingsView · LanguageView

**Files:**
- Modify: `Modules/SettingsFeature/Sources/SettingsView.swift`
- Modify: `Modules/SettingsFeature/Sources/LanguageScene/LanguageView.swift`

**Interfaces:**
- Consumes: `ChalNaNavBar`, `ChalNaNavAction`, `ChalNaCard`, `ChalNaListRow`, `ChalNaListDivider`, `chalNaScreen()`.
- Produces: 없음 (화면).

- [ ] **Step 1: `ChalNaCard` 에 clip 범위 경고 주석 추가 (Task 12 리뷰 Minor)**

`ChalNaCard` 의 `clipShape` 는 **패딩 적용 전 `content()` 자체**에 걸린다. 지금은 무해하지만,
`padding > 0` 인 카드에 **그림자 있는 콘텐츠**(예: 썸네일)를 직접 넣는 호출자가 생기면
그 그림자가 잘린다. P2~P4 에서 새 호출자가 놓치기 쉬운 함정이라 주석으로 못박는다.

`Modules/DesignSystem/Sources/Components/ChalNaCard.swift` 의 타입 doc 주석에 한 줄 추가:

```swift
/// surface + 1px border 컨테이너.
///
/// **주의: `clipShape` 는 패딩 적용 전 `content()` 에 걸린다.** 리스트 행 press 하이라이트가
/// 카드 모서리를 넘지 않게 하려는 것이므로, 그림자가 있는 콘텐츠를 직접 넣으면 그림자가 잘린다.
/// 그런 콘텐츠는 카드 밖에 두거나 `padding: 0` + 자체 여백으로 구성한다.
```

- [ ] **Step 2: SettingsView 재작성**

`Modules/SettingsFeature/Sources/SettingsView.swift` 의 `body` 와 `menuRow` 를 교체한다
(`init`·`store` 프로퍼티는 그대로):

```swift
    public var body: some View {
        VStack(spacing: 0) {
            ChalNaNavBar(
                title: "설정",
                leading: .back { store.send(.backTapped) },
                showsDivider: true
            )
            .zIndex(1)

            ScrollView {
                ChalNaCard(padding: 0) {
                    VStack(spacing: 0) {
                        ChalNaListRow.navigate(
                            title: "라벨",
                            subtitle: "영상에 표시되는 시각·날짜 라벨"
                        ) { store.send(.labelMenuTapped) }

                        ChalNaListDivider()

                        ChalNaListRow.navigate(
                            title: "언어",
                            subtitle: "앱 표시 언어를 선택하세요"
                        ) { store.send(.languageMenuTapped) }

                        ChalNaListDivider()

                        ChalNaListRow.navigate(
                            title: "문의·신고",
                            subtitle: "불편한 점이나 제안을 보내주세요"
                        ) { store.send(.supportMenuTapped) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .chalNaScreen()
        .onAppear { store.send(.onAppear) }
    }
```

`menuRow(title:subtitle:action:)` 함수 전체를 **삭제**한다 (`ChalNaListRow.navigate` 가 대체).
이로써 `.font(.system(size: 16, weight: .semibold))`·`.font(.system(size: 14))`·
`.font(.system(size: 16, weight: .semibold))`(chevron)·`Image(systemName: "chevron.right")`·
`cornerRadius: 8` 리터럴 2곳이 함께 사라진다 (감사 #13, #14).

- [ ] **Step 3: LanguageView 재작성**

`Modules/SettingsFeature/Sources/LanguageScene/LanguageView.swift` 의 `body` 와 `languageRow` 를 교체한다:

```swift
    public var body: some View {
        VStack(spacing: 0) {
            ChalNaNavBar(
                title: "언어",
                leading: .back { store.send(.backTapped) },
                showsDivider: true
            )
            .zIndex(1)

            ScrollView {
                ChalNaCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element) { index, lang in
                            if index > 0 { ChalNaListDivider() }
                            // displayName 은 이미 해석된 String → verbatim.
                            ChalNaListRow.check(
                                verbatimTitle: lang.displayName,
                                isChecked: lang == languageStore.language
                            ) {
                                languageStore.set(lang)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .chalNaScreen()
    }
```

`languageRow(_:)` 함수 전체를 **삭제**한다. `Image(systemName: "checkmark")` 직접 사용이 함께 사라진다.
`.background(Color.white.ignoresSafeArea())` → `.chalNaScreen()` 으로 바뀐 것도 확인한다.

- [ ] **Step 4: 빌드 후 두 화면 스크린샷**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           -derivedDataPath /tmp/chalna-build build 2>&1 | grep -E "error:" | sort -u
xcrun simctl install "iPhone 17 Pro" /tmp/chalna-dd/Build/Products/Debug-iphonesimulator/ChalNa.app
xcrun simctl terminate "iPhone 17 Pro" ios.inho.ChalNa 2>/dev/null || true
xcrun simctl launch "iPhone 17 Pro" ios.inho.ChalNa
```

시뮬레이터에서 홈 우상단 설정 아이콘 → 설정 화면 → 언어 화면으로 이동한 뒤:

```bash
xcrun simctl io "iPhone 17 Pro" screenshot /tmp/p2-settings.png
open /tmp/p2-settings.png
```

확인할 것: 카드가 `surface`(배경보다 살짝 밝음)로 보이는가, 행 구분선이 좌측 16pt 인셋인가,
chevron 이 `textSecondary` 인가, 흰 판이 남아 있지 않은가.

> **★ 여기서 카드 press 하이라이트를 반드시 한 번 캡처한다 (Task 8·12 에서 미해결).**
> `ChalNaCard(padding: 0) { rows }` 의 **첫 행 또는 마지막 행을 누른 상태**에서 스크린샷을 찍어,
> 사각 press 하이라이트가 카드의 14pt 둥근 모서리 **안에 갇히는지** 확인한다.
> Task 8 이 이 bleed 를 지적하고 Task 12 가 `clipShape` 로 고쳤지만, 터치 주입 수단이 없어
> **세 에이전트 모두 눌림 상태를 한 번도 못 잡았다.** 소스 추론상으로는 맞지만 육안 확인이 비어 있다.
>
> 이 화면은 실제 리스트 행이 있는 첫 화면이라 여기가 첫 기회다. 캡처 방법:
> - `xcrun simctl` 에는 탭 주입이 없다. 대신 **`ChalNaListRow` 를 눌린 상태로 강제 렌더하는
>   임시 `#Preview`** 를 `SettingsView.swift` 에 추가해 `RenderPreview` 로 찍는다
>   (`ButtonStyle` 의 `configuration.isPressed` 를 직접 흉내낼 수 없으므로,
>   `ListRowPressStyle` 의 pressed 배경색 `surfaceRaised` 를 첫 행에 직접 깐 프리뷰로 충분하다).
> - 그것도 어려우면 **못 했다고 정직하게 보고**하고 다음 화면(Task 15)으로 넘긴다.
>   추측으로 "확인했다"고 쓰지 말 것.

> **상태바 스타일 — 이미 해결됨(조치 불필요).** Task 3 직후 컨트롤러가 Splash 화면
> (`Purple.p900` 어두운 배경)에서 스크린샷으로 확정했다: 시계·WiFi·배터리가 **흰색**으로
> 렌더된다. 즉 `UIUserInterfaceStyle: Dark` 는 정상 동작한다.
>
> Task 3 때 Home 에서 상태바가 검정으로 보인 것은, 헤더의 `Color.white` 띠가 상태바
> 영역을 덮고 있어 iOS 가 그 위에 **검정 글자를 올린 것**이다(흰 배경 위 검정 = 정상·가독).
> iOS 가 화면별로 적응하므로 Task 17 이 그 흰 헤더를 없애면 Home 도 흰 상태바가 된다.
>
> **따라서 `preferredColorScheme` / `overrideUserInterfaceStyle` / `statusBarStyle` 오버라이드를
> 넣지 말 것.** 넣으면 흰 배경 구간에서 흰 글자가 되어 시계가 사라진다.

- [ ] **Step 5: 커밋**

```bash
git add Modules/SettingsFeature/Sources/SettingsView.swift \
        Modules/SettingsFeature/Sources/LanguageScene/LanguageView.swift
git commit -m "$(cat <<'EOF'
💄 style(Settings): 설정·언어 화면 다크 전환 + ChalNaListRow 도입

- 손으로 쓴 menuRow / languageRow 빌더 2개를 ChalNaListRow 로 대체
- .font(.system(...)) 4곳, cornerRadius: 8 리터럴 2곳,
  Image(systemName:) 직접 사용 2곳 제거
- ChalNaNavBar + ChalNaCard + ChalNaListDivider 로 통일

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: LabelSettingsView · LabelPositionSettingsView (10pt 테두리 버그)

**Files:**
- Modify: `Modules/SettingsFeature/Sources/LabelSettingsScene/LabelSettingsView.swift`
- Modify: `Modules/SettingsFeature/Sources/LabelSettingsScene/LabelPositionScene/LabelPositionSettingsView.swift`

**Interfaces:**
- Consumes: `ChalNaNavBar`, `ChalNaCard`, `ChalNaListRow`, `ChalNaListDivider`, `ChalNaColor`, `ChalNaTypography`, `ChalNaRadius`.
- Produces: 없음 (화면).

- [ ] **Step 1: LabelSettingsView 를 ChalNaListRow 로 재작성**

`body` 와 `labelRows(...)` 를 교체한다:

```swift
    public var body: some View {
        VStack(spacing: 0) {
            ChalNaNavBar(
                title: "라벨",
                leading: .back { store.send(.backTapped) },
                showsDivider: true
            )
            .zIndex(1)

            ScrollView {
                ChalNaCard(padding: 0) {
                    VStack(spacing: 0) {
                        labelRows(
                            kind: .time,
                            isOn: store.timeEnabled,
                            position: store.timePosition,
                            opacity: store.timeOpacity,
                            onToggle: { store.send(.timeToggled($0)) },
                            onPositionTap: { store.send(.timePositionRowTapped) },
                            onOpacityChange: { store.send(.timeOpacityChanged($0)) }
                        )

                        ChalNaListDivider()

                        labelRows(
                            kind: .date,
                            isOn: store.dateEnabled,
                            position: store.datePosition,
                            opacity: store.dateOpacity,
                            onToggle: { store.send(.dateToggled($0)) },
                            onPositionTap: { store.send(.datePositionRowTapped) },
                            onOpacityChange: { store.send(.dateOpacityChanged($0)) }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .chalNaScreen()
    }

    @ViewBuilder
    private func labelRows(
        kind: LabelKind,
        isOn: Bool,
        position: LabelPosition,
        opacity: Double,
        onToggle: @escaping (Bool) -> Void,
        onPositionTap: @escaping () -> Void,
        onOpacityChange: @escaping (Double) -> Void
    ) -> some View {
        // LabelKind.title/.subtitle 은 String(localized:) 로 이미 해석된 String 이다
        // (Models/Sources/LabelSettings.swift:86,93). verbatim 변형을 써야 이중 조회를 피한다.
        ChalNaListRow.toggleVerbatim(
            title: kind.title,
            subtitle: kind.subtitle,
            isOn: isOn,
            onChange: onToggle
        )

        ChalNaListDivider()

        ChalNaListRow.navigate(
            title: "위치",
            value: position.koreanName,
            enabled: isOn,
            action: onPositionTap
        )

        ChalNaListDivider()

        ChalNaListRow.slider(
            title: "투명도",
            value: opacity,
            enabled: isOn,
            trailingText: "\(Int((opacity * 100).rounded()))%",
            onChange: onOpacityChange
        )
    }
```

> **타입 확정(사전 확인 완료).** `LabelKind.title`·`.subtitle` 은 `String(localized:)` 로
> 이미 해석된 `String` 이므로 **`toggleVerbatim` 을 쓴다.** `LocalizedStringKey` 변형에 넘기면
> 번역 테이블을 다시 조회해 키 자체를 반환하는, 조용히 잘못된 동작이 된다.
> `LabelPosition.koreanName` 도 `String` 이며 `navigate(value:)` 가 이미 `String` 을 받으므로 그대로 쓴다.
> `kind.subtitle` 은 기존에 `monoFallback` 로 렌더됐지만 한글이 섞이면 폴백이 생기므로
> `ChalNaListRow` 의 `.label`(시스템 폰트)로 바뀐다 — 의도된 변경(감사 #11).

- [ ] **Step 2: LabelPositionSettingsView — 10pt 버그 수정 + 도형 그리드로 교체**

`preview`·`grid`·`sampleLabel` 을 교체한다:

```swift
    // MARK: - Mini preview (9:16 중립 캔버스)

    private var preview: some View {
        ZStack(alignment: alignment(for: store.selected)) {
            RoundedRectangle(cornerRadius: ChalNaRadius.md, style: .continuous)
                .fill(ChalNaColor.surfaceRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: ChalNaRadius.md, style: .continuous)
                        .strokeBorder(ChalNaColor.border, lineWidth: 1)
                )

            sampleLabel
                .padding(12)
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .frame(maxWidth: 200)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var sampleLabel: some View {
        if store.kind == .time {
            Text(verbatim: store.kind.sampleText)
                .font(ChalNaTypography.keris(40))
                .foregroundColor(ChalNaColor.textPrimary.opacity(0.6))
        } else {
            Text(verbatim: store.kind.sampleText)
                .font(ChalNaTypography.keris(13))
                .foregroundColor(ChalNaColor.textPrimary)
        }
    }

    // MARK: - 3×3 grid (텍스트 대신 도형으로 위치를 시각화)

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(LabelPosition.allCases, id: \.self) { pos in
                let isSelected = store.selected == pos
                Button { store.send(.positionSelected(pos)) } label: {
                    positionCell(pos, isSelected: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: pos.koreanName))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    /// 9칸 미니 도형으로 위치를 표현한다 — 글자보다 훨씬 빨리 읽힌다.
    private func positionCell(_ pos: LabelPosition, isSelected: Bool) -> some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { column in
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(cellFill(pos, row: row, column: column, isSelected: isSelected))
                            .frame(width: 10, height: 6)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(
            RoundedRectangle(cornerRadius: ChalNaRadius.sm, style: .continuous)
                .fill(isSelected ? ChalNaColor.accentFill.opacity(0.20) : ChalNaColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChalNaRadius.sm, style: .continuous)
                .strokeBorder(isSelected ? ChalNaColor.accent : ChalNaColor.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private func cellFill(_ pos: LabelPosition, row: Int, column: Int, isSelected: Bool) -> Color {
        let target = gridSlot(for: pos)
        guard target.row == row, target.column == column else {
            return ChalNaColor.border
        }
        return isSelected ? ChalNaColor.accent : ChalNaColor.textSecondary
    }

    /// LabelPosition → 3×3 격자 좌표 (row 0 = 위, column 0 = 좌).
    private func gridSlot(for pos: LabelPosition) -> (row: Int, column: Int) {
        switch pos {
        case .topLeft:      return (0, 0)
        case .topCenter:    return (0, 1)
        case .topRight:     return (0, 2)
        case .centerLeft:   return (1, 0)
        case .center:       return (1, 1)
        case .centerRight:  return (1, 2)
        case .bottomLeft:   return (2, 0)
        case .bottomCenter: return (2, 1)
        case .bottomRight:  return (2, 2)
        }
    }
```

또한 헤더를 `ChalNaNavBar` 로 바꾼다:

```swift
            ChalNaNavBar(
                verbatimTitle: "\(store.kind.title) 위치",
                leading: .back { store.send(.backTapped) },
                showsDivider: true
            )
            .zIndex(1)
```

> **이것이 감사 #1 의 수정이다.** 기존 코드는
> `.strokeBorder(..., lineWidth: isSelected ? 0 : 10)` 로 비선택 셀에 10pt 테두리를 그렸다.
> 위 구현에는 `lineWidth: 1` 만 있다. 또 `.font(.system(size: 14, ...))` 직접 호출도 사라진다.
>
> **타이틀 보간(사전 확인 완료).** `store.kind.title` 은 이미 해석된 `String` 이므로
> `verbatimTitle: "\(store.kind.title) 위치"` 가 맞다. 기존 코드도 `ChalNaNavigationBar(title:)`
> (verbatim init)에 같은 보간을 넘기고 있었으므로 **동작·i18n 범위가 그대로 유지된다.**
> " 위치" 접미사의 로컬라이즈는 기존에도 없던 것이라 이번 범위에서 새로 만들지 않는다.

- [ ] **Step 3: 빌드 후 두 화면 스크린샷**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           -derivedDataPath /tmp/chalna-build build 2>&1 | grep -E "error:" | sort -u
xcrun simctl install "iPhone 17 Pro" /tmp/chalna-dd/Build/Products/Debug-iphonesimulator/ChalNa.app
xcrun simctl terminate "iPhone 17 Pro" ios.inho.ChalNa 2>/dev/null || true
xcrun simctl launch "iPhone 17 Pro" ios.inho.ChalNa
```

설정 → 라벨 → 위치 로 이동한 뒤 스크린샷:

```bash
xcrun simctl io "iPhone 17 Pro" screenshot /tmp/p2-labelposition.png
open /tmp/p2-labelposition.png
```

확인할 것 (**이 태스크의 핵심**):
1. 3×3 셀에 **10pt 두꺼운 테두리가 없다** — 1pt 얇은 선만
2. 각 셀의 9칸 도형에서 해당 위치 칸만 강조돼 있다
3. 선택된 셀이 accent 테두리 + 옅은 accent 배경이다
4. 라벨 설정 화면의 토글·슬라이더가 다크에서 보인다 (OFF 일 때 `textTertiary` 로 죽는지)

- [ ] **Step 4: 커밋**

```bash
git add Modules/SettingsFeature/Sources/LabelSettingsScene/
git commit -m "$(cat <<'EOF'
🐛 fix(Settings): 위치 선택 3×3 그리드 10pt 테두리 버그 + 도형 시각화

- lineWidth: isSelected ? 0 : 10 → 1 (비선택 셀 내부를 잠식하던 오타)
- 텍스트 라벨("좌상단"…) 대신 9칸 미니 도형으로 위치를 표현 —
  위치 선택은 글자보다 도형이 훨씬 빨리 읽힌다. VoiceOver 라벨은 유지
- 라벨 설정 화면을 ChalNaListRow(toggle/navigate/slider)로 재작성
- .font(.system(...)) 직접 호출 제거, 다크 토큰 전환

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 16: SupportView

**Files:**
- Modify: `Modules/SettingsFeature/Sources/FeedbackScene/SupportScene/SupportView.swift`

**Interfaces:**
- Consumes: `ChalNaNavBar`, `ChalNaNavAction`, `ChalNaTag`, `ChalNaTextArea`, `ChalNaTextField`, `ChalNaButton`, `ChalNaCard`, `chalNaScreen()`.
- Produces: 없음 (화면).

- [ ] **Step 1: 헤더·카테고리 칩·에디터 교체**

`header` / `categoryChip` / `editor` 를 교체한다:

```swift
    private var header: some View {
        ChalNaNavBar(
            title: "문의·신고",
            leading: .back { store.send(.backTapped) },
            showsDivider: true
        )
    }

    /// 아이콘 없는 텍스트 전용 선택 칩.
    private func categoryChip(_ category: FeedbackCategory) -> some View {
        let isSelected = store.category == category
        return Text(verbatim: category.koreanName)
            .font(ChalNaTypography.label)
            .foregroundColor(isSelected ? ChalNaColor.accent : ChalNaColor.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? ChalNaColor.accentFill.opacity(0.22) : ChalNaColor.surface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? ChalNaColor.accent : ChalNaColor.border, lineWidth: 1)
            )
            .contentShape(Capsule())
    }

    private var editor: some View {
        ChalNaTextArea(placeholder: placeholder, minHeight: 180,
                       text: $store.text.sending(\.textChanged))
    }

> **★ placeholder 정렬을 확인한다 (Task 12 리뷰 Important).**
> `ChalNaTextArea` 의 placeholder 는 `.padding(.horizontal 16, .vertical 14)`, 실제 `TextEditor` 는
> `.padding(.horizontal 12, .vertical 8)` 이다. `TextEditor` 의 UIKit 기본 내부 inset
> (`lineFragmentPadding` 5pt + `textContainerInset` 8pt)을 보정한 값으로 보이지만,
> Task 12 리뷰가 diff 만으로는 확정할 수 없다고 남겼다.
> **이 화면이 유일한 실사용처이므로 여기서 확정한다** — 빈 상태 스크린샷과 한 글자 입력 후
> 스크린샷을 각각 찍어 **첫 글자가 placeholder 와 같은 위치에서 시작하는지** 비교한다.
> 1~2pt 차이면 수용, 눈에 띄게 튀면 `ChalNaTextArea` 의 두 padding 을 맞춘다.
```

`body` 의 `header` 호출부에서 `.padding(.horizontal, 16).padding(.vertical, 12).chalNaHeaderBar(scrollProgress: 1)`
체인을 **제거**한다 (`ChalNaNavBar` 가 자체 높이·배경·divider 를 갖는다).

본문 `padding(.horizontal, 24)` → `20`.

"모든 제보는 익명으로 전송돼요." 의 폰트를 `ChalNaTypography.caption`, 색을
`ChalNaColor.textSecondary` 로 바꾼다.

- [ ] **Step 2: 전송 버튼과 리딤 시트 교체**

```swift
    private var sendButton: some View {
        Button {
            store.send(.sendTapped)
        } label: {
            if store.isSending {
                ProgressView().tint(ChalNaColor.onAccent)
            } else {
                Text("전송")
            }
        }
        .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
        .disabled(isSendDisabled)
    }

    private var redeemCodeSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("리딤 코드")
                .font(ChalNaTypography.title)
                .foregroundColor(ChalNaColor.textPrimary)

            Text("코드를 입력하면 2026년까지 영상 생성 제한이 해제돼요.")
                .font(ChalNaTypography.label)
                .foregroundColor(ChalNaColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ChalNaTextField(
                placeholder: "Redeem Code",
                errorText: store.redeemError,
                text: $store.redeemCode.sending(\.redeemCodeChanged)
            )

            Button {
                store.send(.redeemSubmitted)
            } label: {
                Text("적용")
            }
            .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
            .disabled(store.redeemCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ChalNaColor.surfaceRaised.ignoresSafeArea())
    }
```

시트 표시부의 `.presentationDetents([.height(280)])` 에 `.presentationBackground(ChalNaColor.surfaceRaised)` 를 추가한다 —
다크 시트 배경이 시스템 기본 밝은 재질로 나오는 것을 막는다.

- [ ] **Step 3: 빌드 후 스크린샷 (문의 화면 + 리딤 시트)**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           -derivedDataPath /tmp/chalna-build build 2>&1 | grep -E "error:" | sort -u
xcrun simctl install "iPhone 17 Pro" /tmp/chalna-dd/Build/Products/Debug-iphonesimulator/ChalNa.app
xcrun simctl terminate "iPhone 17 Pro" ios.inho.ChalNa 2>/dev/null || true
xcrun simctl launch "iPhone 17 Pro" ios.inho.ChalNa
```

설정 → 문의·신고 로 이동, 텍스트를 입력해 플레이스홀더가 사라지는지 확인한 뒤 스크린샷:

```bash
xcrun simctl io "iPhone 17 Pro" screenshot /tmp/p2-support.png
open /tmp/p2-support.png
```

확인할 것: 플레이스홀더가 `textTertiary` 로 보이는가(안 보이면 대비 부족),
선택된 카테고리 칩이 accent 인가, TextArea 포커스 시 테두리가 accent 로 바뀌는가,
키보드가 올라와도 전송 버튼에 접근 가능한가.

- [ ] **Step 4: P2 전체 lint 진척 확인 후 커밋**

```bash
./scripts/design-lint.sh 2>&1 | grep -E "^(✓|✗)"
```

Expected: `.font(.system(` 위반이 P0 시점 18건에서 **눈에 띄게 줄었다**(SettingsView 2건,
LabelPositionSettingsView 1건 해소). 흰색 위반도 줄었다. 아직 0 은 아니다.

```bash
git add Modules/SettingsFeature/Sources/FeedbackScene/
git commit -m "$(cat <<'EOF'
💄 style(Support): 문의·신고 화면 다크 전환

- TextEditor + 수동 플레이스홀더 오버레이 → ChalNaTextArea
- 카테고리 칩 선택 상태를 accent 톤으로
- 리딤 시트에 presentationBackground(surfaceRaised) 지정 —
  다크에서 시스템 기본 밝은 재질이 나오는 것을 막음
- 헤더를 ChalNaNavBar 로, 본문 좌우 여백 24 → 20

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# Phase P3 — 위계 재배치 (Task 17–20)

## Task 17: HomeView — 위계 반전

**Files:**
- Modify: `Modules/HomeFeature/Sources/HomeView.swift` (전체 재작성)

**Interfaces:**
- Consumes: `ChalNaNavBar`, `ChalNaNavAction`, `ChalNaCard`, `ChalNaEmptyState`, `ChalNaTag`, `ChalNaButton`, `ChalNaColor`, `ChalNaTypography`, `ChalNaRadius`, `MediaThumb`.
- Produces: 없음 (화면). `HomeFeature` 액션(`onAppear`/`newVlogButtonTapped`/`settingsButtonTapped`/`filmTapped(filmID:)`)은 변경하지 않는다.

- [ ] **Step 1: HomeView 전체 재작성**

`Modules/HomeFeature/Sources/HomeView.swift` 전체를 교체한다:

```swift
import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem
import SwiftData

/// 앱 루트 화면.
///
/// 재방문 사용자에게 가치 있는 것은 **만든 필름**이므로 라이브러리를 주역으로 둔다.
/// 앱 설명은 빈 상태에서만 필요하다.
/// CTA 는 `safeAreaInset` 하단 고정 — 스크롤 안에 두면 필름이 늘수록 화면 밖으로 밀린다.
public struct HomeView: View {
    @Environment(AppLanguageStore.self) private var languageStore
    let store: StoreOf<HomeFeature>

    @Query(sort: [SortDescriptor(\Film.createdAt, order: .reverse)])
    private var films: [Film]

    public init(store: StoreOf<HomeFeature> = Store(initialState: HomeFeature.State()) { HomeFeature() }) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            ChalNaNavBar(
                verbatimTitle: "ChalNa",
                trailing: .icon(.settings, accessibilityLabel: "설정") {
                    store.send(.settingsButtonTapped)
                }
            )
            .zIndex(1)

            if films.isEmpty {
                emptyLibrary
            } else {
                libraryGrid
            }
        }
        .chalNaScreen()
        .safeAreaInset(edge: .bottom) { primaryAction }
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Empty state

    private var emptyLibrary: some View {
        ScrollView {
            VStack(spacing: 16) {
                ChalNaEmptyState(
                    icon: .film,
                    title: "아직 만든 필름이 없어요",
                    message: "Live Photo와 짧은 영상을 촬영일 순서로 이어붙여\n한 편의 필름처럼 기록해요."
                )

                // 비한국어 UI 에서만 앱 이름 뜻풀이를 덧붙인다. 빈 상태 한정 —
                // 라이브러리가 채워진 뒤에는 설명이 화면을 차지할 이유가 없다.
                if !languageStore.isKoreanUI {
                    ChalNaCard {
                        Text("'찰나'는 아주 짧은 순간이라는 뜻이에요.")
                            .font(ChalNaTypography.label)
                            .foregroundColor(ChalNaColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Library

    private var libraryGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("최근 필름")
                        .font(ChalNaTypography.title)
                        .foregroundColor(ChalNaColor.textPrimary)
                    Spacer()
                    ChalNaTag(String(localized: "\(films.count)편"), variant: .neutral)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                    spacing: 16
                ) {
                    ForEach(Array(films.enumerated()), id: \.element.id) { index, film in
                        Button {
                            store.send(.filmTapped(filmID: film.id))
                        } label: {
                            FilmPosterCard(film: film, fallbackIndex: index)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: "\(film.title), \(film.metaLabel)"))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Primary CTA (하단 고정)

    private var primaryAction: some View {
        Button {
            store.send(.newVlogButtonTapped)
        } label: {
            HStack(spacing: 8) {
                ChalNaIcon(.plus, size: 18, weight: .semibold)
                Text("새 Vlog 만들기")
            }
        }
        .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(ChalNaColor.bg.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(ChalNaColor.border).frame(height: 1)
        }
        .accessibilityLabel("새 Vlog 만들기")
    }
}

/// 라이브러리 필름 카드.
///
/// 썸네일 비율을 **9:16 으로 맞춘다** — 실제 출력물과 FilmDetail 이 9:16 인데
/// 기존 Home 만 96×54(16:9)라 여기서만 결과물과 다르게 잘려 보였다.
private struct FilmPosterCard: View {
    let film: Film
    let fallbackIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MediaThumb(state: .normal) {
                thumbnail
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: film.title)
                    .font(ChalNaTypography.headline)
                    .foregroundColor(ChalNaColor.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(verbatim: film.metaLabel)
                    .font(ChalNaTypography.caption)
                    .foregroundColor(ChalNaColor.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = film.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            fallbackPreset.view()
        }
    }

    /// 폴백 프리셋을 12종 전부에서 고른다 (기존에는 6종만 썼다).
    private var fallbackPreset: ThumbnailPreset {
        let pool = ThumbnailPreset.allCases
        return pool[fallbackIndex % pool.count]
    }
}

#Preview("Home — 빈 상태") {
    HomeView()
        .environment(EditSession())
        .environment(AppLanguageStore())
        .modelContainer(for: Film.self, inMemory: true)
}
```

> 삭제한 것: `hero`(카피 3줄), `recentFilmsSection` 내 `emptyState`, `FilmRow`(16:9 행).
> `.font(.system(size:))` 직접 호출 9곳과 `Image(systemName: "gearshape")`·
> `Image(systemName: "plus")` 가 함께 사라진다.
> `frame(height: 40)` 헤더(감사 #3)도 `ChalNaNavBar` 로 교체돼 사라진다.

- [ ] **Step 2: 빈 상태와 채워진 상태를 둘 다 스크린샷**

`ChalNa Dev` 스킴으로 실행하면 fixture 로 필름을 만들 수 있다.
먼저 빈 상태(앱 삭제 후 첫 실행):

```bash
xcrun simctl uninstall "iPhone 17 Pro" ios.inho.ChalNa 2>/dev/null || true
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           -derivedDataPath /tmp/chalna-build build 2>&1 | grep -E "error:" | sort -u
xcrun simctl install "iPhone 17 Pro" /tmp/chalna-dd/Build/Products/Debug-iphonesimulator/ChalNa.app
xcrun simctl launch --console-pty "iPhone 17 Pro" ios.inho.ChalNa &
sleep 4
xcrun simctl io "iPhone 17 Pro" screenshot /tmp/p3-home-empty.png
open /tmp/p3-home-empty.png
```

확인할 것: 빈 상태 문구가 중앙 정렬로 읽히는가, CTA 가 하단에 고정돼 있는가,
CTA 위 hairline 이 보이는가.

- [ ] **Step 3: 필름 1편 이상 만들고 그리드 확인**

`ChalNa Dev` 스킴(devMock)으로 홈 → 새 Vlog → fixture 2개 선택 → Timeline → 저장 →
Export 완료까지 진행한 뒤 홈으로 돌아온다. 그 다음:

```bash
xcrun simctl io "iPhone 17 Pro" screenshot /tmp/p3-home-grid.png
open /tmp/p3-home-grid.png
```

확인할 것 (**이 태스크의 핵심**):
1. 포스터 카드가 **9:16 세로 비율**인가 (16:9 가로가 아님)
2. 카드 썸네일이 실제 완성 영상의 첫 프레임과 같은 프레이밍인가
3. 2열 그리드 간격이 균일한가
4. 제목이 2줄까지 늘어나도 카드 높이가 어긋나지 않는가

- [ ] **Step 4: 커밋**

```bash
git add Modules/HomeFeature/Sources/HomeView.swift
git commit -m "$(cat <<'EOF'
💄 style(Home): 위계 반전 — 라이브러리를 주역으로

- 히어로 카피 3줄 삭제. 앱 설명은 빈 상태에서만 노출
  (비한국어 '찰나' 뜻풀이 박스도 빈 상태 한정으로 이동)
- 필름 목록을 16:9 리스트 행 → 2열 9:16 포스터 그리드로.
  기존 96×54(16:9)는 실제 출력물·FilmDetail(9:16)과 비율이 달라
  Home 에서만 결과물과 다르게 잘려 보였다
- CTA 를 safeAreaInset 하단 고정 — 스크롤 안에 있어 필름이 늘면 밀려나던 문제
- 헤더 frame(height: 40) 초과 문제를 ChalNaNavBar 로 해소
- 폴백 ThumbnailPreset 을 6종 → 12종 전부로
- .font(.system(...)) 9곳, Image(systemName:) 2곳 제거

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 18: MediaPickerView · MediaPreviewSheet — 순서 반전

**Files:**
- Modify: `Modules/MediaPickerFeature/Sources/MediaPickerView.swift`
- Modify: `Modules/MediaPickerFeature/Sources/MediaPreviewSheet.swift`

**Interfaces:**
- Consumes: `ChalNaNavBar`, `ChalNaNavAction`, `ChalNaCard`, `ChalNaTag`, `MediaThumb`, `ChalNaTextField`, `ChalNaBlockingOverlay`, `ChalNaButton`, `ChalNaIcon`.
- Produces: 없음 (화면). `MediaPickerFeature` 액션은 변경하지 않는다.

- [ ] **Step 1: 본문 순서를 반전하고 제목을 조건부로**

`MediaPickerView.body` 의 `ScrollView` 내부 `VStack` 을 다음 순서로 바꾼다:

```swift
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro
                        .trackScrollOffset(in: "media-picker-scroll")
                        .simultaneousGesture(TapGesture().onEnded { dismissTitleKeyboard() })

                    pickerLauncher
                        .simultaneousGesture(TapGesture().onEnded { dismissTitleKeyboard() })

                    selectionGrid
                        .simultaneousGesture(TapGesture().onEnded { dismissTitleKeyboard() })

                    // 제목은 고른 뒤에 붙인다. 선택이 0개면 물을 이유가 없다.
                    if selectedCount > 0 {
                        titleField
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
```

개별 섹션에 붙어 있던 `.padding(.horizontal, 24)` / `.padding(.top, 24)` / `.padding(.top, 12)` 는
**전부 제거**한다 (컨테이너가 여백을 갖는다).

- [ ] **Step 2: 헤더·intro 를 로컬라이즈 카피로 교체**

```swift
    private var header: some View {
        ChalNaNavBar(
            title: "미디어 선택",
            leading: .back {
                dismissTitleKeyboard()
                store.send(.dismissTapped)
            }
        )
        .chalNaScrollHairline(progress: store.scrollProgress)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            introHeadline
                .foregroundColor(ChalNaColor.textPrimary)
            Text("Live Photo와 짧은 영상을 불러올 수 있어요.\nLive Photo는 내부의 영상 부분을 사용합니다.")
                .font(ChalNaTypography.label)
                .foregroundColor(ChalNaColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 첫 줄(display)·둘째 줄(title) 폰트가 달라 Text 두 개를 합치지만,
    /// 로컬라이즈 키는 합쳐진 한 문장이라 번역을 가져와 \n 기준으로 쪼갠다.
    private var introHeadline: Text {
        let full = String(localized: "찰나의 순간을\n천천히 골라보세요.")
        let lines = full.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        let first = String(lines.first ?? "")
        let second = lines.count > 1 ? String(lines[1]) : ""
        return Text(verbatim: first + "\n").font(ChalNaTypography.display)
             + Text(verbatim: second).font(ChalNaTypography.title)
    }
```

`body` 의 `header` 호출부에서 `.padding(.horizontal, 16).padding(.vertical, 12).chalNaHeaderBar(...)` 를 제거하고
`.simultaneousGesture(...)` 와 `.zIndex(1)` 만 남긴다.

**삭제:** `Text("PICK · YOUR CHALNA").tagLabel()` — 영문 고정 태그(감사 #23).
서브타이틀 `"LIVE · VIDEO"` 도 삭제(정보가치 없음).

- [ ] **Step 3: 제목 필드를 ChalNaTextField 로 교체**

```swift
    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            ChalNaTextField(
                label: String(localized: "이번 찰나 모음집의 제목"),
                placeholder: String(localized: "예: 제주도, 우리의 봄"),
                helper: String(localized: "비워두면 나중에 자동으로 채워져요."),
                text: $store.titleInput.sending(\.titleChanged)
            )
        }
    }
```

기존 `titleField` 의 `@FocusState private var isTitleFocused` 기반 커스텀 TextField 전체를
위 6줄로 대체한다. `dismissTitleKeyboard()` 는 `isTitleFocused = false` 대신
다음으로 바꾼다 (ChalNaTextField 가 자체 FocusState 를 갖기 때문):

```swift
    private func dismissTitleKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
```

`@FocusState private var isTitleFocused: Bool` 프로퍼티는 삭제한다.

- [ ] **Step 4: 그리드 셀을 비율 기반으로 교체**

`photoGrid` 의 `LazyVGrid` 내부를 교체한다:

```swift
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                    spacing: 10
                ) {
                    ForEach(Array(selectedAssets.enumerated()), id: \.element.id) { idx, asset in
                        MediaThumb(state: .selected) {
                            photoThumbnail(for: asset)
                        }
                        .overlay(alignment: .topLeading) {
                            kindTag(for: asset.kind)
                                .padding(4)
                                .allowsHitTesting(false)
                        }
                        .overlay(alignment: .topTrailing) {
                            removeBadge(for: asset)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissTitleKeyboard()
                            store.send(.previewRequested(asset))
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel(thumbnailAccessibilityLabel(for: asset, index: idx, isSelected: true))
                        .accessibilityHint("탭하면 미리보기가 열려요")
                        .accessibilityAction {
                            store.send(.previewRequested(asset))
                        }
                        .accessibilityAction(named: Text("선택에서 제외")) {
                            store.send(.photoAssetTapped(asset))
                        }
                    }
                }
                .padding(.top, 12)
```

`kindChip(for:)` 을 `kindTag(for:)` 로 바꾼다:

```swift
    @ViewBuilder
    private func kindTag(for kind: PhotoLibraryAssetKind) -> some View {
        switch kind {
        case .livePhoto: ChalNaTag("LIVE", variant: .live)
        case .video:     ChalNaTag("VIDEO", variant: .video, icon: .video)
        case .image, .unknown: EmptyView()
        }
    }
```

> **제거된 것:** `size: CGSize(width: 84, height: 108)` 고정 크기(3열 flexible 과 폭 불일치),
> 그리고 칩을 억지로 맞추던 `.scaleEffect(0.78, anchor: .topLeading).fixedSize(...).offset(x: -5, y: -7)`.
> `MediaThumb` 이 `aspectRatio(9/16)` 로 열 폭을 따르고 `ChalNaTag` 가 이미 작다.

- [ ] **Step 5: 제거 배지를 44pt 히트로**

```swift
    /// 선택 제외 X 버튼. 본문 탭(미리보기)과 분리된 히트 영역 44pt.
    private func removeBadge(for asset: PhotoLibraryAsset) -> some View {
        Button {
            dismissTitleKeyboard()
            store.send(.photoAssetTapped(asset))
        } label: {
            ChalNaIcon(.close, size: 11, weight: .bold)
                .foregroundColor(ChalNaColor.onAccent)
                .frame(width: 24, height: 24)
                .background(Circle().fill(ChalNaColor.accentFill))
                .overlay(Circle().strokeBorder(ChalNaColor.canvas.opacity(0.4), lineWidth: 1))
                .frame(width: 44, height: 44, alignment: .topTrailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("선택에서 제외")
        .accessibilityHint("\(asset.kind == .video ? String(localized: "비디오") : String(localized: "라이브 포토"))를 선택에서 빼요")
    }
```

- [ ] **Step 6: 로딩 오버레이·하단바·나머지 토큰 치환**

`pickedMediaLoadingOverlay` 전체를 다음으로 대체한다:

```swift
    @ViewBuilder
    private var pickedMediaLoadingOverlay: some View {
        ChalNaBlockingOverlay(
            title: "사진을 불러오는 중",
            detail: "Live Photo와 영상을 정성껏 추출하고 있어요",
            progressText: loadingProgressText,
            accessibilityLabel: "사진을 불러오는 중이에요"
        )
    }

    /// total 자릿수에 맞춰 done 을 0 패딩 (총 12개 → "05 / 12", 총 9개 → "5 / 9").
    private var loadingProgressText: String? {
        guard let progress = store.preparingPickedMediaProgress, progress.total > 0 else { return nil }
        let doneText = String(format: "%0\(String(progress.total).count)d", progress.done)
        return "\(doneText) / \(progress.total)"
    }
```

`bottomActionArea` 의 `Color.white` → `ChalNaColor.bg`, `ChalNaColor.Gray.g200` → `ChalNaColor.border`,
`.padding(.horizontal, 16)` → `20`.

`chalNaBottomBar` 의 버튼 스타일을 교체한다:

```swift
    private var chalNaBottomBar: some View {
        HStack(spacing: 10) {
            Button {
                dismissTitleKeyboard()
                store.send(.dismissTapped)
            } label: {
                Text("취소").frame(maxWidth: .infinity)
            }
            .buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))

            Button {
                store.send(.primaryActionTapped)
            } label: {
                confirmBottomLabel.frame(maxWidth: .infinity)
            }
            .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
            .disabled(!canUsePrimaryAction || store.isResolving)
        }
    }
```

`confirmBottomLabel` 의 `ProgressView().tint(ChalNaColor.Gray.g900)` → `.tint(ChalNaColor.onAccent)`.

나머지: `photoLauncher`·`devLauncher`·`photoThumbnail`·`DevMediaAssetCard`·상태 메시지 블록에
**P2 공통 마이그레이션 표**를 적용한다. 특히:
- `photoThumbnail` 의 `Circle().fill(Color.white.opacity(0.92))` → `.fill(ChalNaColor.surfaceRaised.opacity(0.92))`, 내부 아이콘 색 `ChalNaColor.textPrimary`
- `"영상 X"` 배지의 `monoFallback(8)` → `ChalNaTypography.caption` (8pt 금지, 감사 #12)
- `DevMediaAssetCard` 의 `krBody(11)` → `ChalNaTypography.caption`, `ClipThumbCard` → `MediaThumb`, `ChalNaChip` → `ChalNaTag`
- `photoLauncher`/`devLauncher` 의 `RoundedRectangle().fill(Color.white)` 조합 → `ChalNaCard`

- [ ] **Step 7: MediaPreviewSheet 다크 전환**

`Modules/MediaPickerFeature/Sources/MediaPreviewSheet.swift`:

| 기존 | 변경 |
|---|---|
| `Color.white.ignoresSafeArea()` | `ChalNaColor.surfaceRaised.ignoresSafeArea()` |
| `ChalNaColor.Gray.g900` (stage 배경) | `ChalNaColor.canvas` |
| `ChalNaChip(...)` | `ChalNaTag(...)` |
| `Circle().fill(Color.white.opacity(0.92))` (pausedOverlay) | `Circle().fill(ChalNaColor.surfaceRaised.opacity(0.92))` + 아이콘 `ChalNaColor.textPrimary` |
| `monoFallback(13, weight: .medium)` | `ChalNaTypography.mono()` |
| `krBody(13, weight: .medium)` (실패 문구) | `ChalNaTypography.label`, 색 `ChalNaColor.textPrimary` |
| `krBody(12)` (hint) | `ChalNaTypography.caption` |
| `ProgressView().tint(ChalNaColor.Purple.p600)` | `.tint(ChalNaColor.accent)` |
| `ChalNaColor.Gray.g50.opacity(0.2)` (썸네일 폴백) | `ChalNaColor.surface` |
| `ChalNaRadius.sheet` / `.card` | `ChalNaRadius.lg` / `.md` |
| `.padding(.horizontal, 24)` | `20` |

추가: `.presentationBackground(ChalNaColor.surfaceRaised)` 를 시트 modifier 체인에 넣는다.

- [ ] **Step 8: 빌드 후 devMock 으로 전 플로 스크린샷**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           -derivedDataPath /tmp/chalna-build build 2>&1 | grep -E "error:" | sort -u
xcrun simctl install "iPhone 17 Pro" /tmp/chalna-dd/Build/Products/Debug-iphonesimulator/ChalNa.app
xcrun simctl terminate "iPhone 17 Pro" ios.inho.ChalNa 2>/dev/null || true
xcrun simctl launch "iPhone 17 Pro" ios.inho.ChalNa --CHALNA_APP_MODE devMock
```

`ChalNa Dev` 스킴으로 Xcode 에서 실행하는 것이 더 확실하다 (환경변수가 스킴에 정의돼 있다).

홈 → 새 Vlog 로 이동해 스크린샷 3장:

```bash
xcrun simctl io "iPhone 17 Pro" screenshot /tmp/p3-picker-empty.png   # 선택 0개
# fixture 2개 선택 후
xcrun simctl io "iPhone 17 Pro" screenshot /tmp/p3-picker-selected.png
# 썸네일 탭 → 미리보기 시트
xcrun simctl io "iPhone 17 Pro" screenshot /tmp/p3-preview-sheet.png
open /tmp/p3-picker-empty.png /tmp/p3-picker-selected.png /tmp/p3-preview-sheet.png
```

확인할 것 (**이 태스크의 핵심**):
1. **선택 0개 화면에 제목 입력 필드가 없다**
2. 선택 후 제목 필드가 그리드 **아래**에 나타난다
3. 영문 태그("PICK · YOUR CHALNA")가 없다
4. 그리드 셀이 열 폭을 채우고 3열 간격이 균일하다 (고정 84pt 로 인한 빈틈 없음)
5. LIVE/VIDEO 태그가 셀 좌상단에 자연스럽게 놓인다 (scaleEffect 로 억지로 줄인 흔적 없음)
6. 미리보기 시트 배경이 어둡다 (시스템 기본 밝은 재질이 아님)

- [ ] **Step 9: 커밋**

```bash
git add Modules/MediaPickerFeature/Sources/
git commit -m "$(cat <<'EOF'
💄 style(MediaPicker): 순서 반전 + 다크 전환

- 본문 순서를 ① 사진 추가 → ② 선택 그리드 → ③ 제목 으로 반전.
  제목 필드는 선택이 1개 이상일 때만 노출 (0개일 때 물을 이유가 없다)
- 영문 고정 태그(PICK · YOUR CHALNA / TITLE ·) 삭제 — i18n 3개 언어에서
  영문으로 고정돼 있었다. 서브타이틀 LIVE · VIDEO 도 정보가치 없어 삭제
- 그리드 셀 84×108 고정 → MediaThumb aspectRatio(9:16)로 열 폭 추종.
  칩을 억지로 맞추던 scaleEffect(0.78)+offset(-5,-7) 제거
- 제거(X) 배지 히트 40 → 44pt
- 로딩 오버레이를 ChalNaBlockingOverlay 로 이관
- 8pt "영상 X" 배지와 11pt 카드 캡션을 12pt 하한으로
- MediaPreviewSheet 다크 전환 + presentationBackground 지정

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 19: FilmDetailView

**Files:**
- Modify: `Modules/FilmDetailFeature/Sources/FilmDetailView.swift`

**Interfaces:**
- Consumes: `ChalNaNavBar`, `ChalNaNavAction`, `ChalNaTag`, `ChalNaNotice`, `ChalNaEmptyState`, `ChalNaButton`, `ChalNaIcon`, `chalNaScrollHairline`.
- Produces: 없음 (화면). `FilmDetailFeature` 액션 불변.

- [ ] **Step 1: 헤더·포스터를 교체**

```swift
    private var header: some View {
        ChalNaNavBar(
            title: "필름 정보",
            leading: .back { store.send(.backTapped) }
        )
        .chalNaScrollHairline(progress: scrollProgress)
    }
```

`body` 의 header 호출부에서 `.padding(.horizontal, 16).padding(.vertical, 12).chalNaHeaderBar(...)` 제거.

포스터를 **폭 상한 먼저 + aspectRatio** 로 바꾼다:

```swift
    /// 9:16 출력 비율 포스터.
    ///
    /// ScrollView 안에서는 높이 제안이 무한이라 `aspectRatio(.fit)` 이 폭을 역산해
    /// 레이아웃이 부풀 수 있다. **폭 상한을 먼저 확정**하면 높이 역산이 안전하다.
    /// (기존에는 이걸 300pt 고정으로 우회했다)
    private func posterHero(for film: Film, isPlayable: Bool) -> some View {
        ZStack(alignment: .bottomTrailing) {
            posterThumbnail(for: film, isPlayable: isPlayable)
            durationBadge(for: film).padding(12)
        }
        .frame(maxWidth: 240)
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    private func posterThumbnail(for film: Film, isPlayable: Bool) -> some View {
        ZStack {
            ChalNaColor.canvas

            if let data = film.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ThumbnailPreset.jejuOrange.view()
            }

            // 파일이 사라진 필름은 포스터를 덮어 재생 불가 상태를 즉시 알린다.
            if !isPlayable {
                ChalNaColor.scrim
                ChalNaIcon(.film, size: 40, weight: .light)
                    .foregroundColor(ChalNaColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ChalNaRadius.md, style: .continuous)
                .strokeBorder(ChalNaColor.border, lineWidth: 1)
        )
    }

    private func durationBadge(for film: Film) -> some View {
        ChalNaTag(Self.durationLabel(film.totalDurationSeconds), variant: .neutral)
            .accessibilityLabel(Text(verbatim: "총 길이 \(Self.durationLabel(film.totalDurationSeconds))"))
    }
```

`.chalNaShadow(ChalNaShadow.md)` 는 **제거**한다 (다크에서 무의미).

- [ ] **Step 2: 메타 3칼럼 카드를 태그 한 줄로 압축**

`metaGrid(for:)` 와 `metaCell(label:value:)` 을 **삭제**하고 다음으로 대체한다:

```swift
    /// 클립 / Live / Video 를 태그 한 줄로. 카드 3개는 정보량 대비 과했고,
    /// 그 공간을 포스터에 돌려준다.
    private func metaTags(for film: Film) -> some View {
        let videoCount = max(film.clipCount - film.liveCount, 0)
        return HStack(spacing: 8) {
            ChalNaTag(String(localized: "클립 \(film.clipCount)"), variant: .neutral)
            ChalNaTag(String(localized: "Live \(film.liveCount)"), variant: .live)
            ChalNaTag(String(localized: "Video \(videoCount)"), variant: .video, icon: .video)
            Spacer(minLength: 0)
        }
    }
```

`content(for:)` 의 `metaGrid(for: film)` 호출을 `metaTags(for: film)` 으로 바꾼다.

- [ ] **Step 3: 타이틀·안내·액션 버튼 교체**

```swift
    private func titleBlock(for film: Film) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: film.title)
                .font(ChalNaTypography.display)
                .foregroundColor(ChalNaColor.textPrimary)
                .lineLimit(3)

            Text(film.createdAt, format: .dateTime.year().month().day().weekday())
                .font(ChalNaTypography.label)
                .foregroundColor(ChalNaColor.textSecondary)
                .lineLimit(2)
        }
    }

    private var missingFileNotice: some View {
        ChalNaNotice(
            icon: .film,
            title: "영상 파일을 찾을 수 없어요",
            message: "앱을 다시 설치하셨거나 파일이 삭제되었어요. 재생과 공유는 불가능하고, 라이브러리에서 항목을 정리할 수 있어요."
        )
    }

    private func actionButtons(canPlayOrShare: Bool) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    store.send(.playTapped)
                } label: {
                    HStack(spacing: 8) {
                        ChalNaIcon(.play, size: 16, weight: .semibold)
                        Text("재생")
                    }
                }
                .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
                .disabled(!canPlayOrShare)
                .accessibilityLabel(canPlayOrShare ? "재생" : "재생 (파일 없음)")

                Button {
                    store.send(.shareTapped)
                } label: {
                    HStack(spacing: 8) {
                        ChalNaIcon(.share, size: 16, weight: .semibold)
                        Text("공유")
                    }
                }
                .buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))
                .disabled(!canPlayOrShare)
                .accessibilityLabel(canPlayOrShare ? "공유" : "공유 (파일 없음)")
            }

            // 파괴적 액션은 ghost + destructive 로 1차 CTA 와 위계를 분리한다.
            // (기존에는 .chalNa(.text) 가 coral 고정이라 커스텀 라벨로 우회했다)
            Button {
                store.send(.deleteTapped)
            } label: {
                HStack(spacing: 8) {
                    ChalNaIcon(.trash, size: 16, weight: .semibold)
                    Text("필름 삭제")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.chalNa(.ghost, size: .lg, fillWidth: true, destructive: true))
            .accessibilityLabel("필름 삭제")
        }
    }

    private var missingFilmState: some View {
        ChalNaEmptyState(
            icon: .film,
            title: "필름을 찾을 수 없어요",
            message: "이미 삭제되었거나 다른 기기에서 동기화 중일 수 있어요.",
            actionTitle: "홈으로"
        ) {
            store.send(.backTapped)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
```

`content(for:)` 의 `.padding(.horizontal, 24)` → `20`.

- [ ] **Step 4: 플레이어·공유 시트 다크 처리**

`content(for:)` 의 `.sheet(isPresented: $store.isPlayerPresented...)` 블록에서
`VideoPlayerCover` 를 `ZStack { ChalNaColor.canvas.ignoresSafeArea(); VideoPlayerCover(...) }` 로 감싸고
`.presentationBackground(ChalNaColor.canvas)` 를 추가한다.

- [ ] **Step 5: 빌드 후 스크린샷 (정상 + 파일 없음 상태)**

정상 상태: 홈에서 필름 카드 탭.

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           -derivedDataPath /tmp/chalna-build build 2>&1 | grep -E "error:" | sort -u
xcrun simctl install "iPhone 17 Pro" /tmp/chalna-dd/Build/Products/Debug-iphonesimulator/ChalNa.app
xcrun simctl terminate "iPhone 17 Pro" ios.inho.ChalNa 2>/dev/null || true
xcrun simctl launch "iPhone 17 Pro" ios.inho.ChalNa
# 홈 → 필름 카드 탭
xcrun simctl io "iPhone 17 Pro" screenshot /tmp/p3-filmdetail.png
open /tmp/p3-filmdetail.png
```

확인할 것:
1. 포스터·제목·태그 한 줄·버튼 3개가 **한 화면에 다 들어오는가** (기존 카드 3개는 스크롤을 만들었다)
2. 포스터가 9:16 이고 폭 상한 240pt 안에 있는가
3. "필름 삭제" 가 danger 톤 ghost 이고 재생(primary)과 위계가 분리되는가

**파일 없음 상태 검증** (선택): 시뮬레이터 컨테이너에서 mp4 를 지운다.

```bash
CONTAINER=$(xcrun simctl get_app_container "iPhone 17 Pro" ios.inho.ChalNa data)
rm -f "$CONTAINER/Documents/films/"*.mp4
xcrun simctl terminate "iPhone 17 Pro" ios.inho.ChalNa
xcrun simctl launch "iPhone 17 Pro" ios.inho.ChalNa
# 홈 → 필름 카드 탭
xcrun simctl io "iPhone 17 Pro" screenshot /tmp/p3-filmdetail-missing.png
open /tmp/p3-filmdetail-missing.png
```

확인할 것: 안내 카드가 맨 위에 나오고, 포스터가 scrim 으로 덮이고,
재생·공유 버튼이 `textTertiary` 로 비활성인가.

- [ ] **Step 6: 커밋**

```bash
git add Modules/FilmDetailFeature/Sources/FilmDetailView.swift
git commit -m "$(cat <<'EOF'
💄 style(FilmDetail): 포스터 고정 300pt 제거 + 메타 압축

- 포스터: frame(maxWidth: 240) 로 폭을 먼저 확정한 뒤 aspectRatio(9:16).
  기존 주석의 진단("ScrollView 에서 aspectRatio 가 폭을 역산해 깨진다")은
  정확했지만 해법이 300pt 고정이었다
- 메타 3칼럼 카드 → ChalNaTag 3개 한 줄. 그 공간을 포스터에 돌려줌
- 삭제 버튼을 ChalNaButton(.ghost, destructive:)로 — 커스텀 라벨 우회 제거
- 안내/빈 상태를 ChalNaNotice / ChalNaEmptyState 로 이관
- 플레이어 시트 배경을 canvas 로 지정

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 20: ExportView — 커버와 진행률 통합

**Files:**
- Modify: `Modules/ExportFeature/Sources/ExportView.swift`

**Interfaces:**
- Consumes: `ChalNaNavBar`, `ChalNaCanvas`, `ChalNaProgressBar`, `ChalNaTag`, `ChalNaButton`, `ChalNaIcon`, `chalNaToast`.
- Produces: 없음 (화면). `ExportFeature` 액션 불변.

- [ ] **Step 1: GeometryReader + reservedHeight 마법숫자를 제거**

`body` 를 다음 구조로 교체한다:

```swift
    public var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                cover
                    .padding(.horizontal, 20)

                Spacer(minLength: 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .chalNaScreen()
        .safeAreaInset(edge: .bottom) { bottomCTAs }
        .chalNaToast(message: store.saveToast) { store.send(.toastDismissed) }
        .onAppear { /* 기존 그대로 */ }
        // 나머지 modifier 체인(onDisappear / onChange / fullScreenCover)은 기존 유지
    }
```

**삭제:** `coverWidth(forAvailableHeight:)` 함수 전체(`reservedHeight` 210/300/290 포함),
`statusBlock`, `statusLabelLeft`.

- [ ] **Step 2: 헤더를 ChalNaNavBar 로**

```swift
    private var header: some View {
        // ExportPhase.title/.tag 는 String(localized:) 로 이미 해석된 String 이다
        // (ExportFeature.swift:256,264). 다시 감싸면 이중 조회가 된다.
        ChalNaNavBar(
            verbatimTitle: store.phase.title,
            caption: store.phase.tag,
            showsDivider: true
        )
    }
```

> **타입 확정(사전 확인 완료).** `ExportPhase.title`·`.tag` 는 둘 다 `String(localized:)` 로
> 이미 해석된 `String` 이다. `verbatimTitle:`·`caption:`(String?) 에 그대로 넘긴다.
> `tagColor` 함수는 caption 색이 고정(`textSecondary`)으로 바뀌므로 **삭제**한다.

- [ ] **Step 3: 커버에 진행률을 얹는다 — 이 태스크의 핵심**

```swift
    /// 9:16 커버. 진행률·완료 배지를 **커버 위에** 얹어 시선을 한 곳에 모은다.
    /// (기존에는 커버와 statusBlock 이 분리돼 시선이 두 곳으로 갈렸다)
    @ViewBuilder
    private var cover: some View {
        if let clip = session.clips.first {
            let canPlay = store.phase == .done && store.exportedURL != nil

            VStack(alignment: .leading, spacing: 12) {
                ChalNaCanvas { box in
                    clip.thumbnailView(contentMode: .fill)
                        .frame(width: box.width, height: box.height)
                } overlay: { _ in
                    coverOverlay(canPlay: canPlay)
                }
                .frame(maxWidth: 300)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard canPlay else { return }
                    store.send(.playerPresentedChanged(true))
                }
                .accessibilityAddTraits(canPlay ? .isButton : [])
                .accessibilityLabel(canPlay ? "완성된 영상 재생" : "")

                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: session.title.isEmpty ? SampleData.filmTitle : session.title)
                        .font(ChalNaTypography.title)
                        .foregroundColor(ChalNaColor.textPrimary)
                        .lineLimit(1)
                    Text(verbatim: metaLine)
                        .font(ChalNaTypography.mono())
                        .foregroundColor(ChalNaColor.textSecondary)
                    Text(statusLine)
                        .font(ChalNaTypography.label)
                        .foregroundColor(ChalNaColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 300, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        } else {
            Text("내보낼 클립이 없어요")
                .font(ChalNaTypography.headline)
                .foregroundColor(ChalNaColor.textSecondary)
        }
    }

    /// 커버 위 오버레이: 진행 중이면 하단 진행률 바 + 퍼센트, 완료면 재생 버튼 + DONE 태그.
    @ViewBuilder
    private func coverOverlay(canPlay: Bool) -> some View {
        ZStack {
            if canPlay {
                playOverlay
            }

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if store.phase == .done {
                        ChalNaTag("DONE", variant: .accent, icon: .check)
                    }
                }
                .padding(12)

                Spacer()

                if store.phase != .done {
                    VStack(spacing: 6) {
                        HStack {
                            Text(verbatim: "\(Int(store.progress * 100))%")
                                .font(ChalNaTypography.mono(.footnote, weight: .semibold))
                                .foregroundColor(ChalNaColor.textPrimary)
                            Spacer()
                        }
                        ChalNaProgressBar(
                            progress: store.progress,
                            tint: store.phase == .failed ? ChalNaColor.danger : ChalNaColor.accent
                        )
                    }
                    .padding(12)
                    .background(ChalNaColor.scrim)
                }
            }
        }
    }

    private var playOverlay: some View {
        ZStack {
            ChalNaColor.scrim.opacity(0.4)
            Circle()
                .fill(ChalNaColor.surfaceRaised.opacity(0.9))
                .frame(width: 64, height: 64)
                .overlay(Circle().strokeBorder(ChalNaColor.border, lineWidth: 1))
                .overlay(
                    ChalNaIcon(.play, size: 26, weight: .semibold)
                        .foregroundColor(ChalNaColor.textPrimary)
                )
        }
    }
```

- [ ] **Step 4: 완료 CTA 위계를 분리**

```swift
    @ViewBuilder
    private var bottomCTAs: some View {
        Group {
            switch store.phase {
            case .idle, .exporting:
                HStack(spacing: 8) {
                    ChalNaIcon(.film, size: 14)
                    Text("잠깐만 기다려주세요")
                }
                .font(ChalNaTypography.label)
                .foregroundColor(ChalNaColor.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)

            case .done:
                completedCTAs

            case .failed:
                failedCTAs
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(ChalNaColor.bg.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(ChalNaColor.border).frame(height: 1)
        }
    }

    /// 주 액션 2개(저장·공유)를 면형/선형으로, 보조 2개는 ghost 텍스트로 내려
    /// 위계를 분리한다. 기존에는 4개가 2×2 로 동등해 무엇이 주인지 불명확했다.
    private var completedCTAs: some View {
        VStack(spacing: 8) {
            if let url = store.exportedURL {
                HStack(spacing: 10) {
                    Button {
                        store.send(.saveToPhotoLibraryTapped)
                    } label: {
                        HStack(spacing: 6) {
                            if store.isSaving {
                                ProgressView().controlSize(.small).tint(ChalNaColor.onAccent)
                            } else {
                                ChalNaIcon(.download, size: 16, weight: .semibold)
                            }
                            Text(store.isSaving ? LocalizedStringKey("저장 중…") : LocalizedStringKey("저장하기"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
                    .disabled(store.isSaving)

                    ShareLink(item: url) {
                        HStack(spacing: 6) {
                            ChalNaIcon(.share, size: 16, weight: .semibold)
                            Text("공유")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))
                }
            }

            HStack(spacing: 4) {
                Button("다른 영상 만들기") { store.send(.startAnotherTapped) }
                    .buttonStyle(.chalNa(.ghost, size: .md, fillWidth: true))
                Button {
                    store.send(.homeTapped)
                } label: {
                    HStack(spacing: 4) {
                        Text("홈으로")
                        ChalNaIcon(.chevronRight, size: 13, weight: .semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.chalNa(.ghost, size: .md, fillWidth: true))
            }
        }
    }

    private var failedCTAs: some View {
        VStack(spacing: 8) {
            Button {
                store.send(.retryTapped(clips: session.clips,
                                        rotations: session.rotations,
                                        transforms: session.transforms,
                                        clipLabels: session.labels))
            } label: {
                Text("다시 시도").frame(maxWidth: .infinity)
            }
            .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))

            Button("편집으로 돌아가기") { store.send(.backToEditTapped) }
                .buttonStyle(.chalNa(.ghost, size: .md, fillWidth: true))
        }
    }
```

**삭제:** `paperCompletedCTAs`/`paperFailedCTAs` 래퍼(이름만 감싸던 중간 계층),
`startAnotherFilm()` 함수(`store.send` 한 줄이라 인라인).

- [ ] **Step 5: fullScreenCover 플레이어 다크 처리**

기존 `fullScreenCover` 블록의 `Color.black.ignoresSafeArea()` → `ChalNaColor.canvas.ignoresSafeArea()`,
닫기 버튼을 다음으로 교체한다:

```swift
                    Button {
                        store.send(.playerPresentedChanged(false))
                    } label: {
                        ChalNaIcon(.close, size: 18, weight: .semibold)
                            .foregroundColor(ChalNaColor.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(ChalNaColor.surfaceRaised.opacity(0.8)))
                            .overlay(Circle().strokeBorder(ChalNaColor.border, lineWidth: 1))
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 16)
                    .accessibilityLabel("재생 닫기")
```

- [ ] **Step 6: 빌드 후 SE 와 Pro Max 양쪽에서 3단계 스크린샷**

**SE 가 이 화면의 핵심 검증 기기다** — 기존 `reservedHeight` 마법숫자가 SE 에서 넘쳤다.

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
           -derivedDataPath /tmp/chalna-build build 2>&1 | grep -E "error:" | sort -u
xcrun simctl boot "iPhone SE (3rd generation)" 2>/dev/null || true
xcrun simctl install "iPhone SE (3rd generation)" \
  /tmp/chalna-se/Build/Products/Debug-iphonesimulator/ChalNa.app
xcrun simctl launch "iPhone SE (3rd generation)" ios.inho.ChalNa
```

`ChalNa Dev` 스킴으로 홈 → 새 Vlog → fixture 2개 → Timeline → 저장 을 진행하며
exporting / done 두 단계에서 각각 스크린샷:

```bash
xcrun simctl io "iPhone SE (3rd generation)" screenshot /tmp/p3-export-se-exporting.png
xcrun simctl io "iPhone SE (3rd generation)" screenshot /tmp/p3-export-se-done.png
open /tmp/p3-export-se-exporting.png /tmp/p3-export-se-done.png
```

확인할 것 (**이 태스크의 핵심**):
1. **SE 에서 커버·제목·CTA 가 모두 화면 안에 들어오는가** (기존에는 넘쳤다)
2. 진행 중에 진행률 바와 퍼센트가 **커버 하단 위에** 있는가
3. 완료 시 저장(면형)과 공유(선형)의 위계가 구별되는가
4. 보조 액션 2개가 ghost 로 내려가 주 액션과 구별되는가
5. DONE 태그가 커버 우상단에 보이는가

Pro Max 에서도 같은 두 단계를 확인한다 (커버가 300pt 상한에서 멈추는지).

- [ ] **Step 7: 커밋**

```bash
git add Modules/ExportFeature/Sources/ExportView.swift
git commit -m "$(cat <<'EOF'
💄 style(Export): 커버와 진행률 통합 + reservedHeight 마법숫자 제거

- GeometryReader + reservedHeight 210/300/290 하드코딩 삭제.
  커버는 maxWidth 300 + aspectRatio(9:16)로 남는 공간에서 자동 축소,
  CTA 는 safeAreaInset. SE .done 에서 넘치던 문제 해소
- 진행률을 커버 위 오버레이로 이동 — 커버와 statusBlock 이 분리돼
  시선이 두 곳으로 갈리던 문제 해결. 별도 statusBlock 삭제
- 완료 CTA 4개 2×2 동등 배치 → 주 2개(저장 면형 / 공유 선형) +
  보조 2개(ghost)로 위계 분리
- paperCompletedCTAs / paperFailedCTAs 이름만 감싸던 중간 계층 제거
- 플레이어 fullScreenCover 닫기 버튼 히트 36 → 44pt

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# Phase P4 — 최고 위험: Timeline 계열 (Task 21–25)

> **P4 는 SE 실측이 합격 기준이다.** 계산(스펙 §6.5)은 근사치이므로 매 태스크에서
> iPhone SE (3rd generation) 스크린샷으로 확인한다. 미달 시 1차 조정 레버는
> **필름스트립 96 → 80pt** 다.

## Task 21: FilmStripCollectionView · DaySprocket (UIKit 레이어)

**Files:**
- Modify: `Modules/TimelineFeature/Sources/Components/FilmStripCollectionView.swift`
- Modify: `Modules/TimelineFeature/Sources/Components/DaySprocket.swift`

**Interfaces:**
- Consumes: `ChalNaColor`, `ChalNaTypography.label`, `ChalNaRadius.xs`, `MediaThumb`, `ChalNaTag`.
- Produces: 없음 (내부 컴포넌트). `FilmStripCollectionView(store:session:onTapClip:)` 시그니처 불변.

- [ ] **Step 1: UIKit 배경을 토큰으로 교체 (감사 #4)**

`FilmStripCollectionView.swift:71` 을 찾아 교체한다:

```swift
        collectionView.backgroundColor = UIColor(ChalNaColor.bg)
```

> **이것이 감사 #4 의 수정이다.** 기존 `UIColor(named: "ChalNaInk") ?? .black` 은
> colorset 이 DesignSystem.framework 번들에 있고 `UIColor(named:)` 기본 조회가
> `Bundle.main`(앱)이라 **항상 nil 을 반환**해 `.black` 으로 낙하했다.
> 즉 검은 띠는 의도가 아니라 우연이었다. `UIColor(_ color: Color)` 이니셜라이저는
> 번들 조회를 하지 않으므로 이 문제가 재발하지 않는다.

`view.backgroundColor = .clear`(62줄)는 그대로 둔다 — 상위 SwiftUI 배경이 보이게 하는 의도다.

- [ ] **Step 2: 셀 높이를 96 로 줄이고 썸네일을 MediaThumb 로 교체**

`itemSize` / `groupSize`(106~114줄)의 `heightDimension: .absolute(80)` 은 **셀 내부 높이**다.
Timeline 이 `frame(height: 96)` 을 주므로 셀은 80 을 유지하고 상하 여백 8pt 씩을 갖는다.
값 변경 없이 그대로 둔다.

셀 내부(146~156줄 부근)의 다음 두 곳을 교체한다:

```swift
// LiveBadge(size: 10) 이 있던 자리 →
ChalNaTag("LIVE", variant: .live)
    .scaleEffect(0.85, anchor: .topLeading)
```

> `LiveBadge` 는 이 한 곳에서만 쓰였다. `ChalNaTag(.live)` 가 dot + 라벨을 함께 주므로
> 셀이 좁으면 dot 만 필요할 수 있다 — 스크린샷에서 잘리면 `ChalNaTag` 대신
> `Circle().fill(ChalNaColor.danger).frame(width: 6, height: 6)` 로 단순화한다.

선택 하이라이트 색(155~156줄):

```swift
                        ? ChalNaColor.accent
                        : ChalNaColor.textSecondary)
```

또한 **72줄의 `collectionView.layer.cornerRadius = 16`** 을 토큰으로 바꾼다:

```swift
        collectionView.layer.cornerRadius = ChalNaRadius.md
```

> 이 줄은 `cornerRadius: [0-9]` 패턴(콜론형)에 걸리지 않아 lint 가 못 보던 리터럴이다
> (Task 4 리뷰에서 발견 → 패턴을 `cornerRadius[:=(] *[0-9]` 로 확장했다).
> 값 16 은 새 스케일에 없으므로 가장 가까운 `md`(14)로 매핑한다. 배경이 `bg` 로 바뀌어
> 화면과 같은 색이 되므로 이 라운딩은 시각적으로 사실상 무해하다 —
> 리터럴을 없애는 것이 목적이다.

`params.visiblePath = UIBezierPath(roundedRect: cell.contentView.bounds, cornerRadius: 4)`(365줄)의
`4` 를 `ChalNaRadius.xs` 로 바꾼다:

```swift
            params.visiblePath = UIBezierPath(roundedRect: cell.contentView.bounds,
                                              cornerRadius: ChalNaRadius.xs)
```

이로써 `design-lint.sh` 의 `cornerRadius 리터럴` 예외에서 이 파일을 제거할 수 있다 — **Step 5 에서 처리**.

셀 내부에서 `ClipThumbCard` 를 쓰고 있다면 `MediaThumb` 으로 바꾼다 (state 케이스 이름은 동일).

- [ ] **Step 3: DaySprocket 다크 전환**

`Modules/TimelineFeature/Sources/Components/DaySprocket.swift` 전체를 교체한다:

```swift
import SwiftUI
import DesignSystem

/// FilmStrip 의 날짜 구분자(필름 sprocket 스타일).
/// `MM.dd` 라벨 + sprocket dot 라인. UIKit 셀(`UIHostingConfiguration`)에서도 쓰이므로 internal.
struct DaySprocket: View {
    let label: String
    let highlighted: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(verbatim: label)
                .font(ChalNaTypography.label)
                .foregroundColor(highlighted ? ChalNaColor.accent : ChalNaColor.textSecondary)
            SprocketLine(highlighted: highlighted)
                .frame(width: 2, height: 64)
        }
        .padding(.horizontal, 2)
    }
}

private struct SprocketLine: View {
    let highlighted: Bool

    var body: some View {
        GeometryReader { proxy in
            let count = max(1, Int(proxy.size.height / 8))
            VStack(spacing: 3) {
                ForEach(0..<count, id: \.self) { _ in
                    Circle()
                        .fill(highlighted ? ChalNaColor.accent : ChalNaColor.border)
                        .frame(width: 2.2, height: 2.2)
                }
            }
            .frame(width: 2.2)
            .frame(maxHeight: .infinity)
        }
    }
}
```

> 제거한 것: `ChalNaTypography.handFallback(13)` — legacy stub 의 **마지막 실사용처**였다.
> `.opacity(highlighted ? 1.0 : 0.85)` 도 제거했다 — 색 자체로 강조를 표현하므로
> 투명도를 겹칠 이유가 없다.

- [ ] **Step 4: 빌드 후 필름스트립 스크린샷**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           -derivedDataPath /tmp/chalna-build build 2>&1 | grep -E "error:" | sort -u
xcrun simctl install "iPhone 17 Pro" /tmp/chalna-dd/Build/Products/Debug-iphonesimulator/ChalNa.app
xcrun simctl terminate "iPhone 17 Pro" ios.inho.ChalNa 2>/dev/null || true
xcrun simctl launch "iPhone 17 Pro" ios.inho.ChalNa
```

`ChalNa Dev` 스킴으로 Timeline 까지 진입한 뒤:

```bash
xcrun simctl io "iPhone 17 Pro" screenshot /tmp/p4-filmstrip.png
open /tmp/p4-filmstrip.png
```

확인할 것 (**이 태스크의 핵심**):
1. **필름스트립 영역에 검은 띠가 없다** — 화면 배경과 연속돼 보인다
2. 날짜 구분자 텍스트·dot 이 보인다 (`textSecondary`, 강조 시 `accent`)
3. LIVE 태그가 셀 안에서 잘리지 않는다
4. 선택된 셀의 링이 밝은 썸네일에서도 보인다
5. long-press 드래그로 순서를 바꿀 때 lifted/ghost 상태가 구별된다

- [ ] **Step 5: design-lint 예외 정리 후 커밋**

`scripts/design-lint.sh` 의 `cornerRadius 리터럴` `check` 호출에서
`'FilmStripCollectionView.swift'` 예외 줄을 **삭제**한다 — 이 파일의 리터럴 2곳
(72줄 `layer.cornerRadius = 16`, 365줄 `visiblePath cornerRadius: 4`)을 모두 토큰화했으므로
예외가 더 필요하지 않다. 예외는 파일 단위라서 남겨두면 이 파일에 새로 들어오는
리터럴이 영구히 보이지 않게 된다.

```bash
./scripts/design-lint.sh 2>&1 | grep -E "^(✓|✗)"
```

Expected: `UIColor(named:)` 규칙이 **✓ 0건**으로 바뀐다.

```bash
git add Modules/TimelineFeature/Sources/Components/FilmStripCollectionView.swift \
        Modules/TimelineFeature/Sources/Components/DaySprocket.swift \
        scripts/design-lint.sh
git commit -m "$(cat <<'EOF'
🐛 fix(Timeline): 필름스트립 검은 띠 제거 (UIColor(named:) 항상 nil)

- collectionView.backgroundColor 를 UIColor(ChalNaColor.bg) 로.
  기존 UIColor(named: "ChalNaInk") ?? .black 은 colorset 이
  DesignSystem.framework 번들에 있고 기본 조회가 Bundle.main 이라
  항상 nil → .black 으로 낙하했다. 검은 띠는 의도가 아니라 우연이었다
- visiblePath cornerRadius 리터럴 4 → ChalNaRadius.xs
- LiveBadge 마지막 사용처를 ChalNaTag(.live) 로 교체
- DaySprocket 다크 전환 + handFallback legacy stub 마지막 사용처 제거

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 22: PreviewPanel · ScrubBar · TransportControls · EditToolbar

**Files:**
- Modify: `Modules/TimelineFeature/Sources/Components/PreviewPanel.swift` (전체 재작성)
- Modify: `Modules/TimelineFeature/Sources/Components/TransportControls.swift`
- Modify: `Modules/TimelineFeature/Sources/Components/EditToolbar.swift`
- Modify: `Modules/TimelineFeature/Sources/Components/AutoLabelsOverlay.swift` (색만)

**Interfaces:**
- Consumes: `ChalNaCanvas`, `ChalNaTag`, `ChalNaProgressBar`, `ChalNaColor`, `ChalNaTypography.mono/.caption`, `ChalNaIcon`, `ChalNaShadow.floating`, `ChalNaRadius`.
- Produces: `PreviewPanel(store:playback:)` — 시그니처 불변. **높이 고정을 제거**하고 부모가 준 공간을 채운다.
- Produces: `TransportControls(isPlaying:onPrev:onToggle:onNext:)` — 시그니처 불변.
- Produces: `EditToolbar(dimmed:adjustActive:labelActive:canSave:onAdjust:onLabel:onDelete:onSave:)` — 시그니처 불변.

- [ ] **Step 1: PreviewPanel 을 ChalNaCanvas 기반으로 재작성 + 고정 높이 제거**

`Modules/TimelineFeature/Sources/Components/PreviewPanel.swift` 전체를 교체한다:

```swift
import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem

/// 영상 프리뷰 패널.
///
/// **고정 높이를 갖지 않는다** — 부모(TimelineView)가 준 공간을 채우고
/// `ChalNaCanvas` 가 9:16 으로 aspect-fit 한다. 이것이 SE 세로 예산의 핵심이다.
/// (기존에는 `previewHeight = 300` 고정이라 SE 에서 세로가 넘쳤다)
struct PreviewPanel: View {
    private static let render = CGSize(width: 1080, height: 1920)

    @Environment(EditSession.self) private var session

    let store: StoreOf<TimelineFeature>
    let playback: ClipPlaybackController

    private var currentRotation: ClipRotation {
        guard let id = store.currentClip?.id else { return .r0 }
        return session.rotation(for: id)
    }

    private var currentLabel: ClipLabel {
        guard let id = store.currentClip?.id else { return .default }
        return session.label(for: id)
    }

    var body: some View {
        VStack(spacing: 8) {
            ChalNaCanvas { box in
                clipContent(box: box)
            } overlay: { box in
                ZStack {
                    autoLabelsOverlay(box: box)
                    labelOverlay(box: box)
                    clipIndexBadge
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            scrubBar
        }
    }

    // MARK: - Clip content

    @ViewBuilder
    private func clipContent(box: CGSize) -> some View {
        if let clip = store.currentClip {
            let transform = session.transform(for: clip.id)
            let rrect = ClipFraming.resolvedRect(
                display: clip.displaySize ?? CGSize(width: 9, height: 16),
                rotation: currentRotation,
                render: Self.render,
                transform: transform
            )
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
        }
    }

    // MARK: - Overlays

    /// 자동 시간/날짜 라벨을 출력과 동일하게 표시(읽기 전용).
    /// 센터 크롭에서는 보이는 클립 영역 = 캔버스 전체 → 캔버스 박스를 renderSize 로 간주.
    @ViewBuilder
    private func autoLabelsOverlay(box: CGSize) -> some View {
        if let clip = store.currentClip {
            AutoLabelsOverlay(box: box, capturedAt: clip.capturedAt)
                .frame(width: box.width, height: box.height)
                .allowsHitTesting(false)
        }
    }

    /// 현재 클립 라벨을 에디터와 동일한 정규화 좌표·렌더러로 표시(WYSIWYG).
    @ViewBuilder
    private func labelOverlay(box: CGSize) -> some View {
        let label = currentLabel
        if store.currentClip != nil, label.isVisible {
            ClipLabelText(label: label, fontPx: label.clampedSizeFraction * box.height)
                .position(x: label.position.x * box.width,
                          y: label.position.y * box.height)
                .frame(width: box.width, height: box.height)
                .allowsHitTesting(false)
        }
    }

    /// 영상 위에는 정보용 인덱스만 둔다. 재생 제어는 아래 TransportControls 담당.
    private var clipIndexBadge: some View {
        ChalNaTag("\(store.currentIndex + 1) / \(store.clips.count)", variant: .neutral)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(10)
            .allowsHitTesting(false)
    }

    // MARK: - Scrub bar

    private var scrubBar: some View {
        HStack(spacing: 8) {
            Text(verbatim: store.isPlaying ? store.playheadLabel : "00:00")
                .font(ChalNaTypography.mono(.caption, weight: .semibold))
                .foregroundColor(ChalNaColor.textPrimary)

            ChalNaProgressBar(progress: scrubProgress, height: 3)

            Text(verbatim: store.totalClockLabel)
                .font(ChalNaTypography.mono(.caption, weight: .semibold))
                .foregroundColor(ChalNaColor.textSecondary)
        }
        .frame(height: 20)
    }

    private var scrubProgress: Double {
        guard store.isPlaying else { return 0 }
        return min(1.0, max(0.0, store.playheadSeconds / max(store.totalDuration, 0.001)))
    }
}
```

> **삭제한 것:**
> - `previewHeight = 300` 고정 (감사 #6, #8 의 직접 원인)
> - `ScrubBarStyle` enum + `ScrubBar` 구조체 전체 — `paper` / `liquidGlass` 두 경로를
>   유지하던 `#available(iOS 26.0, *)` 분기. deployment target 이 iOS 18 이라 양쪽을
>   영구히 유지해야 하는데 얻는 것은 재질 차이뿐이다 (스펙 §7.1). 노브(knob)도 함께
>   사라진다 — 스크럽바가 **읽기 전용 진행 표시**이고 드래그 제스처가 없었으므로
>   노브는 조작 가능하다는 잘못된 신호였다.
> - `hudOverlay` 의 `GlassEffectContainer` 분기와 `topRightIndexAttributed` —
>   `ChalNaTag` 하나로 대체.
> - `chalNaShadow(ChalNaShadow.md)` — 다크에서 무의미.

- [ ] **Step 2: TransportControls 다크 전환**

`Modules/TimelineFeature/Sources/Components/TransportControls.swift` 의 두 함수를 교체한다:

```swift
    private func sideButton(icon: ChalNaIconKind, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(ChalNaColor.surface).frame(width: 40, height: 40)
                Circle().strokeBorder(ChalNaColor.border, lineWidth: 1).frame(width: 40, height: 40)
                ChalNaIcon(icon, size: 14, weight: .semibold)
                    .foregroundColor(ChalNaColor.textPrimary)
            }
        }
        .buttonStyle(.plain)
        .chalNaHitTarget()
        .accessibilityLabel(label)
    }

    private var centerButton: some View {
        Button(action: onToggle) {
            ZStack {
                Circle().fill(ChalNaColor.accentFill).frame(width: 52, height: 52)
                ChalNaIcon(isPlaying ? .pause : .play, size: 18, weight: .semibold)
                    .foregroundColor(ChalNaColor.onAccent)
            }
        }
        .buttonStyle(.plain)
        .chalNaHitTarget(minSize: 52)
        .accessibilityLabel(isPlaying ? LocalizedStringKey("일시정지") : LocalizedStringKey("재생"))
        .accessibilityHint("현재 클립 재생 상태를 전환합니다.")
    }
```

> 제거한 것: `.shadow(color: ChalNaColor.Purple.p600.opacity(0.6), radius: 10, y: 5)` —
> 다크 배경에서 보라 글로우가 번져 버튼 경계를 흐린다.
> 제거한 것: `.offset(x: isPlaying ? 0 : 2)` — SF Symbols `play.fill` 은 이미 optical
> 중심이 맞아 있어 수동 보정이 불필요하다.
> 총 높이는 52pt(center) 로 스펙의 56pt 예산 안에 들어간다.

- [ ] **Step 3: EditToolbar 다크 전환 + 삭제 색 수정 (감사 #15)**

`Modules/TimelineFeature/Sources/Components/EditToolbar.swift` 의 `paperToolbar`·`item`·
`ToolbarItemTone` 을 교체한다:

```swift
    private var toolbar: some View {
        HStack(spacing: 0) {
            item(icon: .move, label: "조정", action: onAdjust, dotIndicator: adjustActive)
            item(icon: .textLabel, label: "라벨", action: onLabel, dotIndicator: labelActive)
            item(icon: .trash, label: "삭제", action: onDelete, tone: .destructive)
            item(icon: .check, label: "저장", action: onSave, disabled: !canSave)
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: ChalNaRadius.lg, style: .continuous)
                .fill(ChalNaColor.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChalNaRadius.lg, style: .continuous)
                .strokeBorder(ChalNaColor.border, lineWidth: 1)
        )
        .chalNaShadow(ChalNaShadow.floating)
        .opacity(dimmed ? 0.5 : 1)
        .allowsHitTesting(!dimmed)
        .accessibilityHidden(dimmed)
    }

    private func item(
        icon: ChalNaIconKind,
        label: LocalizedStringKey,
        action: @escaping () -> Void,
        dotIndicator: Bool = false,
        tone: ToolbarItemTone = .normal,
        disabled: Bool = false
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    ChalNaIcon(icon, size: 20, weight: .regular)
                        .foregroundColor(tone.foregroundColor)
                    if dotIndicator {
                        Circle()
                            .fill(ChalNaColor.accent)
                            .frame(width: 6, height: 6)
                            .offset(x: 4, y: -2)
                    }
                }
                Text(label)
                    .font(ChalNaTypography.caption)
                    .foregroundColor(tone.foregroundColor)
            }
            .opacity(disabled ? 0.4 : 1)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .chalNaHitTarget()
        .disabled(dimmed || disabled)
        .accessibilityLabel(label)
        .accessibilityHint(tone.accessibilityHint)
    }
```

그리고 `body` 를 `var body: some View { toolbar }` 로,
`ToolbarItemTone.foregroundColor` 를 다음으로 바꾼다:

```swift
    var foregroundColor: Color {
        switch self {
        case .normal:      return ChalNaColor.textPrimary
        case .destructive: return ChalNaColor.danger
        }
    }
```

> **이것이 감사 #15 의 수정이다.** 삭제 항목이 `Purple.p600`(=Primary)이라
> FilmDetail 의 `danger` 와 갈렸다.
>
> 또 `dimmed` 일 때 라벨을 숨기던 `if !dimmed { Text(label) }` 을 제거했다 —
> 라벨이 사라지면 아이콘만 남아 툴바 높이가 재생 중/정지 상태에서 달라지고,
> 그 변화가 세로 예산을 흔든다. 이제 `opacity` 로만 흐리게 한다.
> `.ultraThinMaterial` 오버레이도 제거(다크에서 `surfaceRaised` 로 충분).

- [ ] **Step 4: AutoLabelsOverlay 색 토큰화**

`Modules/TimelineFeature/Sources/Components/AutoLabelsOverlay.swift` 의 `label(...)` 함수에서:

```swift
            .foregroundColor(ChalNaColor.onAccent)
            ...
            .shadow(color: ChalNaColor.canvas.opacity(0.5), radius: 4, x: 0, y: 2)
```

> `onAccent`(= 흰색)를 쓰는 이유: 이 라벨은 **영상 출력과 픽셀 일치해야 한다**.
> 출력이 흰 글자 + 검은 그림자이므로 UI 테마와 무관하게 흰색을 유지하되,
> 리터럴 `.white` 대신 값이 흰색인 토큰을 참조해 lint 를 통과시킨다.
> 값을 바꾸면 안 되는 곳이라는 주석을 함수 위에 남긴다.

- [ ] **Step 5: 빌드 확인 + TimelineFeature 테스트**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:" | sort -u
xcodebuild -workspace ChalNa.xcworkspace -scheme TimelineFeature \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

Expected: 빌드 성공 + TimelineFeature 테스트 전부 PASS.

- [ ] **Step 6: 커밋**

```bash
git add Modules/TimelineFeature/Sources/Components/PreviewPanel.swift \
        Modules/TimelineFeature/Sources/Components/TransportControls.swift \
        Modules/TimelineFeature/Sources/Components/EditToolbar.swift \
        Modules/TimelineFeature/Sources/Components/AutoLabelsOverlay.swift
git commit -m "$(cat <<'EOF'
♻️ refactor(Timeline): 프리뷰 고정 높이 제거 + glassEffect 이중 경로 삭제

- PreviewPanel 의 previewHeight = 300 고정 삭제. ChalNaCanvas 로 부모가 준
  공간을 채운다 — SE 세로 예산의 핵심
- ScrubBar 의 paper/liquidGlass 두 경로(#available(iOS 26)) 삭제.
  iOS 18 타겟이라 양쪽 영구 유지 비용만 들고 얻는 건 재질 차이뿐.
  드래그 제스처가 없는 읽기 전용 표시였는데 노브가 조작 가능한 신호를
  주고 있었으므로 ChalNaProgressBar 로 대체
- HUD 인덱스 배지를 ChalNaTag 로 (GlassEffectContainer 분기 제거)
- EditToolbar 삭제 항목 색을 Purple(=Primary) → danger. FilmDetail 과 일치
- EditToolbar 가 재생 중 라벨을 숨겨 높이가 달라지던 것을 opacity 로 변경 —
  툴바 높이가 상태에 따라 흔들리면 세로 예산이 무너진다
- TransportControls 보라 글로우 shadow 제거, play 아이콘 수동 offset 제거

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 23: TimelineView — 세로 예산 재설계 + SE UI 테스트

**Files:**
- Modify: `Modules/TimelineFeature/Sources/TimelineView.swift`
- Create: `ChalNa/UITests/TimelineLayoutUITests.swift`

**Interfaces:**
- Consumes: `ChalNaNavBar`, `ChalNaNavAction`, `PreviewPanel`, `TransportControls`, `EditToolbar`, `FilmStripCollectionView`, `ChalNaColor`, `ChalNaTypography.caption`.
- Produces: 없음 (화면). `TimelineFeature` 액션 불변.

- [ ] **Step 1: SE 에서 하단 툴바가 보이는지 검증하는 UI 테스트를 먼저 작성**

`ChalNa/UITests/TimelineLayoutUITests.swift`:

```swift
import XCTest

/// Timeline 세로 예산 실측 검증 (devMock, 사진 권한 불필요).
///
/// 스펙 §6.5 의 예산 계산은 근사치다. 실제로 하단 EditToolbar 가 화면 안에
/// 들어오는지는 가장 작은 기기에서 확인해야만 알 수 있다.
/// **iPhone SE (3rd generation) 에서 실행해야 의미가 있다.**
final class TimelineLayoutUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTimelineFitsOnScreen_EditToolbarVisible() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CHALNA_APP_MODE"] = "devMock"
        app.launchArguments += ["-AppleLanguages", "(ko)"]
        app.launch()

        let newVlog = app.buttons["새 Vlog 만들기"].firstMatch
        XCTAssertTrue(newVlog.waitForExistence(timeout: 10), "홈의 새 Vlog 버튼")
        newVlog.tap()

        // dev fixture 2개 선택
        let firstAsset = app.buttons.matching(NSPredicate(format: "label CONTAINS '협재 바다'")).firstMatch
        XCTAssertTrue(firstAsset.waitForExistence(timeout: 10), "dev fixture: 협재 바다")
        firstAsset.tap()
        let secondAsset = app.buttons.matching(NSPredicate(format: "label CONTAINS '카페 테이블'")).firstMatch
        XCTAssertTrue(secondAsset.waitForExistence(timeout: 5), "dev fixture: 카페 테이블")
        secondAsset.tap()

        let confirm = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Timeline으로'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Timeline으로 버튼")
        confirm.tap()

        // 하단 EditToolbar 4개 항목이 모두 존재하고 화면 안에 들어와야 한다.
        let screen = app.windows.firstMatch.frame
        for label in ["조정", "라벨", "삭제", "저장"] {
            let button = app.buttons[label].firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 15), "하단 툴바 '\(label)' 버튼이 없다")
            XCTAssertTrue(button.isHittable, "'\(label)' 버튼이 탭 불가 — 화면 밖으로 밀렸을 가능성")
            XCTAssertTrue(
                screen.contains(button.frame),
                "'\(label)' 버튼이 화면(\(screen)) 밖에 있다: \(button.frame) — 세로 예산 초과"
            )
        }

        // 재생 컨트롤도 화면 안에 있어야 한다.
        let playToggle = app.buttons["재생"].firstMatch
        XCTAssertTrue(playToggle.waitForExistence(timeout: 5), "재생 버튼")
        XCTAssertTrue(screen.contains(playToggle.frame),
                      "재생 버튼이 화면 밖: \(playToggle.frame)")

        // 필름스트립 셀도 접근 가능해야 한다.
        XCTAssertTrue(app.collectionViews.firstMatch.exists, "필름스트립 collection view")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "timeline-layout"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

- [ ] **Step 2: SE 에서 테스트를 실행해 현재 실패를 확인**

```bash
xcrun simctl boot "iPhone SE (3rd generation)" 2>/dev/null || true
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
           -only-testing:ChalNaUITests/TimelineLayoutUITests \
           test 2>&1 | tail -40
```

Expected: **FAIL** — 하단 툴바 버튼 중 하나 이상이 `isHittable == false` 이거나
`screen.contains(button.frame) == false`. 이것이 감사 #6(94pt 초과)의 실측 증거다.

> 만약 여기서 통과한다면 Task 22 의 프리뷰 고정 높이 제거만으로 이미 해결됐다는 뜻이다.
> 그 경우에도 Step 3 은 수행한다 — `labelRow`/`hintRow` 중복 정보 제거는 별개의 개선이다.

- [ ] **Step 3: TimelineView 를 예산 구조로 재작성**

`Modules/TimelineFeature/Sources/TimelineView.swift` 의 `body`·`header`·`labelRow` 관련
부분을 교체한다 (playback wiring / session sync / adjust / label 함수는 그대로):

```swift
    public var body: some View {
        VStack(spacing: 0) {
            header

            // 프리뷰가 유일한 가변 요소다. 남는 공간을 전부 먹는다.
            PreviewPanel(store: store, playback: playback)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .layoutPriority(1)

            TransportControls(
                isPlaying: store.isPlaying,
                onPrev: { store.send(.previousTapped) },
                onToggle: { store.send(.togglePlay) },
                onNext: { store.send(.nextTapped) }
            )
            .padding(.top, 12)

            hintRow
                .padding(.horizontal, 20)
                .padding(.top, 10)

            FilmStripCollectionView(
                store: store,
                session: session,
                onTapClip: { store.send(.clipTapped(index: $0)) }
            )
            .frame(height: 96)
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .chalNaScreen()
        .safeAreaInset(edge: .bottom) {
            bottomBar
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
        // onAppear / onChange / onDisappear / confirmationDialog / fullScreenCover 는 기존 유지
    }

    private var header: some View {
        ChalNaNavBar(
            title: "편집",
            caption: store.title.isEmpty ? nil : store.title,
            leading: .back { store.send(.dismissTapped) },
            showsDivider: true
        )
    }

    /// 힌트 1줄. 재생 중에는 숨긴다.
    ///
    /// 기존에는 이 위에 `labelRow`(TIMELINE · N CLIPS + 총 길이)가 따로 있었지만
    /// 클립 수는 필름스트립이, 총 길이는 스크럽바가, 현재 인덱스는 캔버스 배지가
    /// 이미 말하고 있었다. 같은 정보를 35pt 더 써서 두 번 말하던 것을 지웠다.
    @ViewBuilder
    private var hintRow: some View {
        if store.isPlaying {
            // 자리를 유지해 재생/정지 전환 시 레이아웃이 튀지 않게 한다.
            Color.clear.frame(height: 16)
        } else {
            Text("클립을 탭해 편집 · 길게 눌러서 끌어 이동")
                .font(ChalNaTypography.caption)
                .foregroundColor(ChalNaColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 16)
        }
    }
```

**삭제:** `labelRow`, `labelLeft`, `labelLeftColor`, `labelRight`, `preview`(1줄 래퍼),
`canSave` 는 유지(`bottomBar` 가 쓴다), `headerTitle`/`headerSubtitle`(인라인화).

`bottomBar` 의 `.padding(.bottom, 16)` 을 두 분기에서 **제거**한다 (safeAreaInset 이 여백을 갖는다).

- [ ] **Step 4: SE 에서 테스트가 통과하는지 확인 — 이 태스크의 합격 기준**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
           -only-testing:ChalNaUITests/TimelineLayoutUITests \
           test 2>&1 | tail -40
```

Expected: **PASS**.

**실패하면** 순서대로 조정한다:
1. 필름스트립 `frame(height: 96)` → `80` (스펙 §11 의 1차 조정 레버)
2. `TransportControls` 의 `.padding(.top, 12)` → `8`
3. `hintRow` 를 재생 중이 아닐 때만 표시하고 `Color.clear` 자리 유지를 포기
각 조정 후 테스트를 다시 돌린다.

- [ ] **Step 5: SE 스크린샷 + Dynamic Type xxxLarge 확인**

```bash
xcrun simctl io "iPhone SE (3rd generation)" screenshot /tmp/p4-timeline-se.png
open /tmp/p4-timeline-se.png
```

확인할 것: 헤더 · 캔버스 · 재생 컨트롤 · 힌트 · 필름스트립 · 하단 툴바가 **모두 보인다**.

**Dynamic Type 확대 확인 — `simctl ui content-size` 를 쓰지 말 것.**

이 환경에서 `xcrun simctl ui <device> content-size extra-extra-extra-large` 는
**앱 프로세스에 전달되지 않는다**(Task 12 검증에서 확인: OS 설정은 `defaults read` 로 바뀐 것이
보이는데 xxxLarge 스크린샷이 기본 스크린샷과 바이트 단위로 동일했고, 시뮬레이터 완전 재부팅 후에도
같았다). 그 명령으로 찍은 스크린샷은 증거가 되지 않는다.

대신 **코드로 환경값을 직접 거는 프리뷰**를 쓴다. `TimelineView.swift` 하단에 추가:

```swift
#Preview("Timeline · xxxLarge") {
    TimelineView()
        .environment(EditSession(title: SampleData.filmTitle, clips: SampleData.jejuTimeline))
        .environment(\.dynamicTypeSize, .xxxLarge)
}
```

그리고 Xcode 의 `RenderPreview` 로 이 프리뷰를 렌더해 캡처한다.
**눈대중으로 "비슷해 보인다"고 판단하지 말 것** — Task 12 검증은 Pillow 로 픽셀 바운딩박스를
실측해 캡션 20→29px, 글리프 31→42px, 행 타이틀 24→34px 로 확대가 실제 일어남을 증명했다.
같은 방식으로 **하단 EditToolbar 의 y 좌표가 화면 높이 안에 있는지 픽셀로 확인**한다.

이 프리뷰는 커밋에 포함해도 좋다 — 이후 태스크가 같은 검증을 반복할 수 있다.

확인할 것: 툴바 라벨이 커져도 하단 툴바가 화면 안에 있는가 (캔버스가 줄어드는 것이 정상).

- [ ] **Step 6: 커밋**

```bash
git add Modules/TimelineFeature/Sources/TimelineView.swift ChalNa/UITests/TimelineLayoutUITests.swift
git commit -m "$(cat <<'EOF'
🐛 fix(Timeline): 세로 예산 재설계 — SE 94pt 초과 해소

고정 높이 합계 741pt(SE 가용 647pt) → 320pt. 캔버스가 남는 공간을 먹는다.

> **★ 헤더 52pt 는 하한이다(Task 6 리뷰 확인).** `ChalNaNavBar` 는 높이를
> `.frame(minHeight: 52)` 로 적용한다. 이 화면은 `title: "편집"` + `caption: store.title` 을
> **세로로 쌓기** 때문에 Dynamic Type 을 키우면 헤더가 52pt 를 넘어 캔버스 몫을 잠식한다.
> 즉 320pt 는 기본 텍스트 크기에서의 하한 합계이고 xxxLarge 에서는 더 커진다.
> 캔버스가 `layoutPriority(1)` 로 남는 공간을 먹으므로 헤더가 커지면 캔버스가 자동 축소된다 —
> 파열이 아니라 축소로 흡수되는 구조다. Step 5 의 xxxLarge 실측이 이 지점을 확인하며,
> 미달 시 1차 조정 레버는 필름스트립 96 → 80pt.

- 프리뷰를 layoutPriority(1) 가변 요소로, 나머지는 고정
- labelRow(TIMELINE · N CLIPS + 총 길이) 삭제 — 클립 수는 필름스트립,
  총 길이는 스크럽바, 현재 인덱스는 캔버스 배지가 이미 말한다.
  같은 정보를 35pt 더 써서 두 번 말하고 있었다
- hintRow 를 24pt 로 압축(두 행 69pt → 24pt). 재생 중에는 자리만 유지해
  레이아웃이 튀지 않게 함
- 필름스트립 104 → 96, 좌우 여백 16 → 20 통일
- bottomBar 이중 패딩 제거 (safeAreaInset 이 여백 담당)

검증: TimelineLayoutUITests 가 SE 에서 하단 툴바 4개 버튼의 isHittable 과
화면 포함 여부를 실측한다. 계산이 아니라 실제 프레임으로 확인한다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 24: ClipAdjustView

**Files:**
- Modify: `Modules/TimelineFeature/Sources/ClipAdjustView.swift`

**Interfaces:**
- Consumes: `ChalNaNavBar`, `ChalNaNavAction`, `ChalNaCanvas`, `ChalNaButton`, `ChalNaIcon`, `ChalNaColor`, `ChalNaTypography.caption`, `ChalNaMotion.spring`.
- Produces: 없음 (화면). 제스처·러버밴드 로직은 **변경하지 않는다**.

- [ ] **Step 1: 상단바·하단 컨트롤·힌트 교체**

```swift
    private var topBar: some View {
        ChalNaNavBar(
            title: "조정",
            leading: .back { store.send(.backTapped) },
            trailing: .text("완료") { store.send(.doneTapped) },
            showsDivider: true
        )
    }

    private var adjustHint: some View {
        Text("드래그로 보이는 부분을 옮기고, 핀치로 확대해요. 더블탭 = 초기화")
            .font(ChalNaTypography.caption)
            .foregroundColor(ChalNaColor.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button { rotate() } label: {
                HStack(spacing: 6) {
                    ChalNaIcon(.rotate, size: 16, weight: .semibold)
                    Text("회전")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))

            Button { resetToCenterCrop() } label: {
                HStack(spacing: 6) {
                    ChalNaIcon(.move, size: 16, weight: .semibold)
                    Text("초기화")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
    }
```

`topBar` 호출부에서 `.padding(.horizontal, 16).padding(.vertical, 12).chalNaHeaderBar(scrollProgress: 1)` 를 **제거**한다.

- [ ] **Step 2: 캔버스를 ChalNaCanvas 로 교체 (제스처 로직 보존)**

`canvas` 프로퍼티를 교체한다. **`handleGestureChange`·`commitWorking`·`resolvedRectUnclamped`·
`rotate`·`resetToCenterCrop` 는 한 글자도 바꾸지 않는다.**

```swift
    private var canvas: some View {
        ChalNaCanvas { box in
            let factor = box.width / Self.render.width
            let live = working ?? committed
            // 제스처 중에만 러버밴드 오버슛을 그대로 그리고(unclamped),
            // 휴지 상태는 항상 clamp 된 사각형으로 렌더 — 프리뷰/export 와 픽셀 일치.
            let rrect = raw != nil
                ? resolvedRectUnclamped(transform: live)
                : ClipFraming.resolvedRect(display: displaySize, rotation: rotation,
                                           render: Self.render, transform: live)

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
                onEnded: { commitWorking() }
            )
            .frame(width: box.width, height: box.height)
            .onTapGesture(count: 2) { resetToCenterCrop() }
        }
        .padding(.horizontal, 20)
    }
```

> `.aspectRatio(9.0 / 16.0, contentMode: .fit)` 는 `ChalNaCanvas` 내부가 담당하므로 제거한다.
> 제스처를 `overlay` 로 옮긴 이유: `ChalNaCanvas` 의 content 는 clip 안쪽이라 히트 영역이
> 라운딩에 잘린다. overlay 는 clip 밖이므로 박스 전체가 히트 영역이 된다.

- [ ] **Step 3: thirdsGrid 색 토큰화**

```swift
    /// 3분할(rule of thirds) 그리드 — 드래그 중에만 표시.
    /// 밝은/어두운 영상 모두에서 보이도록 이중 스트로크(어두운 밑선 + 밝은 윗선).
    /// 이 이중 스트로크는 의도된 설계다 — 한 색만으로는 어느 한쪽에서 사라진다.
    private func thirdsGrid(box: CGSize) -> some View {
        Canvas { context, size in
            var path = Path()
            for i in 1...2 {
                let x = size.width * CGFloat(i) / 3
                let y = size.height * CGFloat(i) / 3
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(ChalNaColor.canvas.opacity(0.35)), lineWidth: 2.5)
            context.stroke(path, with: .color(ChalNaColor.onAccent.opacity(0.85)), lineWidth: 1)
        }
        .frame(width: box.width, height: box.height)
        .allowsHitTesting(false)
    }
```

`Self.snapBack` 상수를 `ChalNaMotion.spring` 으로 바꾼다 (값이 동일하다):

```swift
    private static let snapBack: Animation = ChalNaMotion.spring
```

- [ ] **Step 4: 기존 크롭 UI 테스트가 여전히 통과하는지 확인 — 회귀 방어선**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           -only-testing:ChalNaUITests/CropAdjustUITests \
           test 2>&1 | tail -40
```

Expected: PASS. 이 테스트가 드래그·러버밴드·리셋 플로를 검증하므로,
제스처 로직을 건드리지 않았다는 증거가 된다.

> **실패하면** 원인은 거의 확실히 제스처 히트 영역이다 —
> `PinchPanGesture` 가 `overlay` 로 옮겨져 좌표계가 달라졌는지 확인한다.
> 테스트가 찾는 힌트 텍스트("더블탭 = 초기화")도 그대로 유지했는지 확인한다.

- [ ] **Step 5: SE 스크린샷 후 커밋**

```bash
xcrun simctl io "iPhone SE (3rd generation)" screenshot /tmp/p4-adjust-se.png
open /tmp/p4-adjust-se.png
```

확인할 것 (**이 화면의 최대 수혜 포인트**): 캔버스 검정과 화면 배경이 **이어져 보인다**.
기존에는 흰 화면 위 검은 사각형이었다. 러버밴드로 드래그해 오버슛을 만들었을 때
드러나는 배경도 자연스러워야 한다.

```bash
git add Modules/TimelineFeature/Sources/ClipAdjustView.swift
git commit -m "$(cat <<'EOF'
💄 style(ClipAdjust): ChalNaCanvas 도입 + 다크 전환

- 캔버스를 ChalNaCanvas 로 통합. 제스처를 overlay 로 옮겨 라운딩에 히트
  영역이 잘리지 않게 함
- 제스처·러버밴드·스냅백 로직은 한 글자도 변경하지 않음
  (CropAdjustUITests 통과로 증명)
- snapBack 상수를 ChalNaMotion.spring 으로 (값 동일)
- 3분할 그리드 이중 스트로크 유지 — 밝기 무관 가시성을 위한 의도된 설계
- chalNaHeaderBar(scrollProgress: 1) 억지 패턴 제거 → ChalNaNavBar(showsDivider:)

다크 전환의 최대 수혜 화면: 러버밴드 오버슛 배경이 화면과 이어진다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 25: LabelEditorView

**Files:**
- Modify: `Modules/TimelineFeature/Sources/LabelEditorView.swift`

**Interfaces:**
- Consumes: `ChalNaNavBar`, `ChalNaNavAction`, `ChalNaCanvas`, `ChalNaSlider`, `ChalNaColor`, `ChalNaTypography.label`.
- Produces: 없음 (화면). 상태 머신(`Phase`)·`anchorCorner` 배치·`reflow`·`committedLabel` 로직은 **변경하지 않는다**.

- [ ] **Step 1: 상단바 교체 (감사 #2)**

```swift
    private var topBar: some View {
        ChalNaNavBar(
            title: "라벨",
            leading: .close(action: onCancel),
            trailing: .text("저장") { onCommit(committedLabel()) },
            showsDivider: true
        )
    }
```

호출부에서 `.padding(.horizontal, 16).padding(.vertical, 12).chalNaHeaderBar(scrollProgress: 1)` 제거.

> **이것이 감사 #2 의 수정이다.** `ChalNaHeaderCloseButton` 의 `frame(height: 33)` 짜리
> X 글리프가 사라지고, `ChalNaNavAction.close` 의 20pt 글리프로 통일된다.

- [ ] **Step 2: 슬라이더를 safeAreaInset 으로 옮겨 84pt 고정 예약 제거 (감사 #9)**

`body` 를 교체한다:

```swift
    var body: some View {
        VStack(spacing: 0) {
            topBar
            canvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
        }
        // 본문은 키보드에 밀리거나 리사이즈되지 않아야 한다.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .chalNaScreen()
        // 슬라이더는 실제 높이만 차지한다. 기존 84pt 고정 예약(Color.clear)은
        // 키보드·세이프에어리어 조합에 따라 캔버스를 과하게 줄였다.
        .safeAreaInset(edge: .bottom) { sizeControls }
        // 라벨 외 영역 탭 → 키보드 내림 / ADJUST 종료. 라벨·슬라이더는 각자 제스처가 우선.
        .contentShape(Rectangle())
        .onTapGesture { backgroundTapped() }
        .onChange(of: focused) { _, isFocused in
            if !isFocused, phase == .editing { phase = .idle }
        }
        .onAppear { keyboard.start() }
        .onDisappear { keyboard.stop() }
    }
```

`sizeControls` 를 교체한다:

```swift
    private var sizeControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("크기")
                .font(ChalNaTypography.label)
                .foregroundColor(ChalNaColor.textSecondary)
            ChalNaSlider(
                value: $label.sizeFraction,
                range: ClipLabel.minSizeFraction...ClipLabel.maxSizeFraction,
                step: nil,
                onEditingChanged: { editing in
                    // 드래그 종료 시 현재 크기로 베이크 → scaleEffect=1 로 글자를 선명하게 재렌더.
                    if !editing { renderedSizeFraction = label.clampedSizeFraction }
                }
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(ChalNaColor.bg.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(ChalNaColor.border).frame(height: 1)
        }
        // EDIT 중에는 키보드 위로 띄운다.
        .padding(.bottom, phase == .editing ? keyboard.height : 0)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(ChalNaMotion.standard, value: keyboard.height)
        .animation(ChalNaMotion.standard, value: phase)
    }
```

**삭제:** `private static let sliderRowHeight: CGFloat = 84` 와
`Color.clear.frame(height: Self.sliderRowHeight)` 줄.
`Self.moveAnimation` 은 `ChalNaMotion.standard` 로 바꾼다 (값이 동일: `.easeInOut(0.24)`).

- [ ] **Step 3: 캔버스를 ChalNaCanvas 로 교체 (라벨 좌표계 보존)**

`canvas` 와 `clipCanvas(box:)` 를 교체한다. **`labelLayer`·`displayCornerY`·`labelContent`·
`dragGesture`·`applyDrag`·`reflow`·`committedLabel` 는 변경하지 않는다.**

```swift
    private var canvas: some View {
        GeometryReader { proxy in
            let boxTopGlobalY = proxy.frame(in: .global).minY
            ChalNaCanvas { box in
                clipContent(box: box)
            } overlay: { box in
                ZStack(alignment: .top) {
                    AutoLabelsOverlay(box: box, capturedAt: clip.capturedAt)
                        .frame(width: box.width, height: box.height)
                        .allowsHitTesting(false)
                    labelLayer(box: box, boxTopGlobalY: boxTopGlobalY)
                }
                .onAppear { reflow(from: .zero, to: box) }
                .onChange(of: box) { oldBox, newBox in reflow(from: oldBox, to: newBox) }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    /// 클립을 출력과 동일한 센터 크롭 프레이밍(ClipFraming SSOT)으로 배치.
    @ViewBuilder
    private func clipContent(box: CGSize) -> some View {
        let render = CGSize(width: 1080, height: 1920)
        let rrect = ClipFraming.resolvedRect(
            display: clip.displaySize ?? CGSize(width: 9, height: 16),
            rotation: rotation, render: render, transform: transform
        )
        let factor = box.width / render.width
        RotatableContent(rotation: rotation) {
            clip.thumbnailView(contentMode: .fill)
        }
        .frame(width: rrect.width * factor, height: rrect.height * factor)
        .position(x: rrect.midX * factor, y: rrect.midY * factor)
    }
```

- [ ] **Step 4: 라벨 박스 예외를 코드에 명시**

`inlineEditor(fontPx:)` 함수 **바로 위**에 다음 주석을 추가한다 (색은 바꾸지 않는다):

```swift
    /// 편집 상태: 같은 박스 스타일의 인라인 TextField.
    ///
    /// **다크 토큰 적용 예외.** 라벨 박스(흰 배경 · 검은 글자)는 영상 출력과
    /// 픽셀 일치해야 하므로 UI 테마와 무관하다. `ClipLabel.BoxStyle` 이 SSOT 다.
    /// 여기서 `.black` / `.white` 리터럴을 쓰는 것은 의도된 것이며
    /// `scripts/design-lint.sh` 의 예외 경로에 이 파일이 등록돼 있다.
```

`.tint(ChalNaColor.Purple.p600)` → `.tint(ChalNaColor.accentFill)` 로만 바꾼다
(커서 색은 출력에 영향이 없다).

`selectionFrame`·`alignmentGuides` 의 `Purple.p600` → `ChalNaColor.accent`.

- [ ] **Step 5: SE 에서 라벨 에디터 스크린샷 (idle / editing 두 상태)**

`ChalNa Dev` 스킴으로 Timeline → 라벨 버튼 진입:

```bash
xcrun simctl io "iPhone SE (3rd generation)" screenshot /tmp/p4-labeleditor-idle.png
# 라벨 탭 → 키보드 올라온 상태
xcrun simctl io "iPhone SE (3rd generation)" screenshot /tmp/p4-labeleditor-editing.png
open /tmp/p4-labeleditor-idle.png /tmp/p4-labeleditor-editing.png
```

확인할 것 (**이 태스크의 핵심**):
0. **★ Dynamic Type 상한이 이 화면까지 전파되는지 실측한다 (Task 13 에서 남긴 미해결 질문).**
   Task 13 이 `RootView` 에 `.dynamicTypeSize(...DynamicTypeSize.accessibility1)` 를 앱 전역으로
   걸었지만, **SwiftUI 환경값이 presentation 경계를 항상 넘는다는 보장이 없다.**
   `LabelEditorView` 는 `fullScreenCover` 로 뜨므로, 만약 상한이 전파되지 않으면 이 화면만
   무제한 확대가 되어 84pt 슬라이더 영역과 캔버스가 파열된다.
   확인 방법: 이 파일에 아래 프리뷰를 추가하고 `RenderPreview` 로 렌더해
   **accessibility5(상한보다 큰 값)를 걸었을 때 실제로 accessibility1 로 잘리는지** 본다.
   ```swift
   #Preview("LabelEditor · 상한 초과 시도") {
       LabelEditorView(
           clip: SampleData.jejuTimeline[0], rotation: .r0,
           initialLabel: ClipLabel(text: "제주 바다"),
           onCommit: { _ in }, onCancel: {}
       )
       .dynamicTypeSize(.accessibility5)
   }
   ```
   상한이 먹으면 accessibility1 수준으로만 커진다. 그보다 크게 커지면 **전파되지 않는 것**이므로
   `LabelEditorView` 를 띄우는 `TimelineView` 의 `.fullScreenCover` 콘텐츠에 상한을 직접 한 번 더
   걸어야 한다. 어느 쪽이었는지 리포트에 명시한다 — 같은 문제가 `MediaPreviewSheet`(sheet)에도
   적용되므로 Task 18 이 이 답을 재사용한다.
1. **닫기(X) 아이콘이 back chevron 과 같은 크기**다 (기존 33pt 짜리가 아님)
2. 캔버스가 84pt 예약 없이 가용 공간을 채운다 — idle 에서 사진이 더 크게 보인다
3. 편집 중 슬라이더가 키보드 바로 위에 있다
4. **라벨 박스는 여전히 흰 배경 · 검은 글자**다 (출력과 일치 — 다크로 바뀌면 안 된다)
5. 라벨을 드래그했을 때 중앙 정렬 가이드가 accent 색으로 보인다

- [ ] **Step 6: 라벨 관련 테스트 전체 확인 후 커밋**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme CompositionService \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
xcodebuild -workspace ChalNa.xcworkspace -scheme TimelineFeature \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

Expected: `CompositorLabelTests`·`CustomLabelLayoutTests`·`LabelStackTests`·
`ClipFramingTests` 전부 PASS — **영상 출력 픽셀이 변하지 않았다는 증거**다.

```bash
git add Modules/TimelineFeature/Sources/LabelEditorView.swift
git commit -m "$(cat <<'EOF'
🐛 fix(LabelEditor): 닫기 아이콘 33pt 비대칭 + 84pt 고정 예약 제거

- ChalNaHeaderCloseButton(글리프 33pt) → ChalNaNavAction.close(20pt).
  같은 바의 back chevron 이 10pt 였던 비대칭 해소
- sliderRowHeight = 84 고정 예약 삭제 → safeAreaInset 으로 실제 높이만 차지.
  키보드·세이프에어리어 조합에서 캔버스가 과하게 줄던 문제 해소
- 캔버스를 ChalNaCanvas 로 통합 (라벨 좌표계·상태 머신은 무변경)
- moveAnimation → ChalNaMotion.standard, snapBack 계열 값 동일

라벨 박스(흰 배경·검은 글자)는 영상 출력과 픽셀 일치해야 하므로
다크 토큰 적용 예외임을 코드 주석과 design-lint 예외로 명시.
CompositorLabelTests / CustomLabelLayoutTests 통과로 출력 불변 증명.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# Phase P5 — 정리 (Task 26–27)

## Task 26: deprecated 심 삭제 + 정적 검사 통과

**Files:**
- Modify: `Modules/DesignSystem/Sources/Tokens/ChalNaColor.swift` (deprecated 블록 삭제)
- Modify: `Modules/DesignSystem/Sources/Tokens/ChalNaTypography.swift` (deprecated 블록 삭제)
- Modify: `Modules/DesignSystem/Sources/Tokens/ChalNaRadius.swift` (deprecated 삭제)
- Modify: `Modules/DesignSystem/Sources/Tokens/ChalNaShadow.swift` (deprecated 삭제)
- Modify: `Modules/DesignSystem/Sources/Components/ChalNaButton.swift` (deprecated 별칭 삭제)
- Delete: `ChalNaChip.swift`, `ClipThumbCard.swift`, `LiveBadge.swift`, `ChalNaNavigationBar.swift`, `ChalNaHeaderActionButtonStyle.swift`, `View+ChalNaTopBar.swift`

**Interfaces:**
- Consumes: 앞선 모든 태스크.
- Produces: deprecated 심이 없는 최종 토큰 API.

- [ ] **Step 1: deprecated 사용처가 남아 있는지 먼저 조사**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 \
  | grep -E "warning:.*(deprecated|is deprecated)" \
  | sed -E 's/^.*(Modules|ChalNa)\//\1\//' | sort -u
```

Expected: 목록이 나온다. **이 목록이 곧 남은 할 일이다.** 각 위치를 P2 공통
마이그레이션 표에 따라 새 API 로 바꾼다. 목록이 빌 때까지 반복한다.

- [ ] **Step 2: 구 컴포넌트 파일 삭제**

```bash
git rm Modules/DesignSystem/Sources/Components/ChalNaChip.swift \
       Modules/DesignSystem/Sources/Components/ClipThumbCard.swift \
       Modules/DesignSystem/Sources/Components/LiveBadge.swift \
       Modules/DesignSystem/Sources/Components/ChalNaNavigationBar.swift \
       Modules/DesignSystem/Sources/Components/ChalNaHeaderActionButtonStyle.swift \
       Modules/DesignSystem/Sources/Modifiers/View+ChalNaTopBar.swift
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:" | sort -u
```

Expected: 에러 없음. 에러가 나면 그 호출처가 아직 구 컴포넌트를 쓰고 있다는 뜻이므로
새 컴포넌트로 바꾼다.

- [ ] **Step 3: 토큰의 deprecated 블록 삭제**

각 파일에서 `// MARK: - Deprecated` 주석 이후 블록을 전부 삭제한다:

- `ChalNaColor.swift` — `Purple`/`Blue`/`Gray`/`Chip` enum, `info`
- `ChalNaTypography.swift` — `displayKR`/`krSemibold`/`krBody`/`title(_:weight:)`/
  `monoFallback`/`displayEN`/`serifFallback`/`hand`/`handFallback`/`Size` enum,
  그리고 `Text.tagLabel()` extension 전체
- `ChalNaRadius.swift` — `film`/`button`/`card`/`sheet`
- `ChalNaShadow.swift` — `sm`/`md`/`lg`
- `ChalNaButton.swift` — `ChalNaButtonVariant` 의 deprecated static 5개,
  `ChalNaButtonSize.xl`, `ButtonStyle` extension 의 deprecated 별칭 5개

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:" | sort -u
```

Expected: 에러 없음.

- [ ] **Step 4: 정적 검사 5종이 전부 통과하는지 확인 — 이 태스크의 합격 기준**

```bash
./scripts/design-lint.sh
echo "exit=$?"
```

Expected: 5개 규칙 모두 `✓ 0건`, `exit=0`.

**위반이 남으면** 각 위치를 고친다. 판단 기준:
- 진짜 토큰으로 바꿔야 하는 것 → 바꾼다
- 영상 출력과 픽셀 일치해야 하는 것 → `scripts/design-lint.sh` 의 해당 규칙 예외에
  파일 경로를 추가하고, **그 파일 안에 이유를 주석으로 남긴다.** 예외를 늘릴 때는
  반드시 근거를 코드에 함께 남긴다.

- [ ] **Step 5: 전체 테스트 스위트 확인**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa-Workspace \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -40
```

Expected: 전 스위트 그린. 특히 다음이 통과해야 한다 —
`DesignSystemTests`(13+3건) · `CompositorLabelTests` · `ClipFramingTests` ·
`CustomLabelLayoutTests` · `CompositionRenderSizeTests` · `TimelineFeatureTests`.

> `ChalNa-Workspace` 스킴이 없으면 `tuist generate` 후 다시 시도한다.
> 그래도 없으면 각 테스트 타겟을 개별 스킴으로 순차 실행한다.

- [ ] **Step 6: SE UI 테스트 재확인**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
           -only-testing:ChalNaUITests \
           test 2>&1 | tail -30
```

Expected: `CropAdjustUITests` · `TimelineLayoutUITests` 둘 다 PASS.

- [ ] **Step 7: 커밋**

```bash
git add -A
git commit -m "$(cat <<'EOF'
🔥 chore(DesignSystem): deprecated 심 제거 + 정적 검사 5종 통과

- ChalNaColor 의 Purple/Blue/Gray/Chip 스케일 삭제
- ChalNaTypography 의 krBody/displayKR/Size/legacy stub 4종/tagLabel 삭제
- ChalNaRadius·ChalNaShadow·ChalNaButton 의 deprecated 별칭 삭제
- 구 컴포넌트 6개 파일 삭제: ChalNaChip · ClipThumbCard · LiveBadge ·
  ChalNaNavigationBar · ChalNaHeaderActionButtonStyle · View+ChalNaTopBar

design-lint 결과: P0 시점 .font(.system( 18건 / 흰색 60건 / UIColor(named:) 1건
→ 전부 0건. 예외는 토큰 정의, ChalNaIcon 글리프 크기, 다크 반투명 오버레이 2파일,
ThumbnailPreset 콘텐츠 그라디언트, 영상 출력과 픽셀 일치해야 하는 라벨 박스뿐.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 27: CLAUDE.md · AGENTS.md 동기화

**Files:**
- Modify: `CLAUDE.md` (디자인 시스템 절 전면 교체)
- Modify: `AGENTS.md` (CLAUDE.md 의 미러본 — 같은 내용으로 동기화)

**Interfaces:**
- Consumes: 최종 토큰·컴포넌트 API.
- Produces: 없음 (문서).

- [ ] **Step 1: CLAUDE.md 의 "디자인 시스템" 절을 교체**

`## 디자인 시스템 (ChalNa 식별자 / Danawa DDS Mobile v2.0 값)` 헤딩부터
`### 금지 사항` 절 끝까지를 다음으로 교체한다:

```markdown
## 디자인 시스템 (ChalNa · 다크 시네마틱)

모든 UI 는 `Modules/DesignSystem/Sources/` 토큰·컴포넌트를 사용한다 (**spacing/padding 만 리터럴 숫자**).
**리터럴 HEX·시스템 폰트 직접 호출 금지.** 새 컴포넌트 전에 기존 것 재사용.

앱은 **다크 전용**이다 (`Info.plist UIUserInterfaceStyle: Dark`). 라이트 모드는 지원하지 않는다.
설계 근거: `docs/superpowers/specs/2026-07-28-app-redesign-design.md`

### 파일 레이아웃
```
DesignSystem/Sources/
├─ Tokens/      ChalNaColor · ChalNaTypography · ChalNaRadius · ChalNaShadow · ChalNaMotion
├─ Components/  ChalNaNavBar · ChalNaNavAction · ChalNaButton · ChalNaCard · ChalNaListRow
│               ChalNaTag · MediaThumb · ChalNaCanvas · ChalNaProgressBar · ChalNaEmptyState
│               ChalNaNotice · ChalNaToast · ChalNaBlockingOverlay
│               ChalNaTextField · ChalNaTextArea · ChalNaSlider
├─ Modifiers/   View+ChalNaScreen · +ChalNaScrollHairline · +ChalNaSwipeBack · +ChalNaHitTarget
│               +ScrollProgress
├─ Icons/       ChalNaIcon (SF Symbols 24종)
└─ Showcase/    DesignSystemShowcaseView
```

### Colors — `ChalNaColor` (시맨틱 토큰, 코드 정의)

수치 스케일(`Purple`/`Blue`/`Gray`)은 **없다.** 역할 이름만 쓴다.

| API | 값 | 용도 |
|---|---|---|
| `.bg` | `#0B0A10` | 화면 배경 (옅은 인디고 캐스트) |
| `.surface` | `#16151D` | 카드 · 리스트 행 |
| `.surfaceRaised` | `#201F29` | 바텀시트 · 플로팅 툴바 |
| `.canvas` | `#000000` | 영상 · 크롭 캔버스 |
| `.border` / `.borderStrong` | `#2C2A38` / `#3D3A4D` | hairline / 입력 경계 |
| `.textPrimary` | `#F5F4F7` | 본문 (순백 아님 — 헐레이션 방지) |
| `.textSecondary` | `#A3A0AE` | 보조 |
| `.textTertiary` | `#6B6878` | **disabled 전용** (bg 대비 3.7:1) |
| `.accent` | `#8B7BFF` | 텍스트 · 아이콘 · 스트로크 |
| `.accentFill` | `#5B45E8` | 면형 버튼 배경 |
| `.accentPressed` | `#A091FF` | 눌림 |
| `.onAccent` | `#FFFFFF` | accentFill 위 라벨 |
| `.danger` / `.success` | `#FF6B66` / `#3DD9A0` | 파괴적 · 완료 |
| `.brandDeep` | `#462DE2` | **앱 아이콘 색.** Splash·브랜드 면 전용 (bg 대비 2.4:1 — 인터랙션 금지) |
| `.scrim` | black 60% | 오버레이 |

- 대비 규칙은 `DesignSystemTests/ChalNaColorContrastTests` 가 강제한다. 값을 바꾸면 테스트가 잡는다.
- **깊이는 그림자가 아니라 밝기 3단**(`bg → surface → surfaceRaised`) + 1px hairline 으로 표현한다.

### Typography — `ChalNaTypography` (역할 6종 + mono + keris)

6개 역할이 표준 iOS 텍스트 스타일에 정확히 대응해 **별도 코드 없이 Dynamic Type 을 따른다.**

| API | 대응 스타일 | 기본 크기 |
|---|---|---|
| `.display` | `.title` | 28 bold |
| `.title` | `.title2` | 22 semibold |
| `.headline` | `.headline` | 17 semibold |
| `.body` | `.callout` | 16 |
| `.label` | `.footnote` | 13 medium |
| `.caption` | `.caption` | 12 |
| `.mono(_ style:weight:)` | 지정 스타일 | SF Mono — **숫자 전용, 한글 금지** |
| `.keris(_ size:)` | — | KERISKEDU. Splash·영상 라벨 WYSIWYG 전용 (고정 pt) |

- `Tracking.title`(-0.20) / `Tracking.body`(-0.30).
- 앱 전역 상한: `RootView` 의 `.dynamicTypeSize(...DynamicTypeSize.accessibility1)`.
- **최소 12pt.** 8pt·11pt 금지.

### Radius — `ChalNaRadius`
`.xs 6`(태그·썸네일) · `.sm 10`(버튼·입력) · `.md 14`(카드·캔버스) · `.lg 20`(시트·툴바) · `.pill 999`

### Shadow — `ChalNaShadow` + `View.chalNaShadow(_:)`
`.floating`(black 50%, blur 24, y 8) **하나뿐이다.** 플로팅 툴바 전용.

### Motion — `ChalNaMotion`
`.fast`(easeOut 0.15) · `.standard`(easeInOut 0.24) · `.spring`(response 0.35, damping 0.85)

### Core Components
| 컴포넌트 | 사용 예 |
|---|---|
| 헤더 | `ChalNaNavBar(title: "설정", leading: .back { }, trailing: .text("저장") { }, showsDivider: true)` |
| 헤더 액션 | `ChalNaNavAction.back / .close / .icon(_:accessibilityLabel:action:) / .text(_:action:)` — **글리프 크기 지정 불가**(20pt 고정, 히트 44pt) |
| 버튼 | `.buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true, destructive: false))` — variant `primary/secondary/ghost`, size `lg 52/md 44/sm 36`. 축약 `.chalNaPrimary/.chalNaSecondary/.chalNaGhost` |
| 카드 | `ChalNaCard(padding: 16) { ... }` |
| 리스트 행 | `ChalNaListRow.navigate / .toggle / .slider / .check / .plain` + `ChalNaListDivider()` |
| 태그 | `ChalNaTag("LIVE", variant: .live)` — `live/video/neutral/accent` |
| 썸네일 | `MediaThumb(state: .selected, size: nil) { ... }` — 6상태, `size: nil` 이면 9:16 비율로 폭 채움 |
| 캔버스 | `ChalNaCanvas { box in ... } overlay: { box in ... }` — 9:16 aspect-fit. 기하 SSOT `ChalNaCanvasGeometry.fittedBox` |
| 상태 | `ChalNaProgressBar` · `ChalNaEmptyState` · `ChalNaNotice` · `View.chalNaToast(message:onDismiss:)` · `ChalNaBlockingOverlay` |
| 입력 | `ChalNaTextField(...)` · `ChalNaTextArea(...)` · `ChalNaSlider(...)` |
| 아이콘 | `ChalNaIcon(.play, size: 20, weight: .semibold)` — SF Symbols 24종, `@ScaledMetric` 로 Dynamic Type 추종 |
| 화면 배경 | `someView.chalNaScreen()` — `bg` 풀블리드 |
| 스크롤 hairline | `.chalNaScrollHairline(progress: store.scrollProgress)` |

### 여백
- 리터럴 숫자를 쓰되 리듬은 `4 / 8 / 12 / 16 / 20 / 24`.
- **화면 좌우 여백은 20 하나로 통일.**

### 금지 사항
- `Color(hex:)` / `Color(red:green:blue:)` 직접 호출 금지 — 토큰 정의 파일 내부 전용.
- `.font(.system(...))` 직접 호출 금지 — `ChalNaTypography.*` 경유. (`ChalNaIcon` 만 예외)
- `cornerRadius: <숫자>` 리터럴 금지 — `ChalNaRadius.*`.
- `Color.white` / `.white` 금지 — `ChalNaColor.textPrimary` 또는 `.onAccent`.
- `UIColor(named:)` 금지 — 번들 조회가 조용히 실패한다(과거에 검은 띠 버그를 만들었다).
  UIKit 에서 색이 필요하면 `UIColor(ChalNaColor.bg)`.
- `UIFont` 직접 참조 금지 — `ChalNaTypography.kerisUIFont` 경유.
- **`scripts/design-lint.sh` 가 위 5종을 검사한다. 커밋 전에 실행한다.**

### 다크 토큰 적용 예외 (근거 있는 리터럴)
- `Models/ClipLabel.swift` · `TimelineFeature/Components/ClipLabelText.swift` ·
  `TimelineFeature/LabelEditorView.swift` — **라벨 박스는 영상 출력과 픽셀 일치해야 한다.**
  `ClipLabel.BoxStyle` 가 SSOT 이며 UI 테마와 무관하다.
- `DesignSystem/Components/ChalNaTag.swift` · `MediaThumb.swift` —
  다크 위 반투명 오버레이(`Color.white.opacity(...)`)는 토큰으로 표현할 수 없는 합성 연산.
- `Models/ThumbnailPreset.swift` · `ColorHex.swift` — 콘텐츠 그라디언트(크롬이 아님).
```

또한 문서 앞부분의 다음 문장을 수정한다:

- `> **네이밍**: ... 단 **디자인 토큰의 실제 값은 "Danawa DDS Mobile v2.0"** 으로 교체돼 있다 ...`
  → `> **네이밍**: Tuist 타겟·Xcode 프로젝트·번들 ID·디자인 시스템 brand prefix 모두 \`ChalNa\` 로 통일. 디자인은 **다크 시네마틱**이며 액센트는 앱 아이콘의 인디고(#462DE2)에서 역산했다.`
- `## 코드 컨벤션` 절의 `**Spacing/padding 은 토큰 없이 리터럴 숫자**(...)` 뒤에
  `화면 좌우 여백은 20 으로 통일.` 을 추가.

- [ ] **Step 2: AGENTS.md 동기화**

`AGENTS.md` 는 `CLAUDE.md` 의 미러본이고 앞부분에 Codex workflow 노트만 추가돼 있다.
`CLAUDE.md` 의 변경분을 그대로 반영한다.

```bash
diff <(tail -n +$(grep -n '^# ChalNa' AGENTS.md | head -1 | cut -d: -f1) AGENTS.md) \
     <(tail -n +$(grep -n '^# ChalNa' CLAUDE.md | head -1 | cut -d: -f1) CLAUDE.md) \
  | head -40
```

두 파일의 `# ChalNa` 이후 본문이 동일해질 때까지 맞춘다.

- [ ] **Step 3: 최종 전체 검증**

```bash
./scripts/design-lint.sh && echo "LINT OK"
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -3
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa-Workspace \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
           -only-testing:ChalNaUITests test 2>&1 | tail -20
```

Expected: lint OK · `BUILD SUCCEEDED` · 전 스위트 그린 · UI 테스트 2건 PASS.

- [ ] **Step 4: 14개 화면 × 3기기 최종 스크린샷 수집**

`ChalNa Dev` 스킴으로 각 기기에서 전 플로를 돌며 스크린샷을 모은다:

```bash
for DEVICE in "iPhone SE (3rd generation)" "iPhone 17" "iPhone 17 Pro Max"; do
  SHORT=$(echo "$DEVICE" | tr -d ' ()' )
  echo "=== $DEVICE ==="
  xcrun simctl boot "$DEVICE" 2>/dev/null || true
  # Xcode 에서 ChalNa Dev 스킴으로 해당 기기에 실행한 뒤,
  # 각 화면에서 아래를 수동 실행한다:
  #   xcrun simctl io "$DEVICE" screenshot /tmp/final-$SHORT-<화면이름>.png
done
```

수집 대상 14개: `splash` · `home-empty` · `home-grid` · `picker-empty` · `picker-selected` ·
`preview-sheet` · `timeline` · `adjust` · `label-editor` · `export-exporting` · `export-done` ·
`film-detail` · `settings` · `label-position`

각 스크린샷에서 확인할 것:
1. **흰 판이 하나도 없다** (라벨 박스 제외)
2. 텍스트가 잘리거나 겹치지 않는다
3. 하단 CTA·툴바가 화면 안에 있다
4. 액센트 색이 일관되게 인디고다 (마젠타 보라가 남아 있지 않다)

- [ ] **Step 5: 커밋**

```bash
git add CLAUDE.md AGENTS.md
git commit -m "$(cat <<'EOF'
📝 docs: CLAUDE.md · AGENTS.md 디자인 시스템 절 동기화

기존 문서가 "Danawa DDS Mobile v2.0 값", "Asset Catalog ChalNa*.colorset",
".cream/.coral/.sage" 같은 이미 사실과 다른 내용을 담고 있었고
이번 리디자인으로 완전히 무효가 됐다.

- 다크 전용 시맨틱 토큰 표로 교체
- 역할 기반 타이포 6종 + 표준 텍스트 스타일 대응 명시
- 컴포넌트 인벤토리 갱신 (구 6종 삭제 / 신규 반영)
- 금지 사항에 UIColor(named:) · Color.white 추가,
  design-lint.sh 실행을 커밋 전 절차로 명시
- 다크 토큰 적용 예외 4곳을 근거와 함께 문서화

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## 완료 기준

이 계획이 끝났다고 말할 수 있는 조건 — **전부 명령 출력으로 확인한다.**

| # | 조건 | 확인 방법 |
|---|---|---|
| 1 | 정적 검사 5종 0건 | `./scripts/design-lint.sh` → `exit=0` |
| 2 | 앱 빌드 성공 | `xcodebuild ... -scheme ChalNa build` → `BUILD SUCCEEDED` |
| 3 | deprecated 경고 0건 | 빌드 로그에 `is deprecated` 없음 |
| 4 | 전 스위트 그린 | `-scheme ChalNa-Workspace test` |
| 5 | 영상 출력 불변 | `CompositorLabelTests`·`ClipFramingTests`·`CustomLabelLayoutTests`·`CompositionRenderSizeTests` PASS |
| 6 | 대비·아이콘·타이포 규칙 | `DesignSystemTests` 16건 PASS |
| 7 | **SE 세로 예산** | `TimelineLayoutUITests` PASS on iPhone SE (3rd generation) |
| 8 | 크롭 플로 회귀 없음 | `CropAdjustUITests` PASS |
| 9 | 감사 24건 해소 | 스펙 §3 각 항목을 스크린샷/테스트로 대조 |
| 10 | 문서 동기화 | `CLAUDE.md` · `AGENTS.md` 의 `# ChalNa` 이후 본문 동일 |
