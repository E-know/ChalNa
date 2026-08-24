# 라벨 에디터 3개 개선 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 라벨 에디터에 (1) 키보드 위 `다음` + 키보드 하강 시 자동 스텝 전환, (2) 문구 길이에 따른 폰트 자동 축소, (3) 두 손가락 회전·확대를 추가하고 출력 영상까지 WYSIWYG 로 반영한다.

**Architecture:** 텍스트 실측/맞춤 폰트를 `Models.ClipLabelMetrics` 단일 출처로 모아 지금 3곳에 복제된 측정 코드를 대체한다. 회전은 `ClipLabel.rotationRadians` 로 저장하고, 프리뷰는 `ClipLabelText` 내부 `.rotationEffect`, 합성은 배경·텍스트 레이어에 **동일 회전 아핀**을 걸어(두 레이어의 중심이 증명 가능하게 같다) 반영한다. 에디터 배치의 단일 출처를 좌상단 코너 → **정규화 중심**으로 옮겨 "중심 고정" 정책을 계산이 아니라 구조로 만든다.

**Tech Stack:** Swift 6 / iOS 18 / SwiftUI / TCA / Swift Testing / Tuist / AVFoundation + CoreAnimation

**Spec:** `docs/prompt.md`

## Global Constraints

- Swift 6.0+ / iOS 18+ / **SwiftUI 전용** (UIKit 은 불가피한 래핑만).
- **Swift Testing**(`import Testing`/`@Test`/`#expect`). XCTest 는 `ChalNaUITests` 타겟만 예외.
- **GCD 금지**(`DispatchQueue`/`DispatchGroup`). **`ObservableObject`/`@Published` 금지** → `@Observable` + `async/await`.
- spacing/padding 만 리터럴 숫자. 색·타이포·라디우스·모션은 `ChalNaColor`/`ChalNaTypography`/`ChalNaRadius`/`ChalNaMotion` 토큰.
- `./scripts/design-lint.sh` 6개 규칙 **전부 0건** 유지. 파일 단위 예외 추가는 최후 수단이고, **그 파일에 실제 매치가 있을 때만** 등록한다.
- 한국어 주석 OK, 식별자는 영어, 한 파일 = 한 타입.
- 사용자 노출 문자열은 한국어. 새 문자열 추가 시 `-AppleLanguages "(en)"` 로 1회 실행 확인.
- `CompositionService` 는 `DesignSystem`·`TimelineFeature` 를 볼 수 없다. 합성·프리뷰 공유 지점은 **`Models` 뿐**이다.
- 모듈 의존 방향 변경 금지 (`Project.swift` 수정 없음).
- 스코프 밖(금지): `LabelLayout`·`LabelText`·`AutoLabelsOverlay` 의 기하·불투명도·위치 변경(상수 재사용만) · `ClipTransform`/`ClipFraming` 변경 · 멀티라인 자막 · 새 디자인 토큰/컴포넌트 발명 · 요청 무관 인접 리팩터링.
- iOS 빌드·시뮬레이터 실행은 `ios-build-run` 서브에이전트에 위임한다.
- 유닛 테스트: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa-Workspace -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skip-testing:ChalNaUITests test`
- UI 테스트: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChalNaUITests test`
- 기준선: 8개 유닛 스위트 **166 케이스 전부 그린** (2026-08-24, iPhone 17 Pro).

## File Structure

| 파일 | 책임 | 작업 |
|---|---|---|
| `Modules/Models/Sources/ClipLabelMetrics.swift` | **신규.** 박스 자막 텍스트 실측 · 패딩 포함 박스 · 맞춤 폰트(자동 축소) SSOT | 작업 2 |
| `Modules/Models/Sources/ClipLabel.swift` | 저장 모델. `rotationRadians` 추가 + 프리뷰/합성 회전 변환 SSOT | 작업 3 |
| `Modules/CompositionService/Sources/CompositionService.swift` | 합성. 측정 SSOT 위임 · 회전 아핀 · `stampBounds` 회전 바운딩 | 작업 2·3 |
| `Modules/TimelineFeature/Sources/Components/LabelAnchorMath.swift` | 코너↔중심 변환. 측정은 SSOT 위임 | 작업 2 |
| `Modules/TimelineFeature/Sources/Components/ClipLabelText.swift` | 화면 렌더. 회전 + 선택 프레임 내장 | 작업 3 |
| `Modules/TimelineFeature/Sources/LabelEditorView.swift` | 에디터. 키보드 accessory · 자동 전환 · 중심 SSOT · 핀치/회전 제스처 | 작업 1·2·3 |
| `Modules/TimelineFeature/Sources/Components/PreviewPanel.swift` | 타임라인 프리뷰 소비자. fontPx 를 SSOT 로 | 작업 2 |
| `Modules/Models/Tests/…` → 없음 (Models 테스트 타겟 없음) | — | `ClipLabelMetrics` 테스트는 **CompositionServiceTests** 에 둔다(그 타겟이 Models 에 의존) |

> **Models 에는 유닛 테스트 타겟이 없다** (`Project.swift` 의 8개 목록에 없음). 그래서 `ClipLabelMetrics` 계약 테스트는 `Modules/CompositionService/Tests/` 에 신설하고, `ClipLabel` 값 테스트는 기존 관례대로 `Modules/AppCore/Tests/ClipLabelTests.swift` 에 붙인다.

---

## 사전 결정 사항 (구현 전 확인 필요)

이 5개는 `docs/prompt.md` 의 지시를 그대로 따르지 않거나, 프롬프트가 열어둔 선택지를 좁힌 결정이다.

1. **합성 회전은 컨테이너 `CALayer` 가 아니라 배경·텍스트 두 레이어에 같은 아핀을 건다.**
   프롬프트는 컨테이너를 권장했지만(§작업3 구현지침), 이 코드에서는 `bgLayer` 중심 = `origin - pad + paddedSize/2` = `origin + textSize/2` = `textLayer` 중심 이 **항등식으로 성립**한다. CALayer 변환은 자기 `anchorPoint`(기본 중심) 기준이므로 두 레이어에 같은 각도를 걸면 컨테이너와 결과가 동일하다. 대신 컨테이너를 도입하면 `makeCustomLabelLayers` 반환이 `[container]` 1개로 바뀌어 **기존 테스트 4케이스**(`CustomLabelLayoutTests` 3 + `ClipLabelBoxPaletteTests` 1)가 구조적으로 깨진다. 중심 일치는 테스트로 잠근다.
2. **에디터 배치의 단일 출처를 좌상단 코너(`anchorCorner`) → 정규화 중심(`anchorCenter`)으로 바꾼다.**
   "핀치·슬라이더 모두 중심 고정"을 계산으로 맞추지 않고 구조로 만든다. 부수 효과: box 크기 변경 시 `reflow` 의 재산출 로직이 불필요해진다(정규화 중심은 box 무관).
3. **자동 축소는 출력과 같은 기준 캔버스(1080×1920)에서 계산해 *비율*을 돌려준다.**
   그러면 프리뷰(작은 박스)와 합성(1080)이 **완전히 같은 비율**을 쓰므로 계약이 근사치가 아니라 등식이 된다. 하한도 px 이 아니라 `8/1920` 비율로 표현한다.
4. **`ClipLabelText` 에 `selected: Bool = false` 파라미터를 추가한다.**
   `.rotationEffect` 는 레이아웃 크기를 바꾸지 않으므로, 회전을 `ClipLabelText` 안에 두고 선택 프레임을 바깥 `.overlay` 로 두면 프레임이 회전하지 않고 어긋난다. 프레임을 회전 안쪽으로 넣어야 하고, 그 자리는 `ClipLabelText` 내부다.
5. **`LabelEditorView` 의 `@State renderedSizeFraction` 을 `bakedSizeFraction` 으로 개명한다.**
   Task 2 가 `ClipLabel.renderedSizeFraction`(맞춤 결과 비율) 을 도입하므로 이름이 겹쳐 읽는 사람이
   "베이크된 값"과 "맞춤 결과"를 구별할 수 없다. 내 변경이 만든 혼동이라 정리 범위에 든다.
6. **키보드 accessory 바의 배경은 시스템 제공을 쓰고, 버튼만 토큰으로 스타일한다.**
   `ToolbarItemGroup(placement: .keyboard)` 는 바 크롬을 SwiftUI 가 그리고 `.toolbarBackground` 가 이 placement 를 지원하지 않는다. 앱이 다크 전용이라 시스템 크롬이 톤에서 벗어나지 않는다. 새 DesignSystem 컴포넌트는 만들지 않는다.

프롬프트 §5("막히면 물어볼 것")에 해당하는 4개는 이 계획에서 **건드리지 않는다**:
크기 슬라이더 UX(범위·동작) 변경 없음 · 정정 범위는 라벨 코드 밖으로 나가지 않음 ·
저장 구조 변경은 `ClipLabel` 한 곳뿐(`EditSession.labels`·`Film` 무변경) ·
새 `.sheet`/`.fullScreenCover` 추가 없음(따라서 Dynamic Type 상한을 새로 걸 곳도 없음).

---

## 깨질 것으로 예상되는 기존 테스트

| 테스트 | 작업 | 예상 |
|---|---|---|
| `ChalNaUITests/LabelEditorUITests.testLabelEditor_TwoStepFlow_ControlsReachable` | 1 | **갱신 필요.** `다음` 이 nav bar → keyboard accessory 로 이동. 존재/탭 가능 assert 는 유지되지만 위치 주석·흐름 설명을 고친다. |
| `ChalNaUITests/LabelEditorUITests.testLabelEditor_DynamicTypeAccessibility5_CapsAtAccessibility1` | 1 | **통과해야 함**(회귀 가드). `app.buttons["다음"]` 을 그대로 찾아야 한다 — 문자열을 바꾸지 않는 이유. |
| `TimelineFeatureTests/LabelAnchorMathTests.testSizeGrows_TopLeadingCornerFixed_ExpandsRightAndDown` | 3 | **의미가 뒤집혀 교체.** 순수 함수 테스트라 그대로 두면 *통과*하지만 에디터 정책(중심 고정)과 정반대를 설명한다 → 중심 고정 테스트로 대체. |
| `TimelineFeatureTests/LabelAnchorMathTests.testTextGrows_LeadingFixed_TrailingExpands` | 3 | 통과하지만 doc 주석이 스테일 → 주석만 정정(순수 변환 왕복 성질임을 명시). |
| `CompositionServiceTests/CustomLabelLayoutTests.customLabelLayers_ToggleKeepsTextFrame` | 2 | 통과 예상. `sizeFraction 0.12` + "제주 바다" 는 가용폭 경계 부근이라 축소가 걸릴 수 있으나 ON/OFF 가 같이 축소되므로 단언은 유지된다. **실제 실행으로 확인한다.** |
| `TimelineFeatureTests/ClipLabelBoxPaletteTests.paletteMatchesCompositorOutputForBothBackgroundStates` | 3 | 결정 1 때문에 통과 예상(`layers.count == 2` 유지). 컨테이너를 쓰면 깨진다. |
| `CompositionServiceTests/CompositorLabelTests` (2케이스) | 2·3 | 통과 예상. `"TEST"` 는 짧아 축소 미발동, 회전 기본 0. |
| `CompositionServiceTests/PreviewExportContractTests` · `LabelTextTests` · `LabelLayoutTests` · `TimelineFeatureTests/AutoLabelsOverlayFidelityTests` | — | 영향 없음(자동 라벨 기하 미변경, `LabelLayout.paddingFraction` 은 읽기만). |

