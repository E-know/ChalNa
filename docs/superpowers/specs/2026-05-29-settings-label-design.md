# 설계: 설정(Settings) 화면 + 라벨 ON/OFF·9구역 위치

- 날짜: 2026-05-29
- 대상 앱: ChalNa (iOS, Tuist + SwiftUI + TCA)
- 작성 근거: 사용자 요청(브레인스토밍 합의) + 코드베이스 현황 + Figma 디자인 가이드(`7WAZO6KqGTt06KMudy6NS1`)

## 1. 목표

1. Home 상단 헤더에 숨겨진 **설정(gear) 버튼을 다시 노출**한다.
2. **설정 화면**(목록)을 새로 만든다.
3. 설정에서 **시각 라벨(HH:mm)** 과 **날짜 라벨(yyyy/MM/dd)** 의 **ON/OFF** 를 토글한다.
4. 각 라벨의 **세부 설정**으로 들어가면 **9구역 위치**를 고를 수 있다.
   - 좌측 상단 / 좌측 중앙 / 좌측 하단
   - 중앙 상단 / 정중앙 / 중앙 하단
   - 우측 상단 / 우측 중앙 / 우측 하단

## 2. 비목표 (YAGNI)

- 자유 드래그/픽셀 단위 위치 지정 (9구역 고정).
- 라벨 폰트/색/크기/포맷 커스터마이즈 (표시 여부·위치만).
- 편집 중 Timeline 미리보기에 라벨 실시간 오버레이 (범위 제외 — 아래 결정 D2).
- 두 라벨이 같은 구역일 때 자동 겹침 회피.

## 3. 합의된 결정

- **D1 — 디자인 언어**: 새 화면은 **현재 코드의 Danawa DDS**(흰 배경/보라 Primary/시스템 폰트)를 따른다. Figma의 "Moments" 페이퍼 무드는 채택하지 않는다(Figma는 리네임·DDS 마이그레이션 이전 버전이라 색/폰트가 코드와 불일치). Figma는 **레이아웃·UX 패턴 참고용**으로만 사용.
- **D2 — 적용 범위**: 라벨은 **익스포트 영상에만 burn-in**(현행 유지)되고, 설정 세부 화면의 **미니 미리보기**로 위치를 확인한다. Timeline 실시간 오버레이는 하지 않는다.
- **D3 — 저장/전달**: TCA **`@Shared(.appStorage)`** 로 영속(접근법 A). CompositionService는 설정을 **인자로 받는 순수 함수**로 유지한다.
- **D4 — 미리보기 배경**: 중립 회색 9:16 캔버스.
- **D5 — Analytics**: 최소 이벤트 포함(`settingsOpened` / `labelToggled` / `labelPositionChanged`).
- **D6 — 기본값**: 두 라벨 모두 ON, 시각=정중앙, 날짜=중앙 하단 → **현재 익스포트 출력과 동일**(설정 미변경 시 기존 결과 보존).

## 4. 현황 (앵커가 되는 기존 코드)

- `Modules/HomeFeature/Sources/HomeView.swift:60-69` — gear 버튼이 주석 처리됨. `HomeFeature.Action.settingsButtonTapped`(`HomeFeature.swift:23,41`)와 `.chalNaHeaderAction` 버튼 스타일은 이미 존재.
- `Modules/CompositionService/Sources/CompositionService.swift:218-331` — 익스포트 시 클립 `capturedAt`으로 두 라벨을 burn-in. 현재 **하드코딩**:
  - 시각 `HH:mm`: 큰 글씨(minDim×0.18), opacity 0.5, **정중앙**.
  - 날짜 `yyyy/MM/dd`: 작은 글씨(minDim×0.035), opacity 1.0, **하단 중앙**(padY).
  - KERISKEDU 폰트(없으면 시스템 bold) + 검은 그림자. CoreAnimation 좌표(좌하단 원점).
