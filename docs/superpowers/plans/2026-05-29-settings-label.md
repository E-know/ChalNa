# 설정 화면 + 라벨 ON/OFF·9구역 위치 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Home 헤더의 설정 버튼을 노출하고, 시각/날짜 라벨의 ON/OFF·9구역 위치를 고르는 설정 화면을 추가해 익스포트 영상 오버레이에 반영한다.

**Architecture:** TCA(@Reducer/@ObservableState) + `@Shared(.appStorage)` 영속. 신규 `SettingsFeature` 모듈(리스트 + 9구역 피커), 기존 `AppRouter`→`AppFeature.Path` 네비게이션 패턴 그대로. 9구역 위치는 `Models`의 순수 enum `LabelPosition`으로 모델링하고 `CompositionService.export(...labelSettings:)`로 전달. CompositionService는 설정을 인자로만 받는 순수 함수 유지.

**Tech Stack:** Swift 6 / iOS 18 / SwiftUI / The Composable Architecture 1.18 / Tuist / Swift Testing / AVFoundation.

**Spec:** `docs/superpowers/specs/2026-05-29-settings-label-design.md`

> **커밋 정책:** 각 Task 마지막의 커밋 단계는 계획의 일부다. 단, 이 저장소에서는 사용자가 커밋을 명시 요청할 때만 실제 커밋한다 — 실행 시 커밋 시점은 사용자 지시에 따른다.