---

## 작업 순서

**작업 1 → 작업 2 → 작업 3** (프롬프트 권장 순서 그대로). 근거: 작업 1은 나머지와 코드 접점이 거의 없어 검증 루프가 가장 짧고, 작업 2가 측정 SSOT 를 `Models` 로 정리해두면 작업 3의 회전 바운딩 계산이 그 SSOT 위에서 한 번에 끝난다. 각 작업 끝에 커밋한다.

---

### Task 1: 키보드 위 `다음` 버튼 + 키보드 하강 시 자동 스텝 전환

**Files:**
- Modify: `Modules/TimelineFeature/Sources/LabelEditorView.swift` (topBar 88-105 · body 64-83 · backgroundTapped 356-360 · 헤더 doc 5-18)
- Test: `ChalNa/UITests/LabelEditorUITests.swift`

**Interfaces:**
- Consumes: 기존 `KeyboardObserver.height`(`Modules/TimelineFeature/Sources/Components/KeyboardObserver.swift`), `ChalNaNavBar(title:leading:trailing:showsDivider:)` — `trailing` 기본값 `.empty` 라 비울 수 있다.
- Produces: `LabelEditorView` 내부 `@State private var isClosing: Bool` (화면 종료 중 자동 전환 억제 플래그). 다음 Task 들이 이 이름을 다시 쓰지 않는다.

- [ ] **Step 1: 실패하는 UI 테스트 추가** — 키보드를 내리면(다음 버튼을 누르지 않고) `.style` 스텝으로 자동 전환되는지.

`ChalNa/UITests/LabelEditorUITests.swift` 에 추가:

```swift
    /// `[다음]` 을 누르지 않고 **키보드만 내려도** 위치·배경·크기 스텝으로 넘어간다.
    /// devMock 은 시각 검증 채널이 아니므로 도달성(exists/isHittable) 만 본다.
    func testLabelEditor_KeyboardDismiss_AdvancesToStyleStep() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CHALNA_APP_MODE"] = "devMock"
        app.launchArguments += ["-AppleLanguages", "(ko)"]
        app.launch()

        navigateToLabelEditor(app)

        let textField = app.textFields.firstMatch
        XCTAssertTrue(textField.waitForExistence(timeout: 10), "라벨 인라인 TextField")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "스텝 1 키보드")
        XCTAssertFalse(app.sliders.firstMatch.exists, "스텝 1 에 크기 슬라이더가 있으면 안 됨")

        textField.typeText("제주 바다")
        // 리턴(.done)으로 키보드만 내린다 — `[다음]` 은 누르지 않는다.
        textField.typeText("\n")

        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 5),
                      "키보드 하강만으로 스텝 2(크기 슬라이더)에 도달하지 못했다")
        XCTAssertTrue(slider.isHittable, "자동 전환 후 크기 슬라이더를 탭할 수 없음")
        XCTAssertTrue(app.buttons["저장"].firstMatch.exists, "자동 전환 후 저장 버튼 없음")
    }
```

- [ ] **Step 2: 테스트를 돌려 실패를 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChalNaUITests/LabelEditorUITests/testLabelEditor_KeyboardDismiss_AdvancesToStyleStep test`
Expected: FAIL — "키보드 하강만으로 스텝 2(크기 슬라이더)에 도달하지 못했다"

- [ ] **Step 3: `.text` 스텝의 nav bar trailing 을 비우고 `다음` 을 키보드 accessory 로 옮긴다**

`LabelEditorView.topBar` 의 `.text` 케이스:

```swift
        case .text:
            // `[다음]` 은 키보드 바로 위(accessory)로 옮겼다 — 문구 입력 중 시선·엄지 이동을 줄인다.
            // 문자열("다음")은 그대로 유지한다: `LabelEditorUITests` 가 `app.buttons["다음"]` 으로 찾는다.
            ChalNaNavBar(
                title: "라벨",
                leading: .close(action: cancel),
                showsDivider: true
            )
```

`body` 에 키보드 accessory 를 붙인다 (`.safeAreaInset(edge: .bottom) { bottomControls }` 바로 아래):

```swift
        // 문구 스텝의 `[다음]`. SwiftUI 표준 경로(ToolbarItemGroup placement: .keyboard)로
        // 붙이므로 `UIViewRepresentable`(inputAccessoryView) 래핑이 필요 없다.
        // 바 크롬은 SwiftUI 가 그리고 `.toolbarBackground` 는 이 placement 를 지원하지 않는다 —
        // 앱이 다크 전용이라 시스템 크롬이 톤에서 벗어나지 않으므로 버튼만 토큰으로 스타일한다.
        .toolbar {
            if step == .text {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("다음") { goToStyle() }
                        .font(ChalNaTypography.headline)
                        .foregroundColor(ChalNaColor.accent)
                }
            }
        }
```

- [ ] **Step 4: 키보드 하강 → 자동 전환 + 이중 발화/종료 가드**

`@State private var isClosing = false` 를 `@State private var keyboard = KeyboardObserver()` 아래에 추가하고, `body` 의 `.onDisappear { keyboard.stop() }` 아래에 붙인다:

```swift
        // 키보드가 내려갔다는 **사실 하나만** 자동 전환 트리거로 쓴다.
        // 가드 3개가 필요하다:
        //  ① step == .text  — goToStyle() 이 focused=false 로 키보드를 내리므로,
        //     `[다음]` 탭 → 전환 → 하강 → 다시 전환 시도가 되는 이중 발화를 막는다.
        //  ② !isClosing     — onCancel/onCommit 으로 화면이 닫힐 때도 키보드가 내려간다.
        //     사라지는 중에 스텝을 바꾸지 않는다.
        //  ③ didInit        — box 확정 전(진입 직전) 프레임에서 튀지 않게 한다.
        //     `[‹]` 복귀는 안전하다: 복귀 시점 height 는 이미 0 이라 onChange 가 발화하지 않고,
        //     goToText() 의 focused=true 로 0 → 실제 높이로 **올라가는** 변화만 관측된다.
        .onChange(of: keyboard.height) { _, newHeight in
            guard newHeight == 0, step == .text, !isClosing, didInit else { return }
            step = .style
        }
```

`goToStyle`/`goToText`/`backgroundTapped` 와 종료 경로를 정리한다:

```swift
    private func goToStyle() {
        focused = false
        step = .style
    }

    private func goToText() {
        step = .text
        focused = true
    }

    /// 라벨 외 영역 탭 → 키보드만 내린다.
    /// `.text` 에서는 그 하강이 `onChange(of: keyboard.height)` 를 통해 `.style` 자동 전환으로 이어진다
    /// (즉 이 함수는 더 이상 "스텝 유지"를 뜻하지 않는다). `.style` 에서는 할 일이 없다.
    private func backgroundTapped() {
        if step == .text { focused = false }
    }

    /// 화면을 닫는 두 경로. 닫히는 동안의 키보드 하강이 자동 전환을 일으키지 않도록 먼저 표시한다.
    private func cancel() {
        isClosing = true
        onCancel()
    }

    private func commit() {
        isClosing = true
        onCommit(committedLabel())
    }
```

`.style` 케이스의 trailing 도 `commit()` 을 쓰도록 바꾼다: `trailing: .text("저장") { commit() }`.

- [ ] **Step 5: 헤더 doc 의 2스텝 설명을 정정**

`LabelEditorView` 헤더(5-18행)의 `.text` 줄을 교체:

```swift
/// - `.text`  : 키보드 ↑. 인라인 TextField 로 문구만 입력한다. 라벨은 가시영역(상단바~키보드)
///              높이 정중앙으로 띄운다. 하단 컨트롤 없음. `[다음]` 은 **키보드 바로 위
///              (accessory)** 에 있고, `[다음]` 을 누르지 않고 **키보드를 내려도** `.style` 로
///              자동 전환된다(트리거는 "키보드 높이가 0 이 되었다" 하나뿐).
```

- [ ] **Step 6: UI 테스트 통과 확인 + 기존 2케이스 회귀 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChalNaUITests/LabelEditorUITests test`
Expected: 3케이스 PASS. `다음` 이 accessory 에서 `exists && isHittable` 이고, `[‹]` 복귀 후 키보드가 다시 올라온다.

실패 시: `ToolbarItemGroup(placement: .keyboard)` 가 이 계층(NavigationStack 없는 `fullScreenCover`)에서 동작하지 않는 것이므로 `UIViewRepresentable` + `inputAccessoryView` 로 전환하고 **그 근거(관측한 증상)를 커밋 메시지와 보고에 남긴다.**

- [ ] **Step 7: `testLabelEditor_TwoStepFlow_ControlsReachable` 주석 갱신**

`다음` 의 위치가 nav bar 가 아니라 keyboard accessory 임을 doc 주석에 명시한다(assert 자체는 변경 없음 — 존재/탭 가능 검사는 위치와 무관하다).

- [ ] **Step 8: 캔버스·플로팅 회귀 육안 확인**

`ios-build-run` 서브에이전트로 `ChalNa Dev` 스킴 실행 → 라벨 진입 → accessory 추가로 캔버스가 줄지 않고 라벨 플로팅(`displayCornerY`)이 유지되는지 확인. `.ignoresSafeArea(.keyboard, edges: .bottom)` 과 `.safeAreaInset(edge: .bottom)` 조합은 그대로 둔다.

- [ ] **Step 9: 커밋**

```bash
git add Modules/TimelineFeature/Sources/LabelEditorView.swift ChalNa/UITests/LabelEditorUITests.swift
git commit -m "$(cat <<'MSG'
✨ feat: 라벨 문구 스텝의 [다음]을 키보드 accessory 로 + 키보드 하강 시 자동 스텝 전환

- LabelEditorView: .text 스텝 nav bar trailing 비움, ToolbarItemGroup(placement:.keyboard)에 [다음]
- 자동 전환 트리거는 "키보드 높이 0" 하나. 이중 발화(step 가드)·종료 중 전환(isClosing)·초기 프레임(didInit) 가드
- backgroundTapped / 헤더 doc 의 2스텝 설명 정정
- LabelEditorUITests: 키보드 하강 자동 전환 케이스 1개 추가

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
)"
```

---

### Task 2: 문구가 길어지면 폰트 자동 축소

**Files:**
- Create: `Modules/Models/Sources/ClipLabelMetrics.swift`
- Create: `Modules/CompositionService/Tests/ClipLabelMetricsTests.swift`
- Modify: `Modules/TimelineFeature/Sources/Components/LabelAnchorMath.swift:12-32`
- Modify: `Modules/TimelineFeature/Sources/Components/ClipLabelText.swift:40-48`
- Modify: `Modules/CompositionService/Sources/CompositionService.swift:448-481` (`overlayCustomUIFont`·`measureCustomText`·`makeCustomLabelLayers` 의 fontSize)
- Modify: `Modules/TimelineFeature/Sources/Components/PreviewPanel.swift:89-95`
- Modify: `Modules/TimelineFeature/Sources/LabelEditorView.swift` (fontPx 산출 4곳 + 텍스트 변경 시 베이크)