- `Modules/CompositionService/Sources/CompositionClient.swift:9-14` — `export: @Sendable ([Clip], [Clip.ID: ClipRotation]) -> AsyncStream<ExportEvent>`.
- `Modules/ExportFeature/Sources/ExportFeature.swift:92,100-101` — `startExport`가 `compositionClient.export(clips, rotations)` 호출.
- `Modules/AppCore/Sources/AppRouter.swift` — `Route` enum + thin wrapper.
- `ChalNa/Sources/App/AppFeature.swift` — `Path` enum(`@Reducer`) + `routerPushed*` 액션 + `RootView.destinationView`/`wireRouterHandlers` 연결.
- 설정 저장소: **없음**(신규 도입).

## 5. 데이터 모델 (`Models` 모듈)

신규 파일 `Modules/Models/Sources/LabelSettings.swift`:

```swift
import CoreGraphics

/// 라벨 9구역 위치. CoreAnimation 좌표계(좌하단 원점) origin 계산을 포함한 순수 모델.
public enum LabelPosition: Int, CaseIterable, Sendable, Codable {
    case topLeft, topCenter, topRight
    case centerLeft, center, centerRight
    case bottomLeft, bottomCenter, bottomRight

    /// 사용자 표기. 예: .center → "정중앙"
    public var koreanName: String { ... }

    /// 가로 정렬: 0=left, 0.5=center, 1=right
    var horizontalAnchor: CGFloat { ... }
    /// 세로 정렬(CoreAnimation, 0=bottom … 1=top)
    var verticalAnchor: CGFloat { ... }

    /// 텍스트의 좌하단 origin 계산.
    /// padding 안쪽으로 클램프되어 corner 구역에서도 캔버스 밖으로 나가지 않는다.
    public func origin(renderSize: CGSize, textSize: CGSize, padding: CGSize) -> CGPoint {
        let minX = padding.width
        let maxX = renderSize.width  - padding.width  - textSize.width
        let minY = padding.height
        let maxY = renderSize.height - padding.height - textSize.height
        let x = minX + (maxX - minX) * horizontalAnchor
        let y = minY + (maxY - minY) * verticalAnchor   // bottom=원점
        return CGPoint(x: x, y: y)
    }
}

/// 라벨 표시/위치 설정 묶음. 렌더러로 전달되는 값 타입.
public struct LabelSettings: Equatable, Sendable {
    public var timeEnabled: Bool
    public var timePosition: LabelPosition
    public var dateEnabled: Bool
    public var datePosition: LabelPosition

    public init(timeEnabled: Bool = true,
                timePosition: LabelPosition = .center,
                dateEnabled: Bool = true,
                datePosition: LabelPosition = .bottomCenter) { ... }

    public static let `default` = LabelSettings()
}

/// 설정 UI/네비게이션에서 어떤 라벨을 다루는지 식별.
public enum LabelKind: String, CaseIterable, Sendable, Hashable {
    case time, date
}
```

- `verticalAnchor`: top→1.0, center→0.5, bottom→0.0 (CoreAnimation 원점이 하단이므로). 미리보기(SwiftUI, 상단 원점)에서는 반대로 매핑하는 별도 헬퍼나 `1 - verticalAnchor` 사용.
- `origin(...)`은 순수 함수 → 9구역 전부 단위 테스트.

## 6. 저장 (TCA `@Shared(.appStorage)`)

원시값 4개 키로 영속(=UserDefaults). `LabelPosition: Int`라 RawRepresentable로 appStorage 지원.

| 키 | 타입 | 기본값 |
|---|---|---|
| `label.time.enabled` | Bool | true |
| `label.time.position` | LabelPosition(Int) | .center |
| `label.date.enabled` | Bool | true |
| `label.date.position` | LabelPosition(Int) | .bottomCenter |

- SettingsFeature/LabelPositionFeature가 `@Shared`로 읽고/쓴다(영속·반응형 자동).
- ExportFeature는 같은 4개 `@Shared(.appStorage)`를 **`State`에 보유**(각 기본값 있어 기존 `init` 시그니처에 추가 불필요)하고, `startExport`에서 현재 값으로 `LabelSettings`를 조립해 export에 전달.