> **빌드/테스트 공통 명령**
> - 프로젝트 재생성(타겟/의존성 변경 후 필수): `tuist generate`
> - 빌드: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
> - 단일 테스트: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:<타겟>/<스위트>/<케이스>`
> - 기존 모듈의 `Tests/`·`Sources/` 폴더에 **파일 추가**는 Tuist synchronized folder라 재생성 불필요. **새 타겟/의존성**은 `tuist generate` 필요.

---

## File Structure

신규
- `Modules/Models/Sources/LabelSettings.swift` — `LabelPosition`(9구역 + 순수 `origin()`), `LabelSettings`(값 묶음), `LabelKind`(time/date).
- `Modules/SettingsFeature/Sources/SettingsFeature.swift` — 설정 리스트 Reducer.
- `Modules/SettingsFeature/Sources/SettingsView.swift` — 설정 리스트 View.
- `Modules/SettingsFeature/Sources/LabelPositionFeature.swift` — 9구역 피커 Reducer.
- `Modules/SettingsFeature/Sources/LabelPositionPickerView.swift` — 피커 View(미니 미리보기 + 3×3).
- `Modules/SettingsFeature/Tests/SettingsModuleSmokeTests.swift` — 타겟 헬스 체크.
- `Modules/SettingsFeature/Tests/LabelPositionTests.swift` — `origin()` 9구역 검증.
- `Modules/SettingsFeature/Tests/SettingsFeatureTests.swift` — 토글 → @Shared.
- `Modules/SettingsFeature/Tests/LabelPositionFeatureTests.swift` — 구역 선택 → @Shared.

변경
- `Project.swift` — SettingsFeature 프레임워크/테스트 타겟, 앱 deps.
- `Modules/AnalyticsService/Sources/AnalyticsEvent.swift` — 이벤트 3종.
- `Modules/AppCore/Sources/AppRouter.swift` — `Route` += settings/labelPosition.
- `ChalNa/Sources/App/AppFeature.swift` — Path/Action/Reduce.
- `ChalNa/Sources/App/RootView.swift` — destination/handler.
- `Modules/HomeFeature/Sources/HomeView.swift` — gear 버튼 복원.
- `Modules/CompositionService/Sources/CompositionService.swift` — `labelSettings` 인자.
- `Modules/CompositionService/Sources/CompositionClient.swift` — `labelSettings` 인자.
- `Modules/ExportFeature/Sources/ExportFeature.swift` — `@Shared` 읽어 전달.

---

## Task 1: SettingsFeature 모듈 + 테스트 타겟 스캐폴드

**Files:**
- Modify: `Project.swift`
- Create: `Modules/SettingsFeature/Sources/SettingsFeature.swift`
- Create: `Modules/SettingsFeature/Tests/SettingsModuleSmokeTests.swift`

- [ ] **Step 1: SettingsFeature 프레임워크 타겟 추가 (`Project.swift`)**

`TimelineFeature` 타겟 정의 블록 바로 다음(앱 타겟 `.target(name: "ChalNa", ...)` 앞)에 추가:

```swift
        Module.framework(
            name: "SettingsFeature",
            dependencies: [
                .target(name: "AppCore"),
                .target(name: "AnalyticsService"),
                .target(name: "Models"),
                .target(name: "DesignSystem"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
```

- [ ] **Step 2: 앱 타겟 의존성에 SettingsFeature 추가 (`Project.swift`)**

`.target(name: "ChalNa", ...)`의 `dependencies:` 배열에서 `.target(name: "FilmDetailFeature"),` 다음 줄에 추가:

```swift
                .target(name: "SettingsFeature"),
```

- [ ] **Step 3: 테스트 타겟 추가 (`Project.swift`)**

`Module.unitTests(for: "TimelineFeature", ...)` 블록 다음에 추가:

```swift
        Module.unitTests(
            for: "SettingsFeature",
            dependencies: [
                .target(name: "Models"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
```

- [ ] **Step 4: 플레이스홀더 Reducer 생성 (`Modules/SettingsFeature/Sources/SettingsFeature.swift`)**

```swift
import ComposableArchitecture

@Reducer
public struct SettingsFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action {
        case onAppear
    }

    public var body: some ReducerOf<Self> {
        Reduce { _, _ in .none }
    }
}
```

- [ ] **Step 5: 스모크 테스트 생성 (`Modules/SettingsFeature/Tests/SettingsModuleSmokeTests.swift`)**

```swift
import Testing
@testable import SettingsFeature

struct SettingsModuleSmokeTests {
    @Test func reducerStateInitializes() {
        _ = SettingsFeature.State()
    }
}
```

- [ ] **Step 6: 프로젝트 재생성**

Run: `tuist generate`
Expected: 성공, `SettingsFeature`·`SettingsFeatureTests` 스킴 생성.

- [ ] **Step 7: 빌드 + 스모크 테스트**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:SettingsFeatureTests/SettingsModuleSmokeTests`
Expected: BUILD SUCCEEDED, 1 test PASS.

- [ ] **Step 8: Commit**

```bash
git add Project.swift Modules/SettingsFeature ChalNa.xcodeproj
git commit -m "🏗️ chore: SettingsFeature 모듈/테스트 타겟 스캐폴드"
```

---

## Task 2: Models — LabelPosition / LabelSettings / LabelKind (TDD)

**Files:**
- Test: `Modules/SettingsFeature/Tests/LabelPositionTests.swift`
- Create: `Modules/Models/Sources/LabelSettings.swift`

- [ ] **Step 1: 실패하는 테스트 작성 (`Modules/SettingsFeature/Tests/LabelPositionTests.swift`)**

```swift
import Testing
import CoreGraphics
import Models

struct LabelPositionTests {
    let render = CGSize(width: 1000, height: 2000)
    let text = CGSize(width: 100, height: 40)
    let pad = CGSize(width: 20, height: 20)

    @Test func centerIsCentered() {
        let o = LabelPosition.center.origin(renderSize: render, textSize: text, padding: pad)
        #expect(o.x == 450)   // (1000-100)/2
        #expect(o.y == 980)   // (2000-40)/2
    }

    @Test func topLeftRespectsPadding() {
        let o = LabelPosition.topLeft.origin(renderSize: render, textSize: text, padding: pad)
        #expect(o.x == 20)     // minX
        #expect(o.y == 1940)   // maxY = 2000-20-40 (CoreAnimation: top = 큰 y)
    }

    @Test func bottomRightRespectsPadding() {
        let o = LabelPosition.bottomRight.origin(renderSize: render, textSize: text, padding: pad)
        #expect(o.x == 880)    // 1000-20-100
        #expect(o.y == 20)     // minY (bottom)
    }

    @Test func bottomCenterMatchesLegacyDefault() {
        let o = LabelPosition.bottomCenter.origin(renderSize: render, textSize: text, padding: pad)
        #expect(o.x == 450)
        #expect(o.y == 20)
    }

    @Test func nineCasesWithKoreanNames() {
        #expect(LabelPosition.allCases.count == 9)
        #expect(LabelPosition.allCases.allSatisfy { !$0.koreanName.isEmpty })
    }

    @Test func defaultSettingsMatchCurrentExport() {
        let s = LabelSettings.default
        #expect(s.timeEnabled)
        #expect(s.dateEnabled)
        #expect(s.timePosition == .center)
        #expect(s.datePosition == .bottomCenter)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:SettingsFeatureTests/LabelPositionTests`
Expected: 컴파일 실패("cannot find 'LabelPosition' in scope").

- [ ] **Step 3: 모델 구현 (`Modules/Models/Sources/LabelSettings.swift`)**

```swift
import CoreGraphics

/// 라벨 9구역 위치. CoreAnimation 좌표계(좌하단 원점) origin 계산을 포함한 순수 모델.
public enum LabelPosition: Int, CaseIterable, Sendable, Codable {
    case topLeft, topCenter, topRight
    case centerLeft, center, centerRight
    case bottomLeft, bottomCenter, bottomRight

    /// 사용자 표기. 예: .center → "정중앙"
    public var koreanName: String {
        switch self {
        case .topLeft:      return "좌측 상단"
        case .topCenter:    return "중앙 상단"
        case .topRight:     return "우측 상단"
        case .centerLeft:   return "좌측 중앙"
        case .center:       return "정중앙"
        case .centerRight:  return "우측 중앙"
        case .bottomLeft:   return "좌측 하단"
        case .bottomCenter: return "중앙 하단"
        case .bottomRight:  return "우측 하단"
        }
    }

    /// 가로 정렬: 0 = left, 0.5 = center, 1 = right
    public var horizontalAnchor: CGFloat {
        switch self {
        case .topLeft, .centerLeft, .bottomLeft:    return 0
        case .topCenter, .center, .bottomCenter:    return 0.5
        case .topRight, .centerRight, .bottomRight: return 1
        }
    }

    /// 세로 정렬(CoreAnimation, 좌하단 원점): 1 = top, 0.5 = middle, 0 = bottom
    public var verticalAnchor: CGFloat {
        switch self {
        case .topLeft, .topCenter, .topRight:          return 1
        case .centerLeft, .center, .centerRight:       return 0.5
        case .bottomLeft, .bottomCenter, .bottomRight: return 0
        }
    }

    /// 텍스트의 좌하단 origin (CoreAnimation). padding 안쪽으로 클램프해 코너에서도 캔버스 밖으로 안 나간다.
    public func origin(renderSize: CGSize, textSize: CGSize, padding: CGSize) -> CGPoint {
        let minX = padding.width
        let maxX = max(minX, renderSize.width - padding.width - textSize.width)
        let minY = padding.height
        let maxY = max(minY, renderSize.height - padding.height - textSize.height)
        let x = minX + (maxX - minX) * horizontalAnchor
        let y = minY + (maxY - minY) * verticalAnchor
        return CGPoint(x: x, y: y)
    }
}

/// 라벨 표시/위치 설정 묶음. 렌더러로 전달되는 값 타입.
public struct LabelSettings: Equatable, Sendable {
    public var timeEnabled: Bool
    public var timePosition: LabelPosition
    public var dateEnabled: Bool
    public var datePosition: LabelPosition

    public init(
        timeEnabled: Bool = true,
        timePosition: LabelPosition = .center,
        dateEnabled: Bool = true,
        datePosition: LabelPosition = .bottomCenter
    ) {
        self.timeEnabled = timeEnabled
        self.timePosition = timePosition
        self.dateEnabled = dateEnabled
        self.datePosition = datePosition
    }

    public static let `default` = LabelSettings()
}

/// 설정 UI/네비게이션에서 어떤 라벨을 다루는지 식별.
public enum LabelKind: String, CaseIterable, Sendable, Hashable {
    case time, date

    public var title: String {
        switch self {
        case .time: return "시각 라벨"
        case .date: return "날짜 라벨"
        }
    }

    public var subtitle: String {
        switch self {
        case .time: return "HH:mm"
        case .date: return "yyyy/MM/dd"
        }
    }

    public var sampleText: String {
        switch self {
        case .time: return "12:30"
        case .date: return "2026/04/05"
        }
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:SettingsFeatureTests/LabelPositionTests`
Expected: 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Modules/Models/Sources/LabelSettings.swift Modules/SettingsFeature/Tests/LabelPositionTests.swift
git commit -m "✨ feat: 라벨 9구역 위치 모델(LabelPosition/LabelSettings/LabelKind) 추가"
```

---

## Task 3: AnalyticsEvent 이벤트 3종 추가

**Files:**
- Modify: `Modules/AnalyticsService/Sources/AnalyticsEvent.swift`

> AnalyticsService 는 Models 에 의존하지 않는 설계(예: `MediaPickerSourceTag`)이므로, 이벤트는 primitive(String/Int)로 받는다. 호출부에서 `LabelKind.rawValue`, `LabelPosition.rawValue` 로 변환.

- [ ] **Step 1: case 추가 (`AnalyticsEvent` enum 본문, `case filmDeleted(filmID: UUID)` 다음)**

```swift
    // 설정 / 라벨
    case settingsOpened
    case labelToggled(kind: String, on: Bool)
    case labelPositionChanged(kind: String, position: Int)
```

- [ ] **Step 2: `name` switch 에 추가 (`case .filmDeleted: ...` 다음)**

```swift
        case .settingsOpened:        return "settings_opened"
        case .labelToggled:          return "label_toggled"
        case .labelPositionChanged:  return "label_position_changed"
```

- [ ] **Step 3: `parameters` switch 에 추가**

`case .homeViewed, ...: return [:]` 줄의 `.vlogSavedToLibrary` 뒤에 `, .settingsOpened` 를 더하고, switch 안에 아래 두 case 추가:

```swift
        case let .labelToggled(kind, on):
            return ["kind": .string(kind), "on": .bool(on)]
        case let .labelPositionChanged(kind, position):
            return ["kind": .string(kind), "position": .int(position)]
```

(즉 빈 파라미터 줄은: `case .homeViewed, .newVlogTapped, .timelineOpened, .exportScreenOpened, .vlogSavedToLibrary, .settingsOpened:`)

- [ ] **Step 4: 빌드 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Modules/AnalyticsService/Sources/AnalyticsEvent.swift
git commit -m "✨ feat: 설정/라벨 Analytics 이벤트 3종 추가"
```

---

## Task 4: SettingsFeature Reducer (TDD)

**Files:**
- Modify: `Modules/SettingsFeature/Sources/SettingsFeature.swift` (Task 1 플레이스홀더 교체)
- Test: `Modules/SettingsFeature/Tests/SettingsFeatureTests.swift`

- [ ] **Step 1: 실패하는 테스트 작성 (`Modules/SettingsFeature/Tests/SettingsFeatureTests.swift`)**

```swift
import Testing
import ComposableArchitecture
import Models
@testable import SettingsFeature

@MainActor
struct SettingsFeatureTests {
    @Test func togglingTimeUpdatesShared() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        store.exhaustivity = .off   // @Shared·appStorage 변경만 결과로 확인
        await store.send(.timeToggled(false))
        #expect(store.state.timeEnabled == false)
    }

    @Test func togglingDateUpdatesShared() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        store.exhaustivity = .off
        await store.send(.dateToggled(false))
        #expect(store.state.dateEnabled == false)
    }

    @Test func positionRowTapsAreNoOpInReducer() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        store.exhaustivity = .off
        await store.send(.timePositionRowTapped)   // 네비게이션은 View가 처리 → 상태 불변
        await store.send(.datePositionRowTapped)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:SettingsFeatureTests/SettingsFeatureTests`
Expected: 컴파일 실패("value of type 'State' has no member 'timeEnabled'").

- [ ] **Step 3: Reducer 구현 (`Modules/SettingsFeature/Sources/SettingsFeature.swift` 전체 교체)**

```swift
import ComposableArchitecture
import Models
import AnalyticsService

@Reducer
public struct SettingsFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        @Shared(.appStorage("labelTimeEnabled")) public var timeEnabled = true
        @Shared(.appStorage("labelTimePosition")) public var timePosition = LabelPosition.center
        @Shared(.appStorage("labelDateEnabled")) public var dateEnabled = true
        @Shared(.appStorage("labelDatePosition")) public var datePosition = LabelPosition.bottomCenter

        public init() {}
    }

    public enum Action {
        case onAppear
        case timeToggled(Bool)
        case dateToggled(Bool)
        // 네비게이션 intent — View 가 router.push(.labelPosition(kind)) 처리
        case timePositionRowTapped
        case datePositionRowTapped
    }

    @Dependency(\.analyticsTracker) var analyticsTracker

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                analyticsTracker.log(.settingsOpened)
                return .none

            case let .timeToggled(on):
                state.$timeEnabled.withLock { $0 = on }
                analyticsTracker.log(.labelToggled(kind: LabelKind.time.rawValue, on: on))
                return .none

            case let .dateToggled(on):
                state.$dateEnabled.withLock { $0 = on }
                analyticsTracker.log(.labelToggled(kind: LabelKind.date.rawValue, on: on))
                return .none

            case .timePositionRowTapped, .datePositionRowTapped:
                return .none
            }
        }
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:SettingsFeatureTests/SettingsFeatureTests`
Expected: 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Modules/SettingsFeature/Sources/SettingsFeature.swift Modules/SettingsFeature/Tests/SettingsFeatureTests.swift
git commit -m "✨ feat: SettingsFeature 리듀서(라벨 토글 + @Shared 영속)"
```

---

## Task 5: LabelPositionFeature Reducer (TDD)

**Files:**
- Create: `Modules/SettingsFeature/Sources/LabelPositionFeature.swift`
- Test: `Modules/SettingsFeature/Tests/LabelPositionFeatureTests.swift`

- [ ] **Step 1: 실패하는 테스트 작성 (`Modules/SettingsFeature/Tests/LabelPositionFeatureTests.swift`)**

```swift
import Testing
import ComposableArchitecture
import Models
@testable import SettingsFeature

@MainActor
struct LabelPositionFeatureTests {
    @Test func selectingPositionUpdatesTimeShared() async {
        let store = TestStore(initialState: LabelPositionFeature.State(kind: .time)) {
            LabelPositionFeature()
        }
        store.exhaustivity = .off
        await store.send(.positionSelected(.topRight))
        #expect(store.state.timePosition == .topRight)
        #expect(store.state.selected == .topRight)
    }

    @Test func selectingPositionUpdatesDateShared() async {
        let store = TestStore(initialState: LabelPositionFeature.State(kind: .date)) {
            LabelPositionFeature()
        }
        store.exhaustivity = .off
        await store.send(.positionSelected(.topLeft))
        #expect(store.state.datePosition == .topLeft)
        #expect(store.state.selected == .topLeft)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:SettingsFeatureTests/LabelPositionFeatureTests`
Expected: 컴파일 실패("cannot find 'LabelPositionFeature' in scope").

- [ ] **Step 3: Reducer 구현 (`Modules/SettingsFeature/Sources/LabelPositionFeature.swift`)**

```swift
import ComposableArchitecture
import Models
import AnalyticsService

@Reducer
public struct LabelPositionFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public let kind: LabelKind
        @Shared(.appStorage("labelTimePosition")) public var timePosition = LabelPosition.center
        @Shared(.appStorage("labelDatePosition")) public var datePosition = LabelPosition.bottomCenter

        public init(kind: LabelKind) { self.kind = kind }

        /// 현재 kind 에 해당하는 선택값.
        public var selected: LabelPosition {
            kind == .time ? timePosition : datePosition
        }
    }

    public enum Action {
        case onAppear
        case positionSelected(LabelPosition)
    }

    @Dependency(\.analyticsTracker) var analyticsTracker

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none

            case let .positionSelected(position):
                switch state.kind {
                case .time: state.$timePosition.withLock { $0 = position }
                case .date: state.$datePosition.withLock { $0 = position }
                }
                analyticsTracker.log(.labelPositionChanged(kind: state.kind.rawValue, position: position.rawValue))
                return .none
            }
        }
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:SettingsFeatureTests/LabelPositionFeatureTests`
Expected: 2 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Modules/SettingsFeature/Sources/LabelPositionFeature.swift Modules/SettingsFeature/Tests/LabelPositionFeatureTests.swift
git commit -m "✨ feat: LabelPositionFeature 리듀서(9구역 선택 + @Shared 영속)"
```

---

## Task 6: SettingsView (UI)

**Files:**
- Create: `Modules/SettingsFeature/Sources/SettingsView.swift`

> SwiftUI View 는 단위 테스트 대신 `#Preview` + 빌드로 검증(프로젝트 컨벤션).

- [ ] **Step 1: View 구현 (`Modules/SettingsFeature/Sources/SettingsView.swift`)**

```swift
import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem

public struct SettingsView: View {
    @Environment(AppRouter.self) private var router
    let store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
                .chalNaHeaderBar(scrollProgress: 1)
                .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("라벨")
                        .tagLabel()
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    VStack(spacing: 0) {
                        labelRows(
                            kind: .time,
                            isOn: store.timeEnabled,
                            position: store.timePosition,
                            onToggle: { store.send(.timeToggled($0)) },
                            onPositionTap: {
                                store.send(.timePositionRowTapped)
                                router.push(.labelPosition(.time))
                            }
                        )
                        Divider().overlay(ChalNaColor.Gray.g100)
                        labelRows(
                            kind: .date,
                            isOn: store.dateEnabled,
                            position: store.datePosition,
                            onToggle: { store.send(.dateToggled($0)) },
                            onPositionTap: {
                                store.send(.datePositionRowTapped)
                                router.push(.labelPosition(.date))
                            }
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                            .strokeBorder(ChalNaColor.Gray.g100, lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 64)
            }
        }
        .chalNaScreen()
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("설정")
                .font(ChalNaTypography.title(ChalNaTypography.Size.h2, weight: .semibold))
                .foregroundColor(ChalNaColor.ink)
            HStack {
                Button { router.pop() } label: {
                    ChalNaIcon(.chevronLeft, size: 22)
                        .foregroundColor(ChalNaColor.ink)
                }
                .buttonStyle(.chalNaHeaderAction)
                .accessibilityLabel("뒤로")
                Spacer()
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func labelRows(
        kind: LabelKind,
        isOn: Bool,
        position: LabelPosition,
        onToggle: @escaping (Bool) -> Void,
        onPositionTap: @escaping () -> Void
    ) -> some View {
        // 토글 행
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body, weight: .semibold))
                    .foregroundColor(ChalNaColor.ink)
                Text(kind.subtitle)
                    .font(ChalNaTypography.monoFallback(ChalNaTypography.Size.caption))
                    .foregroundColor(ChalNaColor.taupe)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { isOn }, set: onToggle))
                .labelsHidden()
                .tint(ChalNaColor.coral)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)

        // 위치 행 (OFF 면 비활성)
        Button(action: onPositionTap) {
            HStack(spacing: 12) {
                Text("위치")
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body))
                    .foregroundColor(isOn ? ChalNaColor.ink : ChalNaColor.Gray.g300)
                Spacer()
                Text(position.koreanName)
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.small))
                    .foregroundColor(isOn ? ChalNaColor.taupe : ChalNaColor.Gray.g300)
                ChalNaIcon(.chevronRight, size: 16)
                    .foregroundColor(isOn ? ChalNaColor.Gray.g400 : ChalNaColor.Gray.g300)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isOn)
    }
}

#Preview {
    SettingsView(store: Store(initialState: SettingsFeature.State()) { SettingsFeature() })
        .environment(AppRouter())
}
```

- [ ] **Step 2: 빌드 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED. (Xcode에서 `SettingsView` Preview가 토글 2개 + 위치 행 2개로 렌더되는지 시각 확인)

- [ ] **Step 3: Commit**

```bash
git add Modules/SettingsFeature/Sources/SettingsView.swift
git commit -m "💄 feat: 설정 리스트 화면(SettingsView) DDS 구현"
```

---

## Task 7: LabelPositionPickerView (UI · 미니 미리보기 + 3×3)

**Files:**
- Create: `Modules/SettingsFeature/Sources/LabelPositionPickerView.swift`

- [ ] **Step 1: View 구현 (`Modules/SettingsFeature/Sources/LabelPositionPickerView.swift`)**

```swift
import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem

public struct LabelPositionPickerView: View {
    @Environment(AppRouter.self) private var router
    let store: StoreOf<LabelPositionFeature>

    public init(store: StoreOf<LabelPositionFeature>) {
        self.store = store
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    public var body: some View {
        VStack(spacing: 0) {
            header
                .chalNaHeaderBar(scrollProgress: 1)
                .zIndex(1)

            ScrollView {
                VStack(spacing: 24) {
                    preview
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    grid
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 64)
            }
        }
        .chalNaScreen()
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("\(store.kind.title) 위치")
                .font(ChalNaTypography.title(ChalNaTypography.Size.h2, weight: .semibold))
                .foregroundColor(ChalNaColor.ink)
            HStack {
                Button { router.pop() } label: {
                    ChalNaIcon(.chevronLeft, size: 22)
                        .foregroundColor(ChalNaColor.ink)
                }
                .buttonStyle(.chalNaHeaderAction)
                .accessibilityLabel("뒤로")
                Spacer()
            }
        }
    }

    // MARK: - Mini preview (9:16 중립 회색 캔버스)

    private var preview: some View {
        ZStack(alignment: alignment(for: store.selected)) {
            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                .fill(ChalNaColor.Gray.g200)

            sampleLabel
                .padding(12)
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .frame(maxWidth: 220)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var sampleLabel: some View {
        if store.kind == .time {
            Text(store.kind.sampleText)
                .font(ChalNaTypography.displayKR(40, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
        } else {
            Text(store.kind.sampleText)
                .font(ChalNaTypography.monoFallback(13, weight: .medium))
                .foregroundColor(.white)
        }
    }

    /// LabelPosition → SwiftUI(상단 원점) Alignment.
    private func alignment(for p: LabelPosition) -> Alignment {
        let h: HorizontalAlignment = p.horizontalAnchor == 0 ? .leading
            : (p.horizontalAnchor == 1 ? .trailing : .center)
        let v: VerticalAlignment
        switch p {
        case .topLeft, .topCenter, .topRight:          v = .top
        case .centerLeft, .center, .centerRight:       v = .center
        case .bottomLeft, .bottomCenter, .bottomRight: v = .bottom
        }
        return Alignment(horizontal: h, vertical: v)
    }

    // MARK: - 3×3 grid

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(LabelPosition.allCases, id: \.self) { pos in
                let isSelected = store.selected == pos
                Button { store.send(.positionSelected(pos)) } label: {
                    Text(pos.koreanName)
                        .font(ChalNaTypography.krBody(ChalNaTypography.Size.small, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? ChalNaColor.coral : ChalNaColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                                .fill(isSelected ? ChalNaColor.Purple.p100.opacity(0.5) : Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                                .strokeBorder(isSelected ? ChalNaColor.coral : ChalNaColor.Gray.g200,
                                              lineWidth: isSelected ? 1.5 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    LabelPositionPickerView(
        store: Store(initialState: LabelPositionFeature.State(kind: .time)) { LabelPositionFeature() }
    )
    .environment(AppRouter())
}
```

- [ ] **Step 2: 빌드 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED. (Preview에서 3×3 그리드 + 정중앙에 "12:30" 미리보기, 셀 탭 시 강조·미리보기 이동 시각 확인)

- [ ] **Step 3: Commit**

```bash
git add Modules/SettingsFeature/Sources/LabelPositionPickerView.swift
git commit -m "💄 feat: 9구역 위치 피커(미니 미리보기 + 3×3) 구현"
```

---

## Task 8: 네비게이션 배선 (AppRouter / AppFeature / RootView)

**Files:**
- Modify: `Modules/AppCore/Sources/AppRouter.swift`
- Modify: `ChalNa/Sources/App/AppFeature.swift`
- Modify: `ChalNa/Sources/App/RootView.swift`

- [ ] **Step 1: Route 확장 (`Modules/AppCore/Sources/AppRouter.swift`)**

상단 `import Observation` 아래에 `import Models` 추가. `Route` enum에 두 case 추가:

```swift
public enum Route: Hashable, Sendable {
    case mediaPicker
    case timeline
    case export
    case filmDetail(filmID: UUID)
    case settings
    case labelPosition(LabelKind)
}
```

- [ ] **Step 2: AppFeature 확장 (`ChalNa/Sources/App/AppFeature.swift`)**

import 목록에 추가:

```swift
import Models
import SettingsFeature
```

`Path` enum에 두 case 추가:

```swift
    @Reducer
    public enum Path {
        case mediaPicker(MediaPickerFeature)
        case timeline(TimelineFeature)
        case export(ExportFeature)
        case filmDetail(FilmDetailFeature)
        case settings(SettingsFeature)
        case labelPosition(LabelPositionFeature)
    }
```

`Action` enum의 `case routerPoppedToRoot` 다음에 추가:

```swift
        case routerPushedSettings
        case routerPushedLabelPosition(kind: LabelKind)
```

Reduce switch에서 `case .routerPoppedToRoot:` 블록 다음, `case .home, .path:` 앞에 추가:

```swift
            case .routerPushedSettings:
                state.path.append(.settings(SettingsFeature.State()))
                return .none

            case let .routerPushedLabelPosition(kind):
                state.path.append(.labelPosition(LabelPositionFeature.State(kind: kind)))
                return .none
```

- [ ] **Step 3: RootView 확장 (`ChalNa/Sources/App/RootView.swift`)**

import 목록에 추가:

```swift
import Models
import SettingsFeature
```

`destinationView(for:)` switch에 두 case 추가:

```swift
        case let .settings(s):      SettingsView(store: s)
        case let .labelPosition(s): LabelPositionPickerView(store: s)
```

`wireRouterHandlers()`의 `pushHandler` switch에서 `case let .filmDetail(filmID):` 블록 다음에 추가:

```swift
            case .settings:
                store.send(.routerPushedSettings)
            case let .labelPosition(kind):
                store.send(.routerPushedLabelPosition(kind: kind))
```

- [ ] **Step 4: 빌드 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED. (Path enum 의 모든 case가 destinationView/Path 양쪽에서 망라되는지 컴파일러가 보장)

- [ ] **Step 5: Commit**

```bash
git add Modules/AppCore/Sources/AppRouter.swift ChalNa/Sources/App/AppFeature.swift ChalNa/Sources/App/RootView.swift
git commit -m "✨ feat: 설정/위치피커 네비게이션 배선(Route·Path·RootView)"
```

---

## Task 9: Home 설정 버튼 복원

**Files:**
- Modify: `Modules/HomeFeature/Sources/HomeView.swift:60-69`

- [ ] **Step 1: 주석 처리된 gear 버튼을 실제 버튼으로 교체**

`header`의 `Spacer()` 다음 주석 블록(라인 60-69)을 아래로 교체:

```swift
            Button {
                store.send(.settingsButtonTapped)
                router.push(.settings)
            } label: {
                Image(systemName: "gearshape")
                    .font(ChalNaTypography.krBody(20))
                    .foregroundColor(ChalNaColor.ink)
            }
            .buttonStyle(.chalNaHeaderAction)
            .accessibilityLabel("설정")
```

> `.font(ChalNaTypography.krBody(20))` 로 SF Symbol 크기를 토큰 경유로 지정(DDS의 `.font(.system)` 직접호출 금지 준수).

- [ ] **Step 2: 빌드 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Modules/HomeFeature/Sources/HomeView.swift
git commit -m "✨ feat: Home 헤더 설정 버튼 노출 + 설정 화면 연결"
```

---

## Task 10: CompositionService 라벨 설정 반영

**Files:**
- Modify: `Modules/CompositionService/Sources/CompositionService.swift`
- Modify: `Modules/CompositionService/Sources/CompositionClient.swift`

> 기존 `export(clips:)`/`export(clips:rotations:)` 편의 오버로드는 `.default` 위임으로 보존 → `TimelineFeatureTests`·`CompositionServiceTests` 무수정 통과.

- [ ] **Step 1: 프로토콜·편의 오버로드 갱신 (`CompositionService.swift:37-48`)**

```swift
public protocol CompositionServicing: Sendable {
    /// 클립 배열·회전·라벨 설정을 받아 mp4를 만들고 진행률/완료/실패를 스트림으로 흘려보낸다.
    func export(clips: [Clip], rotations: [Clip.ID: ClipRotation], labelSettings: LabelSettings) -> AsyncStream<ExportEvent>
}

public extension CompositionServicing {
    /// 라벨 설정 없는 호출 → 기본값(현행 동작). 테스트/구버전 호환용.
    func export(clips: [Clip], rotations: [Clip.ID: ClipRotation]) -> AsyncStream<ExportEvent> {
        export(clips: clips, rotations: rotations, labelSettings: .default)
    }
    /// 회전·라벨 설정 없는 호출.
    func export(clips: [Clip]) -> AsyncStream<ExportEvent> {
        export(clips: clips, rotations: [:], labelSettings: .default)
    }
}
```

- [ ] **Step 2: actor export(nonisolated) 시그니처 갱신 (`CompositionService.swift:54-68`)**

```swift
    public nonisolated func export(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        labelSettings: LabelSettings
    ) -> AsyncStream<ExportEvent> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                await self.run(clips: clips, rotations: rotations, labelSettings: labelSettings, continuation: continuation)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
```

- [ ] **Step 3: run() 시그니처 + buildComposition 호출 갱신 (`CompositionService.swift:72-78`)**

```swift
    private func run(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        labelSettings: LabelSettings,
        continuation: AsyncStream<ExportEvent>.Continuation
    ) async {
        do {
            let built = try await buildComposition(clips: clips, rotations: rotations, labelSettings: labelSettings)
```

(이하 `run` 본문은 그대로)

- [ ] **Step 4: buildComposition 시그니처 + animationTool 분기 갱신**

`buildComposition` 시그니처(`CompositionService.swift:132-135`)를 교체:

```swift
    private func buildComposition(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        labelSettings: LabelSettings
    ) async throws -> BuiltComposition {
```

animationTool 분기(`CompositionService.swift:217-223`)를 교체:

```swift
        // 4) 각 클립 placedRange 동안 라벨 오버레이 (설정에 따라 표시/위치 결정).
        if hasContent && (labelSettings.timeEnabled || labelSettings.dateEnabled) {
            videoComposition.animationTool = Self.makeDateLabelAnimationTool(
                renderSize: renderSize,
                entries: layerInstructions.map { ($0.timeRange, $0.capturedAt) },
                labelSettings: labelSettings
            )
        }
```

- [ ] **Step 5: makeDateLabelAnimationTool 일반화 (`CompositionService.swift:282-331` 교체)**

```swift
    /// 클립별 촬영일시를 설정에 따라 오버레이로 합성하는 `AVVideoCompositionCoreAnimationTool`.
    /// - 시각 `HH:mm`: 큰 글씨(minDim×0.18), opacity 0.5
    /// - 날짜 `yyyy/MM/dd`: 작은 글씨(minDim×0.035), opacity 1.0
    /// 표시 여부·위치는 `labelSettings`를 따른다. 각 라벨은 자신의 timeRange 동안만 보인다.
    private static func makeDateLabelAnimationTool(
        renderSize: CGSize,
        entries: [(timeRange: CMTimeRange, capturedAt: Date)],
        labelSettings: LabelSettings
    ) -> AVVideoCompositionCoreAnimationTool {
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = parentLayer.frame
        parentLayer.addSublayer(videoLayer)

        let minDim = min(renderSize.width, renderSize.height)
        let dateFontSize = minDim * 0.035
        let timeFontSize = minDim * 0.18
        let padding = CGSize(width: renderSize.width * 0.04, height: renderSize.height * 0.04)

        for entry in entries {
            if labelSettings.dateEnabled {
                let dateLayer = makeOverlayTextLayer(
                    text: dateOnlyFormatter.string(from: entry.capturedAt),
                    fontSize: dateFontSize,
                    timeRange: entry.timeRange
                ) { size in
                    labelSettings.datePosition.origin(renderSize: renderSize, textSize: size, padding: padding)
                }
                parentLayer.addSublayer(dateLayer)
            }

            if labelSettings.timeEnabled {
                let timeLayer = makeOverlayTextLayer(
                    text: timeOnlyFormatter.string(from: entry.capturedAt),
                    fontSize: timeFontSize,
                    timeRange: entry.timeRange,
                    opacity: 0.5
                ) { size in
                    labelSettings.timePosition.origin(renderSize: renderSize, textSize: size, padding: padding)
                }
                parentLayer.addSublayer(timeLayer)
            }
        }

        return AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
    }
```

- [ ] **Step 6: CompositionClient 갱신 (`CompositionClient.swift` 전체)**

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
        _ labelSettings: LabelSettings
    ) -> AsyncStream<ExportEvent> = { _, _, _ in
        AsyncStream { $0.finish() }
    }
}

extension CompositionClient: DependencyKey {
    public static let liveValue: CompositionClient = {
        let service = AVFoundationCompositionService()
        return CompositionClient(
            export: { clips, rotations, labelSettings in
                service.export(clips: clips, rotations: rotations, labelSettings: labelSettings)
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

- [ ] **Step 7: 빌드 + 기존 테스트 회귀 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:CompositionServiceTests -only-testing:TimelineFeatureTests`
Expected: BUILD SUCCEEDED, 기존 테스트 전부 PASS(편의 오버로드 보존 확인).

- [ ] **Step 8: Commit**

```bash
git add Modules/CompositionService/Sources/CompositionService.swift Modules/CompositionService/Sources/CompositionClient.swift
git commit -m "✨ feat: 익스포트 라벨 표시/위치를 LabelSettings로 제어"
```

---

## Task 11: ExportFeature에서 설정 읽어 전달

**Files:**
- Modify: `Modules/ExportFeature/Sources/ExportFeature.swift`

- [ ] **Step 1: State에 @Shared 4개 추가 (`ExportFeature.swift` State 본문, `isPlayerPresented` 저장 프로퍼티 선언 다음 줄)**

```swift
        // 라벨 설정(설정 화면과 동일 키 공유). 익스포트 시 LabelSettings로 조립.
        @Shared(.appStorage("labelTimeEnabled")) public var timeEnabled = true
        @Shared(.appStorage("labelTimePosition")) public var timePosition = LabelPosition.center
        @Shared(.appStorage("labelDateEnabled")) public var dateEnabled = true
        @Shared(.appStorage("labelDatePosition")) public var datePosition = LabelPosition.bottomCenter
```

> 이 프로퍼티들은 property-wrapper 기본값이 있어 기존 `init(...)` 시그니처(파라미터 목록)는 그대로 두면 된다.

- [ ] **Step 2: startExport에서 LabelSettings 조립·전달 (`ExportFeature.swift:92-112`)**

`case let .startExport(clips, rotations):` 블록을 교체:

```swift
            case let .startExport(clips, rotations):
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
                    dateEnabled: state.dateEnabled,
                    datePosition: state.datePosition
                )
                return .run { send in
                    for await event in compositionClient.export(clips, rotations, labelSettings) {
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

- [ ] **Step 3: 빌드 확인**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add Modules/ExportFeature/Sources/ExportFeature.swift
git commit -m "✨ feat: ExportFeature가 라벨 설정을 읽어 합성에 전달"
```

---

## Task 12: 통합 빌드 + 시뮬레이터 검증

**Files:** (변경 없음 — 검증 전용)

- [ ] **Step 1: 전체 테스트**

Run: `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
Expected: 전 타겟 BUILD SUCCEEDED, 모든 테스트 PASS(특히 SettingsFeatureTests 11+ 케이스, CompositionServiceTests, TimelineFeatureTests).

- [ ] **Step 2: 시뮬레이터 수동 검증 (`ios-build-run` 서브에이전트 권장)**

확인 체크리스트:
1. Home 우측 상단 gear 버튼 노출 → 탭하면 "설정" 화면 push, 좌측 스와이프/뒤로 동작.
2. 설정: 시각/날짜 토글 동작. OFF 시 해당 "위치" 행 회색·비활성.
3. "위치" 탭 → 피커 push. 9칸 중 현재 선택 강조, 미니 미리보기에 샘플 라벨이 해당 구역에 표시.
4. 다른 구역 탭 → 미리보기 즉시 이동, 강조 이동.
5. 뒤로 → 설정 리스트의 "위치" 값이 새 구역명으로 갱신.
6. 앱 재실행 후 설정 유지(@Shared appStorage 영속).
7. 실제 Vlog 익스포트(영상 클립 포함) → 결과 mp4에서 라벨이 설정한 표시여부·구역대로 burn-in. 모두 OFF면 라벨 없이 정상 출력.

- [ ] **Step 3: (해당 시) 최종 정리 커밋**

검증 중 사소한 수정이 있었다면 커밋. 없으면 생략.

---

## Self-Review (작성자 점검 결과)

- **Spec coverage:** Home 버튼(Task 9), 설정 리스트(Task 4/6), 토글(Task 4/6), 9구역 세부(Task 5/7), 모델·기본값=현행(Task 2), `@Shared` 저장(Task 4/5/11), 네비게이션(Task 8), 익스포트 반영(Task 10/11), Analytics(Task 3), 미니 미리보기(Task 7), 테스트(Task 2/4/5), 엣지케이스 클램프(Task 2 origin) — 스펙 14개 섹션 모두 태스크 대응 확인.
- **Placeholder scan:** TBD/TODO/"적절히" 없음. 모든 코드 단계에 실제 코드 포함.
- **Type consistency:** `LabelPosition`/`LabelSettings`/`LabelKind`(Task 2) ↔ Reducer(Task 4/5) ↔ View(Task 6/7) ↔ CompositionService(Task 10) ↔ ExportFeature(Task 11) 시그니처 일치. `export(clips:rotations:labelSettings:)`·`origin(renderSize:textSize:padding:)`·`@Shared` 키 4개("labelTimeEnabled" 등)가 모든 태스크에서 동일. AnalyticsEvent는 primitive(String/Int)로 받고 호출부에서 `.rawValue` 변환(Task 3↔4↔5) 일치.