**Interfaces:**
- Produces (다음 Task 와 다른 소비자가 쓰는 정확한 시그니처):
  ```swift
  public enum ClipLabelMetrics {
      public static let referenceCanvas: CGSize            // 1080×1920
      public static let minFontPx: CGFloat                 // 8
      public static var availableWidthFraction: CGFloat    // 1 - LabelLayout.paddingFraction*2 = 0.92
      public static func textSize(_ text: String, fontPx: CGFloat) -> CGSize
      public static func paddedBoxSize(_ text: String, fontPx: CGFloat) -> CGSize
      public static func fittedSizeFraction(text: String, userSizeFraction: CGFloat) -> CGFloat
      public static func fontPx(text: String, userSizeFraction: CGFloat, canvasHeight: CGFloat) -> CGFloat
      #if canImport(UIKit)
      public static func uiFont(px: CGFloat) -> UIFont
      #endif
  }
  ```
- Consumes: `ClipLabel.BoxStyle.{horizontalPaddingFraction, verticalPaddingFraction, letterSpacing(for:)}`, `ClipLabel.{minSizeFraction, maxSizeFraction}`, `LabelLayout.paddingFraction`.

- [ ] **Step 1: 실패하는 테스트를 먼저 쓴다**

`Modules/CompositionService/Tests/ClipLabelMetricsTests.swift` 신규:

```swift
import Foundation
import CoreGraphics
import Testing
import Models
@testable import CompositionService

#if canImport(UIKit)
import QuartzCore
import UIKit
#endif

/// 박스 자막의 텍스트 실측·자동 축소 SSOT(`Models.ClipLabelMetrics`) 계약.
///
/// 이 스위트의 존재 이유: 같은 실측 코드가 예전에 **3곳**(`LabelAnchorMath.textSize`,
/// `ClipLabelText.measuredSize`, `CompositionService.measureCustomText`)에 복제돼 있었고
/// 한쪽만 고쳐도 컴파일·테스트가 조용히 통과했다. 축소 규칙까지 복제되면 프리뷰와 출력이
/// 서로 다른 폰트를 쓴다.
struct ClipLabelMetricsTests {

    private let longText = "제주 바다에서 보낸 아주 길고 긴 하루의 기록"
    private let shortText = "제주"

    /// 가용폭 = 캔버스 폭 × 0.92 (양쪽 4%씩, `LabelLayout.paddingFraction` 재사용).
    private var availableWidth: CGFloat {
        ClipLabelMetrics.referenceCanvas.width * ClipLabelMetrics.availableWidthFraction
    }

    @Test func availableWidthDerivesFromAutoLabelPadding() {
        #expect(ClipLabelMetrics.availableWidthFraction == 1 - LabelLayout.paddingFraction * 2)
    }

    /// 긴 문구는 패딩 포함 박스가 가용폭 안으로 들어온다.
    @Test func longTextShrinksInsideAvailableWidth() {
        let fraction = ClipLabelMetrics.fittedSizeFraction(text: longText, userSizeFraction: 0.25)
        let px = fraction * ClipLabelMetrics.referenceCanvas.height
        let width = ClipLabelMetrics.paddedBoxSize(longText, fontPx: px).width
        #expect(fraction < 0.25, "긴 문구인데 축소가 걸리지 않았다: \(fraction)")
        #expect(width <= availableWidth + 0.5, "축소 후에도 가용폭 초과: \(width) > \(availableWidth)")
    }

    /// 짧은 문구는 사용자 의도 그대로.
    @Test func shortTextKeepsUserFraction() {
        #expect(ClipLabelMetrics.fittedSizeFraction(text: shortText, userSizeFraction: 0.10) == 0.10)
    }

    /// 배경 ON/OFF 에서 결과가 같다 — 패딩을 ON/OFF 동일하게 유지하므로 판정 입력이 같다.
    /// (`fittedSizeFraction` 이 `hasBackground` 를 아예 받지 않는다는 사실 자체가 계약이다.)
    @Test func fitIsIndependentOfBackgroundToggle() {
        let on = ClipLabel(text: longText, sizeFraction: 0.25, hasBackground: true)
        let off = ClipLabel(text: longText, sizeFraction: 0.25, hasBackground: false)
        let a = ClipLabelMetrics.fittedSizeFraction(text: on.text, userSizeFraction: on.clampedSizeFraction)
        let b = ClipLabelMetrics.fittedSizeFraction(text: off.text, userSizeFraction: off.clampedSizeFraction)
        #expect(a == b)
    }

    /// 하한 8px(기준 캔버스 1080×1920 기준 비율). 가용폭을 못 맞춰도 그 아래로 내리지 않는다.
    @Test func stopsAtMinimumFontEvenIfStillOverflowing() {
        let absurd = String(repeating: "가", count: 400)
        let fraction = ClipLabelMetrics.fittedSizeFraction(text: absurd, userSizeFraction: 0.25)
        let px = fraction * ClipLabelMetrics.referenceCanvas.height
        #expect(abs(px - ClipLabelMetrics.minFontPx) < 0.01, "하한 8px 이 지켜지지 않음: \(px)")
    }

    /// 같은 입력 → 같은 출력(결정론). 이분 탐색 반복수가 고정이어야 성립한다.
    @Test func isDeterministic() {
        let a = ClipLabelMetrics.fittedSizeFraction(text: longText, userSizeFraction: 0.25)
        let b = ClipLabelMetrics.fittedSizeFraction(text: longText, userSizeFraction: 0.25)
        #expect(a == b)
    }

    /// 비율은 캔버스 크기와 무관하다 → 프리뷰(작은 박스)와 출력(1080)이 **같은 비율**을 쓴다.
    @Test func fontPxScalesLinearlyWithCanvasHeight() {
        let out = ClipLabelMetrics.fontPx(text: longText, userSizeFraction: 0.25, canvasHeight: 1920)
        let preview = ClipLabelMetrics.fontPx(text: longText, userSizeFraction: 0.25, canvasHeight: 533)
        #expect(abs(preview - out * 533 / 1920) < 1e-9,
                "프리뷰/출력 폰트가 비례하지 않는다: preview \(preview), out \(out)")
    }

    #if canImport(UIKit)
    /// **합성이 실제로 이 SSOT 를 쓰는가.** 레이어에 박힌 폰트 크기를 직접 읽어 비교한다.
    @Test func compositionUsesFittedFontPx() {
        let label = ClipLabel(text: longText, sizeFraction: 0.25, position: CGPoint(x: 0.5, y: 0.5))
        let layers = AVFoundationCompositionService.makeCustomLabelLayers(
            label: label,
            placedRect: CGRect(origin: .zero, size: ClipLabelMetrics.referenceCanvas),
            renderSize: ClipLabelMetrics.referenceCanvas
        )
        let text = layers.last as? CATextLayer
        let attrs = (text?.string as? NSAttributedString)?.attributes(at: 0, effectiveRange: nil)
        let font = attrs?[.font] as? UIFont
        let expected = ClipLabelMetrics.fontPx(
            text: label.text, userSizeFraction: label.clampedSizeFraction,
            canvasHeight: ClipLabelMetrics.referenceCanvas.height
        )
        #expect(font != nil, "합성 텍스트 레이어에 폰트가 없다")
        #expect(abs((font?.pointSize ?? 0) - expected) < 0.01,
                "합성 폰트 \(font?.pointSize ?? 0) != SSOT \(expected)")
    }

    /// 축소가 걸려도 **저장 모델의 사용자 의도는 변하지 않는다**(파생값이다).
    @Test func fitDoesNotMutateStoredSizeFraction() {
        var label = ClipLabel(text: longText, sizeFraction: 0.25)
        _ = ClipLabelMetrics.fittedSizeFraction(text: label.text, userSizeFraction: label.clampedSizeFraction)
        #expect(label.sizeFraction == 0.25)
        label.text = shortText
        #expect(label.sizeFraction == 0.25, "문구를 줄이면 사용자 의도가 그대로 복귀해야 한다")
    }
    #endif
}
```

- [ ] **Step 2: 테스트를 돌려 실패를 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme CompositionService -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:CompositionServiceTests/ClipLabelMetricsTests test`
Expected: 컴파일 실패 — `cannot find 'ClipLabelMetrics' in scope`

- [ ] **Step 3: `ClipLabelMetrics` 를 Models 에 만든다**

`Modules/Models/Sources/ClipLabelMetrics.swift` 신규:

```swift
import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// 박스 자막(`ClipLabel`)의 **폰트 · 실측 · 자동 축소** 단일 진실 공급원.
///
/// 예전엔 같은 실측 코드가 3곳(`LabelAnchorMath.textSize`, `ClipLabelText.measuredSize`,
/// `CompositionService.measureCustomText`)에 바이트 단위로 복제돼 있었다 — 한쪽만 고치면
/// 프리뷰와 출력이 다른 폭을 갖는데 컴파일도 테스트도 조용했다.
///
/// **왜 Models 인가**: `CompositionService` 는 `DesignSystem`·`TimelineFeature` 를 볼 수 없다.
/// 합성과 프리뷰가 공유할 수 있는 유일한 자리가 Models 다(`LabelLayout`·`LabelText` 가 이미
/// 같은 이유로 여기 있다).
///
/// **자동 축소는 기준 캔버스(`referenceCanvas`, 출력과 동일한 1080×1920)에서 계산해 *비율*을
/// 돌려준다.** 그래서 프리뷰(작은 박스)와 합성(1080)이 근사치가 아니라 **정확히 같은 비율**을
/// 쓴다. 하한도 px 이 아니라 `minFontPx / referenceCanvas.height` 비율로 표현한다.
public enum ClipLabelMetrics {

    /// 축소 판정 기준 캔버스 — 출력 캔버스(`AVFoundationCompositionService.outputSize`)와 동일.
    public static let referenceCanvas = CGSize(width: 1080, height: 1920)

    /// 폰트 하한(기준 캔버스 픽셀). 가용폭을 못 맞춰도 이 아래로는 내리지 않고 넘침을 허용한다.
    public static let minFontPx: CGFloat = 8

    /// 라벨 박스가 쓸 수 있는 가로 비율 — 양쪽 각각 캔버스 폭의 4%를 비운다.
    /// 자동 시각/날짜 라벨과 **같은 상수**(`LabelLayout.paddingFraction`)를 재사용해
    /// 화면 전체에서 라벨 여백이 일관되게 한다.
    public static var availableWidthFraction: CGFloat { 1 - LabelLayout.paddingFraction * 2 }

    /// 이분 탐색 반복수. **고정값이어야 결과가 결정론적이다**(합성·프리뷰·에디터가 같은 입력에
    /// 같은 값을 내야 한다). 24회면 [8, 480] px 구간이 ~3e-5px 까지 좁혀진다.
    private static let searchIterations = 24

    // MARK: - Font

    #if canImport(UIKit)
    /// 박스 자막 폰트 — 시스템 light 고정. 합성(`CATextLayer`)·프리뷰가 공유한다.
    public static func uiFont(px: CGFloat) -> UIFont {
        .systemFont(ofSize: px, weight: .light)
    }
    #endif