## 7. 모듈 & 네비게이션

### 신규 모듈 `SettingsFeature`
- 위치: `Modules/SettingsFeature/Sources/`
- `Project.swift`에 `Module.framework(name: "SettingsFeature", dependencies: [AppCore, Models, DesignSystem, AnalyticsService, ComposableArchitecture])` 추가 + 앱 타겟 deps에 추가 → `tuist generate`.
- 파일:
  - `SettingsFeature.swift` — 리스트 리듀서(토글 4개·위치 행 탭 → router.push).
  - `SettingsView.swift` — 목록 UI.
  - `LabelPositionFeature.swift` — 피커 리듀서(`State { kind: LabelKind }` + `@Shared` 위치).
  - `LabelPositionPickerView.swift` — 미니 미리보기 + 3×3 그리드.
- 테스트 타겟 `SettingsFeatureTests` (`Module.unitTests(for: "SettingsFeature", dependencies: [Models, ComposableArchitecture])`) — `Project.swift`에 함께 추가.

### 네비게이션 (기존 AppRouter → AppFeature.Path 패턴 그대로)
- `AppCore/AppRouter.swift` `Route` += `.settings`, `.labelPosition(LabelKind)`.
- `App/AppFeature.swift`:
  - `Path` += `.settings(SettingsFeature)`, `.labelPosition(LabelPositionFeature)`.
  - `Action` += `routerPushedSettings`, `routerPushedLabelPosition(kind: LabelKind)`.
  - Reduce에서 `state.path.append(.settings(...))` / `.labelPosition(LabelPositionFeature.State(kind:))`.
- `App/RootView.swift`:
  - `wireRouterHandlers()`의 `pushHandler` switch에 두 case 추가.
  - `destinationView(for:)` switch에 `.settings`/`.labelPosition` 렌더 추가(기존처럼 `.toolbar(.hidden)` + `.navigationBarBackButtonHidden(true)` + `.chalNaSwipeBack()`).
- **Home 진입점**: `HomeView.swift:60-69` 주석 복원 → `store.send(.settingsButtonTapped); router.push(.settings)`. `HomeFeature.settingsButtonTapped`는 analytics 로깅 후 `.none`(네비게이션은 View가 router로). `AppFeature` 의존성 그래프에 `SettingsFeature` 추가 필요.

## 8. UI (DDS)

### SettingsView
- `.chalNaScreen()` + 상단바: 좌측 `ChalNaIcon(.chevronLeft)` 뒤로(`router.pop()`), 중앙 "설정". (기존 push 화면 헤더 패턴/`.chalNaTopBar` 재사용)
- 본문: 섹션 헤더 "라벨"(mono tag, taupe) 아래 흰 카드 리스트(Gray.g100 보더, `ChalNaRadius.card`):
  - **시각 라벨** 행: 제목 "시각 라벨" + 보조 "HH:mm" / 우측 `Toggle`(tint `ChalNaColor.coral`) ↔ `@Shared label.time.enabled`.
  - **위치** 행: 좌측 "위치" / 우측 현재 구역명(`timePosition.koreanName`) + `ChalNaIcon(.chevronRight)`. 탭 → `router.push(.labelPosition(.time))`. `timeEnabled == false`면 비활성(회색·탭 불가).
  - **날짜 라벨** 행 / **위치** 행: 위와 동일(`.date`, "yyyy/MM/dd", `.bottomCenter`).

### LabelPositionPickerView
- 상단바: 뒤로 + 타이틀(`"\(kind == .time ? "시각" : "날짜") 라벨 위치"`).
- **미니 미리보기**: 9:16 비율 둥근 사각(`ChalNaColor.Gray.g200` 중립 배경). 선택 구역에 샘플 라벨 배치:
  - 시각: "12:30" 큰 글씨, 흰색 50% 불투명(익스포트 트리트먼트 모사).
  - 날짜: "2026/04/05" 작은 글씨, 흰색.
  - 위치 매핑은 `LabelPosition`의 anchor를 SwiftUI(상단 원점) 좌표로 변환해 사용 → 익스포트 결과와 시각적으로 일치.
- **3×3 그리드**: 9칸(좌상~우하), 셀 라벨은 사용자 표기(좌측 상단/중앙 상단/…). 선택 칸은 coral 보더+옅은 coral 배경. 탭 → `@Shared` 위치 갱신 → 미리보기 즉시 반영.

## 9. 익스포트 연동 (`CompositionService`)

- 프로토콜·클라이언트·구현 시그니처 확장:
  - `CompositionServicing.export(clips:rotations:labelSettings:)`. 기존 `export(clips:)`/`export(clips:rotations:)` 편의 오버로드는 `labelSettings: .default`로 위임(테스트/구버전 호환).
  - `CompositionClient.export` 클로저에 `labelSettings: LabelSettings` 인자 추가, liveValue에서 service로 전달.
- `makeDateLabelAnimationTool(renderSize:entries:labelSettings:)`로 일반화:
  - `labelSettings.timeEnabled`일 때만 시각 레이어 생성, 위치는 `labelSettings.timePosition.origin(renderSize:textSize:padding:)`.
  - `labelSettings.dateEnabled`일 때만 날짜 레이어 생성, 위치는 `datePosition.origin(...)`.
  - 글씨 크기/투명도/폰트/그림자는 **현행 유지**(시각 0.18·0.5, 날짜 0.035·1.0). padding은 현재 `padX/padY` 재사용.
  - 둘 다 disabled면 animationTool 생략.
- `ExportFeature`:
  - `@Shared(.appStorage(...))` 4개를 `State`에 보유, `startExport`에서 `LabelSettings` 조립.
  - `startExport`/`retryTapped`의 `compositionClient.export(clips, rotations, labelSettings)`로 전달.

## 10. 엣지케이스

- 두 라벨이 같은 구역 → **세로 스택**(시각이 위, 날짜가 아래)으로 그 구역에 정렬. (`AVFoundationCompositionService.stackedOrigins(...)` 순수 함수; 익스포트 렌더에만 적용 — 피커 미리보기는 한 라벨만 표시.) 서로 다른 구역이면 독립 배치.
- corner 구역 + 큰 시각 라벨 → `origin(...)`의 min/max 클램프로 캔버스 밖 클리핑 방지.
- 모든 라벨 OFF + 클립 정상 → 영상은 정상 생성, 오버레이만 없음.
- `@Shared` 최초 실행 시 키 부재 → 기본값(D6) 적용 → 기존 동작과 동일.

## 11. 테스트 (Swift Testing)

- `SettingsFeatureTests/LabelPositionTests`: 9구역 각각 `origin(renderSize:textSize:padding:)` 기대 좌표 검증(코너 padding, center 중앙, 클램프). (Models엔 별도 테스트 타겟이 없어 SettingsFeatureTests가 Models를 import해 검증)
- `SettingsFeatureTests`: TestStore로 토글 액션이 `@Shared` enabled를 바꾸는지.
- `LabelPositionFeatureTests`: TestStore로 구역 선택이 `@Shared` position을 바꾸는지.
- (선택) CompositionService: disabled 라벨이 오버레이를 만들지 않는지(레이어 카운트/스냅샷 — 가능 범위에서).

## 12. Analytics (`AnalyticsService`)

`AnalyticsEvent`에 case 추가(기존 snake_case `name`/`parameters` 패턴):
- `settingsOpened`
- `labelToggled(kind: LabelKind, on: Bool)`
- `labelPositionChanged(kind: LabelKind, position: LabelPosition)`

호출: SettingsFeature/LabelPositionFeature가 `@Dependency(\.analyticsTracker)`로 로깅.

## 13. 변경/신규 파일 요약