    // MARK: - Measurement

    /// 텍스트(패딩 제외) 실측 크기. `ceil` 반올림까지 포함해야 프리뷰·합성 박스가 맞는다.
    /// - 비-UIKit(테스트 호스트): 실측 불가 → 글자 수 근사(`LabelText.measure` 와 같은 방식).
    public static func textSize(_ text: String, fontPx: CGFloat) -> CGSize {
        #if canImport(UIKit)
        let measured = NSAttributedString(string: text, attributes: [
            .font: uiFont(px: fontPx),
            .kern: ClipLabel.BoxStyle.letterSpacing(for: fontPx),
        ]).size()
        return CGSize(width: ceil(measured.width), height: ceil(measured.height))
        #else
        return CGSize(width: fontPx * CGFloat(max(text.count, 1)), height: fontPx * 1.4)
        #endif
    }

    /// 패딩 포함 박스 크기. 패딩은 배경 ON/OFF 에서 **동일**하다(합성 정합 유지).
    public static func paddedBoxSize(_ text: String, fontPx: CGFloat) -> CGSize {
        let t = textSize(text, fontPx: fontPx)
        let padX = fontPx * ClipLabel.BoxStyle.horizontalPaddingFraction
        let padY = fontPx * ClipLabel.BoxStyle.verticalPaddingFraction
        return CGSize(width: t.width + padX * 2, height: t.height + padY * 2)
    }

    // MARK: - Auto shrink

    /// 사용자 의도(`sizeFraction`)를 가용폭에 맞춰 축소한 **파생** 비율.
    ///
    /// 저장 모델은 건드리지 않는다 — 슬라이더 값이 제멋대로 튀지 않고, 문구를 짧게 고치면
    /// 원래 크기로 복귀한다. 판정 대상은 **패딩 포함** 박스 폭이므로 배경 ON/OFF 결과가 같다.
    /// 세로(높이) 맞춤은 하지 않는다(자막은 1줄 고정).
    public static func fittedSizeFraction(text: String, userSizeFraction: CGFloat) -> CGFloat {
        let height = referenceCanvas.height
        let available = referenceCanvas.width * availableWidthFraction
        let userPx = userSizeFraction * height
        guard userPx > 0, available > 0 else { return userSizeFraction }
        guard paddedBoxSize(text, fontPx: userPx).width > available else { return userSizeFraction }

        // 하한에서도 넘치면 넘침을 허용하고 하한으로 고정(초장문 방어).
        guard paddedBoxSize(text, fontPx: minFontPx).width <= available else {
            return minFontPx / height
        }
        // 패딩·자간이 fontPx 비례라 대체로 선형이지만 `ceil` 과 kern 때문에 완전 선형은 아니다.
        // 반복수를 고정한 이분 탐색으로 좁히고, 항상 "만족하는 쪽"(lo)을 돌려준다.
        var lo = minFontPx
        var hi = userPx
        for _ in 0..<searchIterations {
            let mid = (lo + hi) / 2
            if paddedBoxSize(text, fontPx: mid).width <= available { lo = mid } else { hi = mid }
        }
        return lo / height
    }

    /// 실제 렌더 폰트(point/pixel). 프리뷰·에디터·합성이 **모두 이 함수를 부른다.**
    public static func fontPx(text: String, userSizeFraction: CGFloat, canvasHeight: CGFloat) -> CGFloat {
        fittedSizeFraction(text: text, userSizeFraction: userSizeFraction) * canvasHeight
    }
}

public extension ClipLabel {
    /// 이 라벨이 실제로 렌더될 폰트 비율(사용자 의도 ∧ 가용폭 맞춤).
    var renderedSizeFraction: CGFloat {
        ClipLabelMetrics.fittedSizeFraction(text: text, userSizeFraction: clampedSizeFraction)
    }

    /// 주어진 캔버스 높이에서의 실제 렌더 폰트 크기.
    func fontPx(canvasHeight: CGFloat) -> CGFloat {
        renderedSizeFraction * canvasHeight
    }
}
```

- [ ] **Step 4: 합성을 SSOT 로 교체**

`CompositionService.swift`:
- `overlayCustomUIFont(fontSize:)` 삭제 → `ClipLabelMetrics.uiFont(px:)` 호출로 교체(2곳: `measureCustomText`, `makeCustomLabelLayers` 의 `.font` 속성).
- `measureCustomText(_:fontSize:)` 삭제 → `ClipLabelMetrics.textSize(_:fontPx:)` 호출.
- `makeCustomLabelLayers` 의 fontSize 산출:

```swift
        // 폰트 크기는 SSOT 에서 받는다 — 문구가 길면 가용폭(캔버스 폭 92%)에 맞춰 자동 축소된다.
        // 하한(8px)도 SSOT 안에 있으므로 여기서 `max(8, …)` 를 따로 걸지 않는다
        // (걸면 축소 규칙이 두 곳으로 갈라진다).
        let fontSize = ClipLabelMetrics.fontPx(
            text: label.text,
            userSizeFraction: label.clampedSizeFraction,
            canvasHeight: placedRect.height
        )
        let textSize = ClipLabelMetrics.textSize(label.text, fontPx: fontSize)
```

`design-lint.sh` 규칙(프로즈) — `UIFont` 직접 참조는 `Models` 경유가 원칙이다. 이 교체로 `CompositionService` 의 `UIFont` 직접 참조가 사라진다는 점을 커밋 메시지에 남긴다.

- [ ] **Step 5: `LabelAnchorMath` · `ClipLabelText` 의 복제 측정 제거**

`LabelAnchorMath.swift`:

```swift
    /// 텍스트(패딩 제외)만의 표시 크기(point). 빈 문자열이면 placeholder("자막 입력") 기준.
    /// 실측은 `Models.ClipLabelMetrics` 가 단일 출처다 — 여기서는 placeholder 치환만 담당한다.
    static func textSize(text: String, fontPx: CGFloat) -> CGSize {
        ClipLabelMetrics.textSize(displayText(text), fontPx: fontPx)
    }

    /// 텍스트 박스(패딩 포함)의 표시 크기(point).
    static func paddedBoxSize(text: String, fontPx: CGFloat) -> CGSize {
        ClipLabelMetrics.paddedBoxSize(displayText(text), fontPx: fontPx)
    }

    /// 빈 문구는 placeholder 로 실측한다 — 편집 중 인라인 TextField 폭을 글자에 맞추기 위함.
    static func displayText(_ text: String) -> String {
        text.isEmpty ? String(localized: "자막 입력") : text
    }
```
`import UIKit` 이 더 이상 필요 없으면 제거한다(내 변경이 만든 orphan).

`ClipLabelText.swift` 의 `measuredSize` 를 `ClipLabelMetrics.textSize(displayString, fontPx: fontPx)` 로 교체하고 `import UIKit` 이 남는지 확인한다.

- [ ] **Step 6: 소비자 3곳의 fontPx 산출을 SSOT 로**

`PreviewPanel.swift:92`:
```swift
            ClipLabelText(label: label, fontPx: label.fontPx(canvasHeight: box.height))
```

`LabelEditorView.labelLayer`:
```swift
        // 위치/드래그/플로팅은 '최종 표시 크기'(맞춤 fontPx) 기준으로 계산한다.
        let fontPx = label.fontPx(canvasHeight: box.height)
        let padded = LabelAnchorMath.paddedBoxSize(text: label.text, fontPx: fontPx)
        let renderedFontPx = bakedSizeFraction * box.height
        let liveScale = renderedSizeFraction > 0 ? label.renderedSizeFraction / renderedSizeFraction : 1
```
`reflow`/`committedLabel` 의 `label.clampedSizeFraction * newBox.height` 도 `label.fontPx(canvasHeight:)` 로 교체한다.

`@State renderedSizeFraction` 을 **`bakedSizeFraction` 으로 개명**하고(사전 결정 5 — `ClipLabel.renderedSizeFraction` 과 이름이 겹친다), 초기값(init 61행)과 슬라이더 `onEditingChanged` 의 베이크를 `initialLabel.renderedSizeFraction` / `label.renderedSizeFraction` 으로 바꾼다 — **베이크 값의 의미가 "사용자 의도"에서 "맞춤 결과"로 통일된다.** `labelLayer` 안의 `renderedFontPx`/`liveScale` 도 `bakedSizeFraction` 기준으로 맞춘다.

**크기 슬라이더의 `range` 는 건드리지 않는다** (`ClipLabel.minSizeFraction...maxSizeFraction` 그대로). 축소가 걸린 상태에서 슬라이더를 올려도 화면 변화가 없을 수 있는데, 그게 의도된 동작이다 — 범위를 동적으로 바꾸는 것은 프롬프트 §작업2 함정에서 금지했고, UX 를 바꿔야 한다고 판단되면 **먼저 물어본다.**

문구 입력 중 불연속을 없애기 위해 텍스트 변경 시에도 베이크한다 (`body` 의 `.onChange` 근처):
```swift
        // 문구가 바뀌면 맞춤 폰트가 달라진다. 타이핑은 연속 제스처가 아니므로 매 입력마다
        // 다시 래스터화해도 문제없다 — 이걸 안 하면 입력 중에는 scaleEffect 로 흐릿하게 커졌다가
        // `[다음]` 에서 갑자기 선명해지는 불연속이 생긴다.
        .onChange(of: label.text) { _, _ in bakedSizeFraction = label.renderedSizeFraction }
```
`inlineEditor(fontPx:)` 는 이미 전달받은 fontPx 를 쓰므로 추가 변경이 없다(같은 맞춤 폰트가 흘러든다).

- [ ] **Step 7: 테스트 실행 — 신규 통과 + 기존 회귀 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa-Workspace -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skip-testing:ChalNaUITests test`
Expected: `ClipLabelMetricsTests` 9케이스 PASS. `CustomLabelLayoutTests`·`ClipLabelBoxPaletteTests`·`CompositorLabelTests`·`LabelAnchorMathTests` 전부 PASS.
`customLabelLayers_ToggleKeepsTextFrame` 이 실패하면 **원인을 먼저 규명한다** — ON/OFF 가 같이 축소되므로 프레임은 같아야 한다. 다르면 패딩이 판정에 비대칭으로 들어간 것이다.

- [ ] **Step 8: `stampBounds` 가 축소를 자동으로 따라가는지 확인 테스트 추가**

`ClipLabelMetricsTests` 에 추가(프롬프트 §작업2 함정 1 — "별도 조치 불필요를 테스트로 확인만"):

```swift
    #if canImport(UIKit)
    /// 오버레이 비트맵 크롭은 레이어 frame 을 읽으므로 축소를 자동으로 따라간다.
    /// 긴 문구(축소 발동)의 박스가 짧은 문구(축소 없음, 같은 sizeFraction)보다 넓지 않아야 한다.
    @Test func shrunkLabelDoesNotWidenLayerBox() {
        func boxWidth(_ text: String) -> CGFloat {
            let layers = AVFoundationCompositionService.makeCustomLabelLayers(
                label: ClipLabel(text: text, sizeFraction: 0.25, position: CGPoint(x: 0.5, y: 0.5)),
                placedRect: CGRect(origin: .zero, size: ClipLabelMetrics.referenceCanvas),
                renderSize: ClipLabelMetrics.referenceCanvas
            )
            return layers.reduce(CGRect.null) { $0.union($1.frame) }.width
        }
        #expect(boxWidth(longText) <= ClipLabelMetrics.referenceCanvas.width,
                "축소된 라벨 박스가 캔버스 폭을 넘는다: \(boxWidth(longText))")
    }
    #endif
```

Run: 같은 명령. Expected: PASS.

- [ ] **Step 9: design-lint + 커밋**

```bash
./scripts/design-lint.sh   # 6개 규칙 전부 0건이어야 한다
git add Modules/Models/Sources/ClipLabelMetrics.swift \
        Modules/CompositionService/Sources/CompositionService.swift \
        Modules/CompositionService/Tests/ClipLabelMetricsTests.swift \
        Modules/TimelineFeature/Sources/Components/LabelAnchorMath.swift \
        Modules/TimelineFeature/Sources/Components/ClipLabelText.swift \
        Modules/TimelineFeature/Sources/Components/PreviewPanel.swift \
        Modules/TimelineFeature/Sources/LabelEditorView.swift
git commit -m "$(cat <<'MSG'
✨ feat: 박스 자막 문구가 길면 폰트 자동 축소 + 측정 SSOT를 Models로 통합

- Models/ClipLabelMetrics 신규: 텍스트 실측 · 패딩 포함 박스 · 맞춤 폰트(기준 캔버스 1080×1920 비율)
  가용폭 = 캔버스 폭 × 0.92 (LabelLayout.paddingFraction 재사용), 하한 8px, 반복수 고정 이분 탐색(결정론)
- 3곳에 복제돼 있던 실측 코드 제거: LabelAnchorMath · ClipLabelText · CompositionService.measureCustomText
- sizeFraction 은 사용자 의도로 보존하고 렌더 폰트를 파생(renderedSizeFraction) — 문구를 줄이면 원래 크기 복귀
- CompositionService: overlayCustomUIFont/measureCustomText 삭제, max(8,…) 도 SSOT 로 이동
- ClipLabelMetricsTests 10케이스 신규 (합성이 SSOT 를 실제로 쓰는지 레이어 폰트로 확인 포함)

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
)"
```

---

### Task 3: `.style` 스텝 두 손가락 회전 + 크기, 중심 고정으로 통일

**Files:**
- Modify: `Modules/Models/Sources/ClipLabel.swift` (필드 추가 + 회전 변환 SSOT + doc 정정)
- Modify: `Modules/CompositionService/Sources/CompositionService.swift` (`makeCustomLabelLayers` 회전 · `customLabelStampRect` 신규 · `stampBounds` 시그니처 · `renderLabelOverlayImage` 평행이동 방식 · 접근 수준)
- Modify: `Modules/TimelineFeature/Sources/Components/ClipLabelText.swift` (회전 + `selected`)
- Modify: `Modules/TimelineFeature/Sources/LabelEditorView.swift` (중심 SSOT · 핀치/회전 제스처)
- Modify: `Modules/TimelineFeature/Sources/Components/LabelAnchorMath.swift` (헤더 doc 정정)
- Test: `Modules/AppCore/Tests/ClipLabelTests.swift` · `Modules/CompositionService/Tests/CustomLabelLayoutTests.swift` · `Modules/CompositionService/Tests/ClipLabelRotationTests.swift`(신규) · `Modules/TimelineFeature/Tests/LabelAnchorMathTests.swift` · `ChalNa/UITests/LabelEditorUITests.swift`

> **자동 축소(Task 2)는 회전 전(unrotated) 박스 폭 기준이다** — `ClipLabelMetrics.fittedSizeFraction`
> 이 회전을 **인자로 받지 않으므로** 이 성질은 계산이 아니라 구조로 보장된다. 회전된 바운딩 박스가
> 캔버스를 넘는 것은 허용한다(사용자가 의도적으로 기울인 결과이고, 회전할 때마다 폰트가 흔들리는 것이
> 더 나쁘다). 이 결정은 코드에 흔적이 남지 않으므로 `ClipLabel.rotationRadians` doc 에 적는다.

**Interfaces:**
- Consumes: `ClipLabelMetrics.{paddedBoxSize, fontPx, textSize}` (Task 2), `LabelAnchorMath.{topLeft(center:in:paddedSize:), center(topLeft:in:paddedSize:)}`.
- Produces:
  ```swift
  // Models/ClipLabel.swift
  public var rotationRadians: CGFloat            // 저장 필드, 기본 0, 시계방향 +
  public var clampedRotationRadians: CGFloat     // −π…π
  public static let rotationSnapRadians: CGFloat // 3° (에디터 스냅 임계)
  public var previewRotation: Angle              // 프리뷰(.rotationEffect) 각도
  public var layerRotationTransform: CGAffineTransform  // 합성(CALayer) 아핀

  // CompositionService (internal, 테스트 도달용)
  static func customLabelStampRect(label: ClipLabel, placedRect: CGRect, renderSize: CGSize) -> CGRect  // y-up
  static func renderLabelOverlayImage(renderSize: CGSize, capturedAt: Date, clipLabel: ClipLabel) -> (image: CGImage, origin: CGPoint)?
  ```

- [ ] **Step 1: 실패하는 모델 테스트를 먼저 쓴다**

`Modules/AppCore/Tests/ClipLabelTests.swift` 에 추가:

```swift
    /// 회전 기본값은 0 — 기존 라벨의 외형이 그대로 유지되어야 한다.
    @Test func defaultRotationIsZero() {
        #expect(ClipLabel().rotationRadians == 0)
        #expect(ClipLabel.default.rotationRadians == 0)
    }

    /// 회전은 값 동등성에 참여한다 — 참여하지 않으면 제스처가 뷰 갱신도, 오버레이 캐시 무효화도 못 만든다.
    @Test func rotationParticipatesInEquality() {
        #expect(ClipLabel(text: "제주 바다", rotationRadians: 0)
                != ClipLabel(text: "제주 바다", rotationRadians: 0.3))
    }

    /// −180°…180° 자유 회전. 그 밖은 clamp.
    @Test func rotationClampsToHalfTurn() {
        #expect(ClipLabel(rotationRadians: 10).clampedRotationRadians == .pi)
        #expect(ClipLabel(rotationRadians: -10).clampedRotationRadians == -.pi)
        #expect(ClipLabel(rotationRadians: 0.5).clampedRotationRadians == 0.5)
    }
```

- [ ] **Step 2: 실패하는 회전 계약 테스트를 쓴다** (프리뷰↔합성 부호 일치 + `stampBounds` 잘림 없음 + 회전 0 회귀)

`Modules/CompositionService/Tests/ClipLabelRotationTests.swift` 신규:

```swift
import Foundation
import CoreGraphics
import QuartzCore
import SwiftUI
import Testing
import Models
@testable import CompositionService

#if canImport(UIKit)
import UIKit
#endif

/// 박스 자막 회전의 기하 계약.
///
/// 위험 지점이 셋이다. ① 오버레이 부모 레이어는 `isGeometryFlipped = true` 라 회전 부호가
/// 뒤집힐 수 있다. ② 오버레이 비트맵은 라벨이 덮는 사각형만 렌더하므로 회전 바운딩을
/// 반영하지 않으면 **모서리가 잘린다.** ③ 회전 0 에서 기존 기하와 픽셀 단위로 같아야 한다.
struct ClipLabelRotationTests {

    private let canvas = CGSize(width: 1080, height: 1920)
    private var placed: CGRect { CGRect(origin: .zero, size: canvas) }

    /// 프리뷰와 합성이 같은 부호 규약을 쓴다. 규약은 `ClipLabel` 한곳에만 있고,
    /// 실제 시각 방향은 아래 `rotatedLabelLeansClockwiseInOverlayBitmap` 이 픽셀로 잠근다.
    @Test func previewAndLayerRotationAgreeOnSign() {
        let label = ClipLabel(text: "제주", rotationRadians: 0.4)
        let preview = label.previewRotation.radians
        let layer = label.layerRotationTransform
        let layerAngle = atan2(layer.b, layer.a)
        #expect(abs(abs(preview) - abs(layerAngle)) < 1e-9, "크기(각도)가 다르다")
        #expect(preview * layerAngle > 0,
                "프리뷰(\(preview))와 합성(\(layerAngle))의 회전 부호가 어긋난다")
    }

    #if canImport(UIKit)
    /// 회전 0: 배경·텍스트 레이어 프레임이 회전 도입 전과 동일해야 한다(회귀 가드).
    /// 기대값은 손계산이 아니라 SSOT(`ClipLabelMetrics` + `customLabelOrigin`)로 재계산해 대조한다.
    @Test func zeroRotationKeepsLegacyGeometry() {
        let label = ClipLabel(text: "제주 바다", sizeFraction: 0.10, position: CGPoint(x: 0.4, y: 0.6))
        let layers = AVFoundationCompositionService.makeCustomLabelLayers(
            label: label, placedRect: placed, renderSize: canvas
        )
        let fontPx = ClipLabelMetrics.fontPx(
            text: label.text, userSizeFraction: label.clampedSizeFraction, canvasHeight: canvas.height
        )
        let textSize = ClipLabelMetrics.textSize(label.text, fontPx: fontPx)
        let origin = AVFoundationCompositionService.customLabelOrigin(
            placedRect: placed, position: label.position, textSize: textSize, renderSize: canvas
        )
        let padX = fontPx * ClipLabel.BoxStyle.horizontalPaddingFraction
        let padY = fontPx * ClipLabel.BoxStyle.verticalPaddingFraction

        #expect(layers.count == 2)
        #expect(layers[1].frame == CGRect(origin: origin, size: textSize))
        #expect(layers[0].frame == CGRect(x: origin.x - padX, y: origin.y - padY,
                                          width: textSize.width + padX * 2,
                                          height: textSize.height + padY * 2))
        #expect(layers.allSatisfy { $0.affineTransform().isIdentity },
                "회전 0 인데 항등이 아닌 변환이 걸렸다")
    }

    /// 회전해도 배경 박스와 텍스트의 **중심이 일치**한다 — 두 레이어에 같은 아핀을 걸어도
    /// 컨테이너와 결과가 같은 이유가 바로 이 중심 일치다. 이게 깨지면 배경이 글자와 어긋난다.
    @Test func rotatedBackgroundAndTextShareCenter() {
        for radians in [0.0, 0.35, -0.9, CGFloat.pi / 2] {
            let label = ClipLabel(text: "제주 바다", sizeFraction: 0.10,
                                  position: CGPoint(x: 0.5, y: 0.5),
                                  rotationRadians: CGFloat(radians))
            let layers = AVFoundationCompositionService.makeCustomLabelLayers(
                label: label, placedRect: placed, renderSize: canvas
            )
            #expect(layers.count == 2)
            let bg = layers[0].position, text = layers[1].position
            #expect(abs(bg.x - text.x) < 1e-6 && abs(bg.y - text.y) < 1e-6,
                    "radians \(radians): 배경 중심 \(bg) != 텍스트 중심 \(text)")
            #expect(abs(atan2(layers[0].affineTransform().b, layers[0].affineTransform().a)
                        - atan2(layers[1].affineTransform().b, layers[1].affineTransform().a)) < 1e-9,
                    "radians \(radians): 두 레이어 회전각이 다르다")
        }
    }

    /// 회전 스탬프 박스가 회전된 바운딩을 **포함**한다(모서리 잘림 없음).
    /// 45° 는 정사각형이 아닌 박스에서 바운딩이 가장 크게 커지는 근방이다.
    @Test func stampRectContainsRotatedBoundingBox() {
        let label = ClipLabel(text: "제주 바다", sizeFraction: 0.10,
                              position: CGPoint(x: 0.5, y: 0.5),
                              rotationRadians: .pi / 4)
        let rect = AVFoundationCompositionService.customLabelStampRect(
            label: label, placedRect: placed, renderSize: canvas
        )
        let upright = AVFoundationCompositionService.customLabelStampRect(
            label: ClipLabel(text: "제주 바다", sizeFraction: 0.10,
                             position: CGPoint(x: 0.5, y: 0.5)),
            placedRect: placed, renderSize: canvas
        )
        #expect(rect.height > upright.height, "45° 회전인데 스탬프 높이가 커지지 않았다")
        #expect(rect.midX == upright.midX && rect.midY == upright.midY,
                "회전은 중심을 옮기지 않아야 한다")
    }

    /// **부호의 시각 방향을 픽셀로 잠근다.** 시계방향 + 이면 오버레이 비트맵에서
    /// 라벨의 오른쪽 절반이 왼쪽 절반보다 아래(top-left 좌표계에서 y 가 큼)에 있어야 한다.
    @Test func rotatedLabelLeansClockwiseInOverlayBitmap() throws {
        let label = ClipLabel(text: "AAAAAA", sizeFraction: 0.10,
                              position: CGPoint(x: 0.5, y: 0.5), rotationRadians: 0.5)
        let rendered = try #require(AVFoundationCompositionService.renderLabelOverlayImage(
            renderSize: canvas, capturedAt: Date(), clipLabel: label
        ))
        let (leftY, rightY) = try opaqueCentroidYByHalf(rendered.image)
        #expect(rightY > leftY,
                "시계방향(+) 회전인데 오른쪽이 아래로 기울지 않았다: left \(leftY), right \(rightY)")
    }

    /// 비트맵의 좌/우 절반에서 불투명 픽셀의 평균 y(top-left 기준).
    /// 자동 시각/날짜 라벨은 우측 하단이라 양쪽 절반에 함께 섞이는데, 그건 회전과 무관한
    /// 공통 항이므로 좌우 **차이** 부호를 뒤집지 않는다 — 라벨을 중앙에 크게 두어 지배시킨다.
    private func opaqueCentroidYByHalf(_ image: CGImage) throws -> (CGFloat, CGFloat) {
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = try #require(pixels.withUnsafeMutableBytes { raw in
            CGContext(data: raw.baseAddress, width: w, height: h,
                      bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        })
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var sums = [CGFloat](repeating: 0, count: 2)
        var counts = [CGFloat](repeating: 0, count: 2)
        for y in 0..<h {
            for x in 0..<w where pixels[(y * w + x) * 4 + 3] > 128 {
                let half = x < w / 2 ? 0 : 1
                sums[half] += CGFloat(y)
                counts[half] += 1
            }
        }
        #expect(counts[0] > 0 && counts[1] > 0, "라벨 픽셀이 좌우 절반 모두에 있어야 한다")
        return (sums[0] / max(counts[0], 1), sums[1] / max(counts[1], 1))
    }

    /// 오버레이 캐시 키(`OverlayKey`)가 회전을 구분한다 — 같은 문구·같은 시각이라도
    /// 회전이 다르면 다른 그림이다. `ClipLabel: Hashable` 이라 자동으로 반영되어야 한다.
    @Test func rotationChangesLabelHashValue() {
        let a = ClipLabel(text: "제주", rotationRadians: 0)
        let b = ClipLabel(text: "제주", rotationRadians: 0.4)
        #expect(a.hashValue != b.hashValue)
    }
    #endif
}
```