신규
- `Modules/Models/Sources/LabelSettings.swift`
- `Modules/SettingsFeature/Sources/{SettingsFeature,SettingsView,LabelPositionFeature,LabelPositionPickerView}.swift`
- `Modules/SettingsFeature/Tests/{LabelPositionTests,SettingsFeatureTests,LabelPositionFeatureTests}.swift`

변경
- `Project.swift` (+SettingsFeature 타겟·앱 deps·테스트 타겟)
- `Modules/HomeFeature/Sources/HomeView.swift` (gear 버튼 복원)
- `Modules/CompositionService/Sources/{CompositionService,CompositionClient}.swift` (labelSettings 인자)
- `Modules/ExportFeature/Sources/ExportFeature.swift` (@Shared 읽어 전달)
- `Modules/AppCore/Sources/AppRouter.swift` (Route += settings/labelPosition)
- `ChalNa/Sources/App/AppFeature.swift` (Path/Action/Reduce)
- `ChalNa/Sources/App/RootView.swift` (handler/destination)
- `Modules/AnalyticsService/Sources/AnalyticsEvent.swift` (이벤트 3종)

## 14. 빌드/검증 순서

1. `tuist generate` (SettingsFeature 타겟 추가 후 필수).
2. `xcodebuild ... -scheme ChalNa build` 통과.
3. Swift Testing: LabelPosition/Settings/LabelPosition 리듀서 테스트 그린.
4. 시뮬레이터(권장: `ios-build-run`): Home gear → 설정 → 토글/위치 변경 → 익스포트 결과에 반영 확인.

## 15. 확장 (구현 후 추가)

- **라벨별 투명도(opacity)**: `LabelSettings`에 `timeOpacity`(기본 0.5)·`dateOpacity`(기본 1.0) 추가. `@Shared(.appStorage("labelTimeOpacity"/"labelDateOpacity"))`(Double, dot-free)로 영속. 설정 리스트에서 각 라벨 블록에 **투명도 슬라이더 행**(0–100%, 5% step, OFF면 비활성)으로 조절. `CompositionService`의 4개 오버레이(독립·스택 × 시각·날짜)가 하드코딩 0.5/1.0 대신 설정값 사용. 슬라이더 드래그가 잦아 Analytics는 미기록. (피커 미리보기는 위치 전용이라 대표 투명도 0.5/1.0 유지.)
- **미리보기 폰트 일치**: 위치 피커의 미니 미리보기 샘플 라벨이 실제 영상과 동일한 **KERISKEDU** 폰트 사용. `ChalNaTypography.keris(_:weight:)`(DesignSystem)가 `CompositionService`와 동일한 패밀리 스캔 규칙(KERIS→Line/Outline 변형, 실패 시 시스템 bold)으로 SwiftUI `Font` 반환. (앱은 `UIAppFonts`로 폰트를 프로세스 전역 등록.)

## 16. 구조 개편 — 설정 메뉴 한 단계 Deep (구현 후 추가)

향후 다른 설정 메뉴가 추가될 예정이라, 설정을 **2단계**로 재구성:
- `SettingsFeature`/`SettingsView` = **최상위 메뉴**(Home gear → `.settings`). 현재 "라벨" 행 1개(→ `.labelSettings` push). 향후 메뉴는 카드에 행만 추가.
- 신규 `LabelSettingsFeature`/`LabelSettingsView` = **라벨 하위 화면**(시각/날짜 토글·위치·투명도). 기존 SettingsFeature의 라벨 `@Shared` 상태·액션을 이전(키/기본값 동일). 위치 행 → `.labelPosition(kind)`는 그대로.
- 네비게이션: `Route`/`AppFeature.Path`에 `.labelSettings` 추가, RootView destination/handler 배선. `settingsOpened` 분석은 메뉴(`SettingsView.onAppear`)에 유지.
- 경로: Home gear → 설정(메뉴) → 라벨 → (위치 행) → 9구역 피커.