- [ ] **Step 3: 두 테스트 파일을 돌려 실패를 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa-Workspace -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skip-testing:ChalNaUITests -only-testing:AppCoreTests/ClipLabelTests -only-testing:CompositionServiceTests/ClipLabelRotationTests test`
Expected: 컴파일 실패 — `extra argument 'rotationRadians' in call`, `cannot find 'customLabelStampRect'`

- [ ] **Step 4: `ClipLabel` 에 회전 필드 + 변환 SSOT 추가, 관련 doc 정정**

```swift
    /// 라벨 기울기(radian). **시계방향이 +**, 0 이 수평. −π…π 자유 회전이며
    /// `clampedRotationRadians` 로 clamp 해 사용한다.
    ///
    /// 프리뷰와 합성의 부호 규약은 `previewRotation`/`layerRotationTransform` 두 파생값에만
    /// 있다 — 합성 오버레이 부모 레이어가 `isGeometryFlipped = true` 라 부호를 손으로 맞추면
    /// 두 경로가 조용히 어긋난다. 실제 시각 방향은 `ClipLabelRotationTests` 가 픽셀로 잠근다.
    public var rotationRadians: CGFloat
```
`init` 에 `rotationRadians: CGFloat = 0` 을 **마지막 파라미터로** 추가한다(기존 호출부 25곳이 그대로 컴파일된다).

```swift
    /// 자유 회전 한계 — 반 바퀴.
    public static let rotationLimit: CGFloat = .pi
    /// 에디터에서 0° 로 스냅되는 임계(±3°). 위치 드래그의 중심 스냅과 같은 패턴이다.
    public static let rotationSnapRadians: CGFloat = 3 * .pi / 180

    public var clampedRotationRadians: CGFloat {
        min(max(rotationRadians, -Self.rotationLimit), Self.rotationLimit)
    }

    /// 프리뷰(SwiftUI `.rotationEffect`)용 각도. 시계방향 +.
    public var previewRotation: Angle { .radians(Double(clampedRotationRadians)) }

    /// 합성(CALayer)용 아핀. 부모가 `isGeometryFlipped = true` 인 상태에서
    /// 프리뷰와 **같은 방향**으로 보이는 부호를 여기 한곳에 둔다.
    public var layerRotationTransform: CGAffineTransform {
        CGAffineTransform(rotationAngle: clampedRotationRadians)
    }
```
`import SwiftUI` 를 `ClipLabel.swift` 에 추가한다(`Angle`; `LabelText.swift` 가 이미 같은 이유로 SwiftUI 를 import 한다).

`hasBackground` doc 의 인과를 정정한다:
```swift
    /// 배경 박스(흰 면 + 검정 테두리) 표시 여부. false 면 흰 글자만 그린다.
    ///
    /// **패딩은 ON/OFF 에서 동일하다.** 근거가 두 개다.
    /// ① 합성(`customLabelOrigin`)은 텍스트 크기만으로 중심을 정하므로 패딩과 무관하다.
    /// ② 자동 축소(`ClipLabelMetrics.fittedSizeFraction`)의 판정 대상이 **패딩 포함 박스 폭**이라,
    ///    패딩이 달라지면 ON/OFF 에서 축소 결과 폰트가 갈린다.
    /// (에디터는 이제 정규화 **중심**을 단일 출처로 쓰므로 패딩이 달라져도 라벨이 움직이지 않는다 —
    ///  좌상단 코너 고정 시절의 근거는 더 이상 유효하지 않다.)
```

Run: `… -only-testing:AppCoreTests/ClipLabelTests test` → PASS 기대.

- [ ] **Step 5: 합성에 회전 적용 + 회전 바운딩 + 평행이동 방식 변경**

`makeCustomLabelLayers` 끝에서 **frame 을 모두 세팅한 뒤** 회전을 건다 (프롬프트 함정 1: 비항등 transform 위에 frame 을 대입하면 동작이 정의되지 않는다):

```swift
        // 회전은 **frame 을 모두 세팅한 뒤** 마지막에 건다 — 비항등 transform 이 걸린 레이어에
        // frame 을 대입하는 것은 동작이 정의되지 않는다.
        //
        // 컨테이너 레이어를 쓰지 않는 이유: `bgLayer` 중심 = origin - pad + paddedSize/2
        // = origin + textSize/2 = `textLayer` 중심 이 항등식으로 성립하고, CALayer 변환은
        // 자기 anchorPoint(기본 중심) 기준이므로 두 레이어에 같은 아핀을 걸면 컨테이너와 결과가
        // 같다. 중심 일치는 `ClipLabelRotationTests.rotatedBackgroundAndTextShareCenter` 가 잠근다.
        let rotation = label.layerRotationTransform
        for layer in result { layer.setAffineTransform(rotation) }
        return result
```
기존 `return [textLayer]` / `return [bgLayer, textLayer]` 두 조기 반환을 지역 변수로 모은다 —
회전을 두 경로에 각각 붙이면 한쪽만 고치는 실수가 가능해진다:

```swift
        var result: [CALayer] = label.hasBackground ? [bgLayer, textLayer] : [textLayer]
```
(배경 OFF 면 `bgLayer` 를 아예 만들지 않도록 기존 `guard label.hasBackground else` 를
`if label.hasBackground { … }` 로 바꾸고 `result` 에 넣는다.)

회전 바운딩 계산 함수를 추가한다 — **`layer.frame` 이 transform 을 반영하는지에 의존하지 않는다**:

```swift
    /// 박스 자막이 캔버스에서 덮는 사각형(**CoreAnimation y-up**, 회전 반영).
    ///
    /// `layer.frame` 이 비항등 transform 을 어떻게 반영하는지에 의존하지 않고 회전 바운딩을
    /// 직접 계산한다 — 이걸 빼먹으면 오버레이 비트맵 크롭이 회전된 라벨 **모서리를 잘라낸다**.
    /// `internal`(테스트 도달용).
    static func customLabelStampRect(label: ClipLabel, placedRect: CGRect, renderSize: CGSize) -> CGRect {
        let fontPx = ClipLabelMetrics.fontPx(
            text: label.text, userSizeFraction: label.clampedSizeFraction, canvasHeight: placedRect.height
        )
        let textSize = ClipLabelMetrics.textSize(label.text, fontPx: fontPx)
        let padded = ClipLabelMetrics.paddedBoxSize(label.text, fontPx: fontPx)
        let origin = customLabelOrigin(
            placedRect: placedRect, position: label.position, textSize: textSize, renderSize: renderSize
        )
        // 박스 중심 = 텍스트 중심(패딩이 대칭이므로). 배경 OFF 라도 패딩 포함 박스를 쓴다 —
        // 패딩을 ON/OFF 동일하게 두는 규칙과 같은 근거이고, 여유가 큰 쪽이 안전하다.
        let center = CGPoint(x: origin.x + textSize.width / 2, y: origin.y + textSize.height / 2)
        let rotated = CGRect(origin: CGPoint(x: -padded.width / 2, y: -padded.height / 2), size: padded)
            .applying(label.layerRotationTransform)
        return rotated.offsetBy(dx: center.x, dy: center.y)
    }
```

`renderLabelOverlayImage` 를 조정한다:
1. `private static` → `static` (테스트 도달용, `makeCustomLabelLayers` 와 같은 이유).
2. 자동 라벨 frame + 위 `customLabelStampRect` 를 모아 y-up 사각형 배열을 만들고, `stampBounds(of:)` 를 `stampBounds(yUpRects:renderSize:)` 로 바꿔 그 배열을 받는다.
3. 평행이동을 `frame` 대입이 아니라 **`position` 이동**으로 바꾼다:

```swift
        // 좌표를 옮길 때 **frame 을 대입하지 않는다** — 회전이 걸린 레이어에 frame 대입은
        // 동작이 정의되지 않는다. `position` 이동은 transform 과 무관하게 정의돼 있고,
        // 항등 변환에서는 frame 평행이동과 결과가 같다.
        // (컨텍스트를 translate 하지 않는 기존 규칙은 그대로다 — `isGeometryFlipped` 의
        //  뒤집기 기준이 그리기 컨텍스트를 따라가면서 완전히 빈 이미지가 되기 때문이다.)
        let yUpBottom = renderSize.height - cropRect.maxY
        for layer in layers {
            layer.position = CGPoint(x: layer.position.x - cropRect.minX,
                                     y: layer.position.y - yUpBottom)
        }
```

Run: `… -only-testing:CompositionServiceTests/ClipLabelRotationTests test`
Expected: PASS. **`rotatedLabelLeansClockwiseInOverlayBitmap` 이 실패하면 `layerRotationTransform` 의 부호를 뒤집고(음수) 다시 돌린다 — 그 결과(어느 부호가 맞았는지)를 doc 주석과 보고에 실측으로 남긴다.** 추론으로 결론내지 않는다.

- [ ] **Step 6: 프리뷰(`ClipLabelText`)에 회전 + 선택 프레임 내장**

```swift
struct ClipLabelText: View {
    let label: ClipLabel
    let fontPx: CGFloat
    var placeholder: Bool = false
    /// 에디터 선택 상태 표시(점선 프레임). **회전 안쪽**에 그려야 프레임이 라벨과 같이 기운다 —
    /// `.rotationEffect` 는 레이아웃 크기를 바꾸지 않으므로, 호출처가 바깥 `.overlay` 로 붙이면
    /// 축 정렬된 사각형이 되어 어긋난다.
    var selected: Bool = false

    var body: some View {
        styledText
            .boxSubtitleStyle(fontPx: fontPx, hasBackground: label.hasBackground)
            .overlay {
                if selected {
                    Rectangle()
                        .strokeBorder(ChalNaColor.accent, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .padding(-3)
                }
            }
            // 회전은 여기 한곳에서만 적용한다 — 호출처마다 `.rotationEffect` 를 붙이면
            // 에디터와 `PreviewPanel` 이 또 갈라진다.
            .rotationEffect(label.previewRotation)
    }
}
```
`LabelEditorView` 의 `selectionFrame` 프로퍼티를 삭제하고(내 변경이 만든 orphan) `labelContent` 를 `ClipLabelText(label: label, fontPx: fontPx, placeholder: isEmpty, selected: true)` 로 바꾼다.

- [ ] **Step 7: 에디터 배치 SSOT 를 좌상단 코너 → 정규화 중심으로 교체**

`LabelEditorView`:
- `@State private var anchorCorner: CGPoint` / `dragBaseCorner` → `@State private var anchorCenter = CGPoint(x: 0.5, y: 0.5)` / `@State private var dragBaseCenter = CGPoint(x: 0.5, y: 0.5)`.
- `labelLayer`: `let corner = LabelAnchorMath.topLeft(center: anchorCenter, in: box, paddedSize: padded)` 를 계산해 `.offset(x: corner.x, y: corner.y)` 로 쓴다. `floatDeltaY` 는 `displayCornerY(...) - corner.y`.
- `displayCornerY`: `anchorCorner.y` 참조를 전달받은 `corner.y` 로 바꾼다.
- `applyDrag`: 중심 기준으로 단순화한다 — 회전과 무관해진다.

```swift
    /// 드래그 결과 중심에 중심 스냅 + 0…1 clamp 적용.
    /// 중심을 직접 옮기므로 **회전 각도와 무관**하다(회전된 박스의 코너를 환산할 필요가 없다).
    private func applyDrag(translation: CGSize, box: CGSize) {
        guard box.width > 0, box.height > 0 else { return }
        var center = CGPoint(x: dragBaseCenter.x + translation.width / box.width,
                             y: dragBaseCenter.y + translation.height / box.height)
        center.x = min(max(center.x, 0), 1)
        center.y = min(max(center.y, 0), 1)
        let eps: CGFloat = 0.02
        showVGuide = abs(center.x - 0.5) < eps
        showHGuide = abs(center.y - 0.5) < eps
        if showVGuide { center.x = 0.5 }
        if showHGuide { center.y = 0.5 }
        anchorCenter = center
    }
```
- `reflow`: box 변경 시 재산출이 **불필요해진다**(정규화 중심은 box 무관).

```swift
    /// box(가용 영역) 확정에 맞춰 배치를 초기화한다.
    /// 배치 단일 출처가 **정규화 중심**이라 box 크기가 바뀌어도 재산출할 것이 없다
    /// (좌상단 코너를 저장하던 시절에는 box 마다 코너를 다시 계산해야 했다).
    private func reflow(to newBox: CGSize) {
        guard newBox.width > 0, newBox.height > 0 else { return }
        boxSize = newBox
        guard !didInit else { return }
        anchorCenter = label.position
        didInit = true
        focused = true   // 진입은 항상 문구 스텝
    }
```
호출부(`canvas` 의 `.onAppear`/`.onChange`)를 `reflow(to:)` 로 맞춘다.
- `committedLabel`: `result.position = anchorCenter` (역산 불필요).
- 헤더 doc(17-18행)을 정정:

```swift
/// 배치는 **정규화 중심 `anchorCenter`(0…1)** 를 단일 출처로 삼는다 — 저장 모델
/// `ClipLabel.position` 과 같은 좌표계라 커밋 시 역산이 없다. 크기(슬라이더·핀치)가 바뀌어도
/// 중심이 그대로이므로 라벨은 **중심 고정으로 확대/축소**된다(좌상단 코너 고정이었던 예전 규칙을
/// 핀치 도입과 함께 중심 고정으로 통일했다).
```
`LabelAnchorMath` 헤더 doc 도 같은 취지로 정정한다(순수 코너↔중심 변환 함수이며, 에디터의 고정 코너 정책은 사라졌다는 사실).

- [ ] **Step 8: 두 손가락 핀치 + 회전 제스처**

`@State private var pinchBaseFraction: CGFloat = 0` / `@State private var rotateBaseRadians: CGFloat = 0` / `@State private var isTransforming = false` 를 추가하고 `labelContent` 의 `.style` 케이스에 붙인다:

```swift
            ClipLabelText(label: label, fontPx: fontPx, placeholder: isEmpty, selected: true)
                .contentShape(Rectangle())
                .onTapGesture { goToText() }
                .gesture(dragGesture(box: box))
                // 한 손가락 드래그(위치)와 두 손가락 확대/회전은 필요한 터치 수가 달라 서로
                // 가로채지 않는다. 확대와 회전은 **동시 인식**해야 한 동작으로 느껴진다.
                .simultaneousGesture(magnifyAndRotateGesture)
```

```swift
    /// 두 손가락: 확대/축소(크기) + 기울기(회전)를 동시에. iOS 18 API(`MagnifyGesture`/`RotateGesture`).
    /// 크기는 슬라이더와 **같은 `sizeFraction`** 을 공유하므로 두 컨트롤이 자동으로 동기화된다.
    private var magnifyAndRotateGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .simultaneously(with: RotateGesture(minimumAngleDelta: .degrees(1)))
            .onChanged { value in
                if !isTransforming {
                    isTransforming = true
                    pinchBaseFraction = label.clampedSizeFraction
                    rotateBaseRadians = label.clampedRotationRadians
                }
                if let magnification = value.first?.magnification {
                    let proposed = pinchBaseFraction * magnification
                    label.sizeFraction = min(max(proposed, ClipLabel.minSizeFraction),
                                             ClipLabel.maxSizeFraction)
                }
                if let rotation = value.second?.rotation {
                    let proposed = rotateBaseRadians + CGFloat(rotation.radians)
                    let clamped = min(max(proposed, -ClipLabel.rotationLimit), ClipLabel.rotationLimit)
                    // 0° 스냅 — 위치 드래그의 중심 스냅(eps 0.02)과 같은 패턴.
                    label.rotationRadians = abs(clamped) < ClipLabel.rotationSnapRadians ? 0 : clamped
                }
            }
            .onEnded { _ in
                isTransforming = false
                // 제스처 종료 시 현재 크기로 베이크 → scaleEffect=1 로 글자를 선명하게 재렌더
                // (크기 슬라이더의 onEditingChanged 와 같은 규칙).
                bakedSizeFraction = label.renderedSizeFraction
            }
    }
```
`dragGesture` 는 `applyDrag(translation:box:)` 시그니처에 맞춰 `padded` 인자를 제거하고 `dragBaseCenter = anchorCenter` 로 기준을 잡는다.

- [ ] **Step 9: `LabelAnchorMathTests` 의 코너 고정 테스트를 중심 고정으로 교체**

`testSizeGrows_TopLeadingCornerFixed_ExpandsRightAndDown` 을 삭제하고 대체:

```swift
    /// 에디터 정책: 크기(슬라이더·핀치)가 변해도 **중심이 고정**된다.
    /// 배치 단일 출처가 정규화 중심이므로, 같은 중심에서 코너를 다시 뽑으면
    /// 박스가 커진 만큼 좌·상으로 균등하게 벌어진다(우하로만 확장하던 예전 규칙을 통일함).
    @Test func testSizeGrows_CenterFixed_ExpandsEvenly() {
        let center = CGPoint(x: 0.35, y: 0.35)
        let small = LabelAnchorMath.topLeft(center: center, in: box, paddedSize: CGSize(width: 90, height: 40))
        let large = LabelAnchorMath.topLeft(center: center, in: box, paddedSize: CGSize(width: 150, height: 70))

        #expect(large.x < small.x, "크기 ↑ → 좌측으로도 벌어진다(중심 고정)")
        #expect(large.y < small.y, "크기 ↑ → 위로도 벌어진다(중심 고정)")
        #expect(abs((small.x - large.x) - (150 - 90) / 2) < 1e-9, "좌우 균등 확장")
        #expect(abs((small.y - large.y) - (70 - 40) / 2) < 1e-9, "상하 균등 확장")

        // 중심은 보존된다.
        let backSmall = LabelAnchorMath.center(topLeft: small, in: box, paddedSize: CGSize(width: 90, height: 40))
        let backLarge = LabelAnchorMath.center(topLeft: large, in: box, paddedSize: CGSize(width: 150, height: 70))
        #expect(abs(backSmall.x - backLarge.x) < 1e-9 && abs(backSmall.y - backLarge.y) < 1e-9)
    }
```
`testTextGrows_LeadingFixed_TrailingExpands` 는 단언을 유지하고 doc 주석만 정정한다 — "이건 순수 변환의 성질이며 에디터 정책이 아니다"를 명시.

- [ ] **Step 10: 실제 export 프레임 픽셀 샘플링으로 잘림 없음 확인**

`Modules/CompositionService/Tests/CompositorLabelTests.swift` 에 추가(같은 파일의 `makeSolidGrayVideo`/`exportAndSample`/`PixelSampler` 헬퍼 재사용):

```swift
    /// 회전된 라벨이 오버레이 비트맵 크롭에서 **잘리지 않는지** 실제 export 프레임으로 확인한다.
    /// 회전 45°: 축 정렬 박스보다 바운딩이 커지므로, 크롭이 회전을 반영하지 않으면
    /// 상·하 모서리의 흰 픽셀이 사라진다.
    @Test func testCompositor_RotatedLabel_CornersNotClipped() async throws {
        let srcURL = try await makeSolidGrayVideo(width: 640, height: 360, seconds: 0.5, fps: 24)
        defer { try? FileManager.default.removeItem(at: srcURL) }

        let clip = Clip(kind: .video, capturedAt: Date(), duration: 0.5, preset: .jejuSea,
                        thumbnailData: nil, videoURL: srcURL,
                        displaySize: CGSize(width: 640, height: 360))
        let upright = ClipLabel(text: "TEST", sizeFraction: 0.12, position: CGPoint(x: 0.5, y: 0.5))
        var rotated = upright
        rotated.rotationRadians = .pi / 4

        let samplerUpright = try await exportAndSample(clip: clip, clipLabels: [clip.id: upright])
        let samplerRotated = try await exportAndSample(clip: clip, clipLabels: [clip.id: rotated])

        // 회전 박스의 대각선은 축 정렬 박스보다 세로로 길다 → 중앙 세로 띠를 넓게 잡아 비교한다.
        let region = CGRect(x: 380, y: 800, width: 320, height: 320)
        expectClearOfAutoLabelStamp(
            [(Int(region.minX), Int(region.minY)), (Int(region.maxX), Int(region.maxY))],
            capturedAt: clip.capturedAt
        )
        let whiteUpright = samplerUpright.countNearWhite(in: region, threshold: 220)
        let whiteRotated = samplerRotated.countNearWhite(in: region, threshold: 220)
        print("[CompositorLabelTests] rotated=\(whiteRotated) upright=\(whiteUpright)")

        // 잘림이 있으면 회전 쪽 흰 픽셀이 급감한다. 박스 면적은 회전으로 보존되므로
        // 90% 이상 남아야 한다(안티에일리어싱 경계 손실만 허용).
        #expect(whiteRotated > Int(Double(whiteUpright) * 0.9),
                "회전된 라벨이 잘린 것으로 보인다: rotated=\(whiteRotated) upright=\(whiteUpright)")
    }
```

Run: `… -only-testing:CompositionServiceTests/CompositorLabelTests test`
Expected: PASS.

- [ ] **Step 11: UI 스모크 테스트 추가(도달성·무크래시만)**

`ChalNa/UITests/LabelEditorUITests.swift`:

```swift
    /// `.style` 스텝에서 두 손가락 확대/회전 후 크래시 없이 컨트롤에 도달하는지.
    /// devMock 은 시각 검증 채널이 아니므로 **기하 단언을 걸지 않는다** — 도달성·무크래시만 본다.
    func testLabelEditor_PinchAndRotate_NoCrashControlsReachable() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CHALNA_APP_MODE"] = "devMock"
        app.launchArguments += ["-AppleLanguages", "(ko)"]
        app.launch()

        navigateToLabelEditor(app)

        let textField = app.textFields.firstMatch
        XCTAssertTrue(textField.waitForExistence(timeout: 10), "라벨 인라인 TextField")
        textField.typeText("제주 바다")
        app.buttons["다음"].firstMatch.tap()

        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 5), "스텝 2 크기 슬라이더")

        app.pinch(withScale: 1.5, velocity: 1.0)
        app.rotate(0.5, withVelocity: 1.0)

        XCTAssertTrue(slider.isHittable, "제스처 후 크기 슬라이더 도달 불가")
        XCTAssertTrue(app.buttons["저장"].firstMatch.isHittable, "제스처 후 저장 버튼 도달 불가")
        app.buttons["저장"].firstMatch.tap()
        XCTAssertTrue(app.buttons["라벨"].firstMatch.waitForExistence(timeout: 10),
                      "저장 후 타임라인 복귀 실패")
    }
```

Run: `xcodebuild … -only-testing:ChalNaUITests/LabelEditorUITests test`
Expected: 4케이스 PASS.

- [ ] **Step 12: design-lint + 커밋**

```bash
./scripts/design-lint.sh
git add Modules/Models/Sources/ClipLabel.swift \
        Modules/CompositionService/Sources/CompositionService.swift \
        Modules/CompositionService/Tests/ClipLabelRotationTests.swift \
        Modules/CompositionService/Tests/CompositorLabelTests.swift \
        Modules/TimelineFeature/Sources/Components/ClipLabelText.swift \
        Modules/TimelineFeature/Sources/Components/LabelAnchorMath.swift \
        Modules/TimelineFeature/Sources/LabelEditorView.swift \
        Modules/TimelineFeature/Tests/LabelAnchorMathTests.swift \
        Modules/AppCore/Tests/ClipLabelTests.swift \
        ChalNa/UITests/LabelEditorUITests.swift
git commit -m "$(cat <<'MSG'
✨ feat: 라벨 두 손가락 회전·확대 + 크기 조절을 중심 고정으로 통일

- ClipLabel: rotationRadians(시계방향 +, −π…π) 추가. 부호 규약은 previewRotation/layerRotationTransform 두 파생값에만
- 합성: frame 세팅 후 배경·텍스트 레이어에 동일 아핀(두 레이어 중심이 항등식으로 일치 → 컨테이너와 동일)
- customLabelStampRect 신규: 회전 바운딩을 직접 계산해 오버레이 크롭 잘림 방지. 평행이동은 frame 대입 → position 이동
- ClipLabelText: 회전·선택 프레임 내장(회전 안쪽) — 호출처 복제 방지
- LabelEditorView: 배치 SSOT 를 좌상단 코너 → 정규화 중심. reflow 재산출 로직 제거, 커밋 역산 없음
- MagnifyGesture+RotateGesture 동시 인식, 0° 스냅(±3°), 종료 시 베이크
- 테스트: ClipLabelRotationTests 신규 6 · ClipLabelTests +3 · CompositorLabelTests +1(회전 잘림 픽셀 가드)
  · LabelAnchorMathTests 코너 고정 → 중심 고정으로 교체 · UI 스모크 1

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
)"
```

---

### Task 4: 최종 검증 + 문서 정정

**Files:**
- Modify: `CLAUDE.md` (라벨 2스텝 플로우 · 패딩 대칭 근거 · 박스 자막 스타일 · 테스트 케이스 수 · UI 테스트 목록)
- Test: 전체 스위트

- [ ] **Step 1: `tuist generate` + 전체 유닛 테스트**

```bash
tuist generate
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa-Workspace \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           -skip-testing:ChalNaUITests test
```
Expected: 8개 스위트 그린. **실제 케이스 수를 세어 기록한다** (166 → 예상 **186**: `ClipLabelMetricsTests` 10 · `ClipLabelRotationTests` 6 · `ClipLabelTests` +3 · `CompositorLabelTests` +1 · `LabelAnchorMathTests` ±0(1 교체) · `LabelEditorUITests` +2 는 UI 타겟이라 8스위트 합계에 안 들어간다 → 166+20=186). 실제 수가 예상과 다르면 그 차이의 원인을 보고에 적는다.

- [ ] **Step 2: UI 테스트**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           -only-testing:ChalNaUITests test
```
Expected: `LabelEditorUITests` 4케이스 + 나머지 3파일 전부 PASS.

- [ ] **Step 3: design lint + 영어 로케일 1회 실행**

```bash
./scripts/design-lint.sh
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           -only-testing:ChalNaUITests/LabelEditorUITests test
```
새 사용자 노출 문자열은 `다음`(기존) 하나뿐이라 카탈로그 추가가 필요 없다 — 그 사실을 `-AppleLanguages "(en)"` 실행으로 확인한다. 새 문자열이 생겼다면 `Localizable.xcstrings` 에 en/ja 를 추가한다.

- [ ] **Step 4: 시뮬레이터 엔드투엔드 1회 통과**

`ios-build-run` 서브에이전트에 위임: 문구 스텝 → 키보드 내림 → 자동 전환 → 두 손가락 회전/확대 → 저장 → 타임라인 프리뷰 → export. 프리뷰와 출력 영상의 라벨 기울기·크기가 일치하는지 확인하고 스크린샷을 보고에 첨부한다.

- [ ] **Step 5: `CLAUDE.md` 정정** (틀린 인과를 남기지 않는다)

- "비디오 합성 원칙" 의 박스 자막 문단: **패딩 ON/OFF 동일 유지의 근거를 갱신한다.** 에디터가 좌상단 코너를 고정하던 비대칭 설명은 더 이상 유효하지 않다(정규화 중심이 SSOT). 새 근거는 ① 합성이 텍스트 크기만으로 중심을 정한다 ② 자동 축소 판정 대상이 패딩 포함 박스 폭이라 패딩이 갈리면 ON/OFF 폰트가 갈린다.
- 같은 문단에 **문구 자동 축소**를 추가: 가용폭 = 캔버스 폭 × 0.92(`LabelLayout.paddingFraction` 재사용), `sizeFraction` 은 사용자 의도로 보존하고 렌더 폰트는 파생, 하한 8px, SSOT 는 `Models.ClipLabelMetrics`, 회전 전 박스 기준.
- **회전**을 추가: `ClipLabel.rotationRadians`(시계방향 +, −180°…180°, 0° 스냅 ±3°), 출력 영상 반영, 부호 규약이 `previewRotation`/`layerRotationTransform` 두 파생값에만 있는 이유(`isGeometryFlipped`), `customLabelStampRect` 로 회전 바운딩을 직접 계산하는 이유(모서리 잘림).
- 라벨 2스텝 플로우 서술: `[다음]` 이 키보드 accessory 에 있고 **키보드 하강만으로도** 스텝 2로 넘어간다는 사실.
- "테스트" 절의 케이스 수를 Step 1 의 실측값으로 갱신하고 증감 내역을 적는다.
- `ChalNaUITests` 파일 설명(`LabelEditorUITests` 케이스 수 2 → 4)을 갱신한다.

- [ ] **Step 6: 커밋**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'MSG'
📝 docs: CLAUDE.md 에 라벨 자동 축소·회전·키보드 accessory 반영 + 패딩 대칭 근거 정정

- 패딩 ON/OFF 동일 유지의 근거 갱신: 에디터 SSOT 가 좌상단 코너 → 정규화 중심으로 바뀌어
  기존 "코너 고정 + 패딩 동일" 인과가 무효. 새 근거는 합성 중심 계산 + 자동 축소 판정 입력
- 문구 자동 축소(가용폭 0.92 · 하한 8px · sizeFraction 보존) · 회전(부호 규약·stamp 바운딩) 추가
- 2스텝 플로우: [다음] 키보드 accessory + 키보드 하강 자동 전환
- 테스트 케이스 수·UI 테스트 목록 실측 갱신

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
)"
```
