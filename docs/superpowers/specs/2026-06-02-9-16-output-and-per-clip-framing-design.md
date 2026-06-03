# 9:16 고정 출력 + 클립별 프레이밍(맞춤/줌/팬) — 설계 문서

- 작성일: 2026-06-02
- 브랜치 기준: `feature/splash-redesign`
- 대상 앱: ChalNa (SwiftUI · TCA · iOS 18+)

## 1. 목표

1. **Feature 1 — 출력 고정**: 최종 export 영상을 항상 **9:16 / 1080×1920px** 로 출력한다. (현재는 "가장 키 큰 클립"의 크기를 캔버스로 사용 → 가로/정사각 클립이 섞이면 출력 비율이 달라짐)
2. **Feature 2 — 클립별 프레이밍**: 모든 클립(Live Photo + 동영상)을 9:16 캔버스 안에서 사용자가 **핀치 줌 + 드래그(팬)** 로 자유롭게 맞추거나 채울 수 있게 한다. 기본 상태는 **맞춤(fit)**. 회전(기존 기능)도 같은 화면으로 통합한다.

### 확정된 제품 결정

| 항목 | 결정 |
|---|---|
| 출력 해상도 | 9:16 / 1080×1920 **고정** |
| 클립 크기 조절 | **핀치 줌 + 드래그**, 기본 = 맞춤(fit), 줌 범위 fit~4× |
| 빈 여백 처리 | **블러 필** — 클립의 대표 프레임(정지)을 확대·블러한 배경 |
| 블러 구현 | **A안: 정지 블러 + `AVVideoCompositionCoreAnimationTool`** (기존 라벨 오버레이 경로 재사용). 라이브 블러(커스텀 컴포지터)는 향후 과제 |
| 조정 UI | **전용 풀스크린 '조정' 화면** (클립 탭 또는 조정 버튼 → push) |
| 적용 범위 | **모든 클립** (`kind` 구분 없음) |
| 회전 | 기존 `cycleRotation` 을 조정 화면으로 **통합** (타임라인 독립 버튼 제거) |

## 2. 현재 상태 (코드 앵커)

- **출력 캔버스**: `CompositionService.resolveRenderSize(clips:rotations:)` (`Modules/CompositionService/Sources/CompositionService.swift:593-615`) 가 "oriented height 최대 클립"의 W×H 를 캔버스로 사용. 1080×1920 은 메타 추출 실패 시 fallback(`:597`)일 뿐. 결과는 `:165` 에서 받아 `:230` `videoComposition.renderSize` 에 할당.
- **클립 변환**: `CompositionService.transform(naturalSize:preferredTransform:rotation:renderSize:)` (`:652-712`) 가 `preferredTransform → normalizeAfterPreferred → rotationMatrix → rotationNormalize → scaleMatrix(fit) → centerTranslate` 체인 구성. **aspectFit 전용**(`:689` `min(...)`), 여백은 `centerTranslate`(`:698-701`)로 가운데 정렬 → 검은 레터박스.
- **라벨/배치 사각형**: `placedRect(...)` (`:716-739`) 가 fit 사각형 반환 → 라벨 폰트/위치 계산에 쓰임. 시간/날짜·커스텀 라벨은 `makeDateLabelAnimationTool(...)` (`:310-`) 의 `AVVideoCompositionCoreAnimationTool` 로 합성. `parentLayer`+`videoLayer` 구성(`:316-320`), 라벨은 `videoLayer` **위**에 add. 애니메이션 툴은 **라벨/시간/날짜가 켜졌을 때만** 부착됨(`:243`).
- **export 경로**: `ExportView.swift:51` `startExport(clips:rotations:clipLabels:)` → `ExportFeature.swift:100` → `compositionClient.export(clips, rotations, labelSettings, clipLabels)` (`:117`) → `CompositionClient.export` (`CompositionClient.swift:8-15`, live `:22`) → 액터 `export`/`buildComposition`(`CompositionService.swift:90,148`).
- **클립별 편집 상태**: `EditSession`(`Modules/AppCore/Sources/EditSession.swift`) 에 `rotations`(`:11`)·`labels`(`:13`)만 존재. `replace(...)`(`:27`)·`clear()`(`:34`) 에서 초기화. **scale/zoom/offset 상태 없음.** `Clip`(`Models/Sources/Clip.swift:9-44`) 의 `displaySize` 는 불변 메타데이터.
- **타임라인 프리뷰**: `PreviewPanel`(`TimelineFeature/Sources/Components/PreviewPanel.swift`) — 고정 224pt(`:9`), `ChalNaColor.ink` 검은 베이스(`:36`), 영상은 `PlayerLayerView`(`videoGravity = .resizeAspect`, `PlayerLayerView.swift:14`), 회전은 `RotatableContent`(`:52`). 라벨 박스 기하는 `LabelBoxGeometry.displayAspect/fittedBox` 사용(`:70-74`).
- **회전 진입점**: `TimelineView.swift:277` `onRotate: { rotateCurrentClip() }` → `:296-301` `session.cycleRotation` 즉시 적용.
- **저장본 미리보기**: `FilmDetailView.swift:133` `aspectRatio(16.0/9.0)` — **9:16 출력과 불일치(버그성)**.

## 3. Feature 1 — 9:16 고정 출력

### 변경

1. `CompositionService` 에 상수 추가:
   ```swift
   public static let outputSize = CGSize(width: 1080, height: 1920)
   ```
2. `resolveRenderSize(clips:rotations:)` — **시그니처 유지**(호출부 `:165` 무변경), 본문은 항상 `outputSize` 반환. "가장 키 큰 클립" 스캔 로직 제거. 이로 인해 고아가 되는 private 헬퍼 `effectiveSize`(`:626`)·`snapEven`(`:618`)은 **제거**(내 변경이 만든 미사용 코드 정리). 프리뷰/조정 화면은 `clip.displaySize`(+ 기존 `LabelBoxGeometry` 의 nil fallback)를 직접 쓰므로 async 자연 크기 로더가 불필요.
3. `transform(...)`·`placedRect(...)` 의 aspectFit + centerTranslate 는 **그대로** → 어떤 비율 클립이든 1080×1920 안에 자동 레터박스/필러박스.
4. `FilmDetailView.swift:133` `aspectRatio(16.0/9.0)` → `9.0/16.0` 으로 교정.
5. `ExportView` 의 export 미리보기 썸네일 비율이 9:16 인지 확인(이미 9:16 이면 유지).

### 검증
- `CompositionRenderSizeTests` (기존 "가장 큰 클립" 검증) → **고정 상수 검증으로 재작성**.
- `CompositionTransformTests` 의 fit/letterbox/회전 케이스는 renderSize 가 1080×1920 로 고정돼도 의미 유지 — renderSize 인자를 outputSize 로 바꿔 통과 확인.
- 시뮬레이터: 가로/세로/정사각 혼합 클립으로 export → 결과 mp4 가 1080×1920, 세로/정사각 클립은 좌우, 가로 클립은 위아래 여백(다음 단계에서 블러로 채움).

## 4. Feature 2 — 데이터 모델 & 합성 수학

### 4.1 신규 값 타입 — `Models/Sources/ClipTransform.swift`
```swift
public struct ClipTransform: Hashable, Sendable {
    /// fit(맞춤) 대비 배율. 1.0 = 맞춤, >1.0 = 확대. 범위 [1.0, 4.0].
    public var scale: CGFloat
    /// 캔버스(renderSize) 기준 정규화 평행이동. (-1…1) 비율, clamp 적용.
    public var offset: CGPoint
    public static let fit = ClipTransform(scale: 1, offset: .zero)
}
```
`ClipRotation`/`ClipLabel` 와 동일한 패턴·위치. `displaySize` 처럼 불변이 아니라 **사용자 편집 상태**.

### 4.2 WYSIWYG 단일 진실원천 — `Models/Sources/ClipFraming.swift`
프리뷰·조정 화면·export 가 **모두 같은 함수**로 위치를 계산해 드리프트를 차단한다. 순수 CoreGraphics 함수(부수효과 없음).
```swift
public enum ClipFraming {
    /// 회전 적용 후 표시 크기 → renderSize 안 aspectFit 배율.
    static func fitScale(display: CGSize, rotation: ClipRotation, render: CGSize) -> CGFloat
    /// 최종 전경 사각형(캔버스 좌표, y-down). scale·offset(clamp) 반영.
    static func resolvedRect(display: CGSize, rotation: ClipRotation, render: CGSize, transform: ClipTransform) -> CGRect
    /// 전경이 프레임을 덮는 경우 가장자리까지만, 작으면 중앙 고정하도록 offset clamp.
    static func clampedOffset(_ proposed: CGPoint, display: CGSize, rotation: ClipRotation, render: CGSize, scale: CGFloat) -> CGPoint
}
```
- 기존 `placedRect`(`CompositionService.swift:716`)의 fit·center 계산을 이 헬퍼로 일원화하고, `CompositionService` 는 이를 호출하도록 변경(중복 수학 제거).
- export 변환은 `resolvedRect` 로부터 평행이동·배율을 도출.

### 4.3 합성 수학 — `transform(...)` 확장
`CompositionService.transform(...)` 에 `transform: ClipTransform` 파라미터 추가. 체인:
```
... → scaleMatrix(fitScale × userScale) → centerTranslate(scaledSize 기준) → offsetTranslate(clampedOffset · render)
```
- 배율은 균일 스케일이라 회전과 교환법칙 성립 → `fitScale × userScale` 로 안전.
- offset 은 **renderSize(화면) 좌표 마지막** 적용 → 클립 회전과 무관하게 "오른쪽 드래그 = 오른쪽 이동" 직관 유지.
- 전경이 renderSize 를 넘치면 AVFoundation 이 renderSize 로 자동 클리핑(넘침은 가려짐) — 시각 확인 필요.

### 4.4 자막 결합 끊기
자막은 "고정 박스 스타일"(commit #21). 라벨 폰트/위치는 **캔버스(1080×1920) 기준 고정**으로 유지하고 **클립 줌의 영향을 받지 않도록** 한다.
- `makeDateLabelAnimationTool` 에 넘기는 `placedRect` 는 라벨 기준용으로 **fit 사각형(줌 미반영)** 을 그대로 사용(현행 유지). 즉 라벨 계산에는 `ClipTransform` 을 적용하지 않는다.
- 프리뷰의 라벨 오버레이(`PreviewPanel.labelOverlay`) 역시 줌과 분리.

### 4.5 상태 저장 — `EditSession`
- `public var scales: [Clip.ID: ClipTransform]` 추가.
- 접근자/뮤테이터: `transform(for:) -> ClipTransform`(miss = `.fit`), `setTransform(_:for:)`, `resetTransform(for:)`.
- **`replace(...)`·`clear()` 에서 `scales = [:]` 초기화** (rotations/labels 와 동일 — 누락 주의).

### 4.6 클라이언트/리듀서 관통
- `CompositionClient.export` 시그니처에 `scales: [Clip.ID: ClipTransform]` 추가(`CompositionClient.swift:8-15`), live(`:22`) 갱신.
- 액터 `export`/`buildComposition`(`CompositionService.swift:90,148`)에 `scales` 추가 → 클립 루프(`:171-224`)에서 `transform(...)` 호출 시 `scales[clip.id] ?? .fit` 전달.
- `ExportFeature.startExport`(`:100`)·`ExportView.swift:51` 호출부에 `session.scales` 전달.

## 5. Feature 2 — 블러 필 배경 (A안)

`makeDateLabelAnimationTool`(`CompositionService.swift:310-`)를 확장하거나 형제 헬퍼로 분리.

### 게이팅 변경
- `:243` 조건을 "**`hasContent` 이면 항상 애니메이션 툴 부착**"으로 변경(블러 배경을 항상 그려야 하므로). 라벨이 없어도 배경 레이어를 위해 툴이 필요.

### 레이어 구성
- `parentLayer`(`:316`)에 `videoLayer`(`:317`, `:320`) 추가는 유지하되, **각 클립의 블러 배경 레이어를 `videoLayer` 아래에 삽입**:
  ```swift
  parentLayer.insertSublayer(backdropLayer, below: videoLayer)
  ```
- 클립별 배경 레이어:
  - 소스: `clip.thumbnailData` → `CIImage` → `CIGaussianBlur`(radius ≈ renderHeight 비례, 예 48) → `CIContext` 로 `CGImage` 렌더 → `CALayer.contents`.
  - `frame = (0,0,renderSize)`, `contentsGravity = .resizeAspectFill`, `masksToBounds = true`.
  - 가독성용 어두운 스크림(검정 `opacity ≈ 0.18`) 레이어 옵션.
  - **시간창 게이팅**: 클립의 `timeRange` 동안만 보이도록 `opacity` 키프레임 애니메이션(`AVCoreAnimationBeginTimeAtZero` 기준) — 라벨 오버레이가 쓰는 방식과 동일.
- `thumbnailData == nil` 인 클립: 배경 생략(검정) 또는 `preset` 그라디언트를 이미지로 렌더해 fallback.

### 비용
- 빌드 시 정지 이미지 N개만 1회 블러 → per-frame 비용 0. export 속도 영향 미미.

## 6. Feature 2 — 전용 '조정' 화면 & 프리뷰 전파

### 6.1 새 라우트
- `AppFeature.Path` 에 `case clipAdjust(ClipAdjustFeature)` 추가(`AppFeature.swift:44-53`).
- AppRouter 호환 레이어: `AppRouter` 에 `push(.clipAdjust(clipID:))` 류 케이스 + `AppFeature` 에 `routerPushedClipAdjust(clipID:)` 액션 → `state.path.append(.clipAdjust(...))`. (기존 `routerPushedTimeline` 등과 동일 패턴, `:73-86`)
- `RootView.wireRouterHandlers()` 에 핸들러 1건 추가.

### 6.2 `ClipAdjustFeature` + `ClipAdjustView` (TimelineFeature 모듈 내)
- State: `clipID: Clip.ID`(편집 대상). 실제 transform/rotation 은 `@Environment(EditSession.self)` 공유 상태를 읽고 쓴다(기존 회전/라벨과 동일 — Route payload 아님).
- 화면 구성(9:16 캔버스 풀스크린):
  - 배경: `clip.thumbnailData` 를 `.scaledToFill()` + `.blur(radius:)` 로 채움(+ 어두운 스크림) — export 와 동일 룩.
  - 전경: 동영상은 `PlayerLayerView`(자동재생), Live/정지는 `thumbnailView`. **`ClipFraming.resolvedRect` 로 위치/크기 산출**(뷰 스케일 = viewSize/renderSize) → export 와 픽셀 일치.
  - 제스처: `MagnificationGesture`(scale, 1.0~4.0 clamp) + `DragGesture`(offset → `ClipFraming.clampedOffset`). 변경 시 `session.setTransform(...)` 즉시 반영.
  - 컨트롤: **회전 버튼**(기존 `cycleRotation` 재사용), **맞춤으로 리셋**(더블탭 또는 버튼 → `.fit`), **완료**(pop). 변경은 live 적용(회전 기존 동작과 일관) → 별도 cancel/snapshot 없음(단순화). 
  - 안내: 그리드/세이프영역 가이드 오버레이(선택).
  - 기존 push 화면 규약: `.toolbar(.hidden)` + `.navigationBarBackButtonHidden(true)` + `.chalNaSwipeBack()`.
- DesignSystem 토큰만 사용(색/타이포/라디우스/섀도우), spacing 은 리터럴.

### 6.3 진입점
- `EditToolbar` 의 **회전 버튼 슬롯을 '조정' 진입 버튼으로 교체** → `router.push(.clipAdjust(clipID: 현재 클립))`. 회전은 조정 화면 내부로 이동(중복 제거).
- 보조 진입: 타임라인 프리뷰 탭 → 동일 push (선택).
- `TimelineView.rotateCurrentClip()`(`:296-301`) 및 `currentRotationActive`(`:291`)는 조정 화면 쪽으로 정리/이동.

### 6.4 프리뷰 WYSIWYG 전파
- **타임라인 `PreviewPanel`**: 9:16 비율 + 블러 필 배경 + 현재 클립의 `ClipTransform`(`session.transform(for:)`) 반영.
  - 검은 `ChalNaColor.ink` 베이스(`:36`) → 블러 썸네일 배경으로 교체.
  - 전경을 `ClipFraming.resolvedRect` 로 배치(회전은 기존 `RotatableContent` 와 통합 또는 resolvedRect 가 회전 포함하도록 일원화).
  - 고정 224pt 패널은 유지하되 내부를 9:16 비율 컨테이너로(레이아웃 미세 조정).
- **`FilmDetailView` 썸네일**: `aspectRatio(9.0/16.0)` 로 교정(Feature 1 항목과 동일).

## 7. 모듈 / 의존성 영향

- `Models`: `ClipTransform.swift`, `ClipFraming.swift` 신규(의존 없음 — CoreGraphics/Foundation). 의존 규칙 위반 없음.
- `CompositionService`: 시그니처 + 합성 수학 + 블러 레이어. `Models` 의존(기존).
- `AppCore`(`EditSession`): `scales` 상태.
- `ExportFeature`: 호출부 관통.
- `TimelineFeature`: `ClipAdjustFeature`/`ClipAdjustView` 신규, `PreviewPanel`/`EditToolbar`/`TimelineView` 수정.
- `FilmDetailFeature`: 비율 교정.
- 앱 셸(`AppFeature`/`RootView`/`AppRouter`): 라우트 1건 배선.
- `Project.swift`: 새 파일은 기존 모듈 내부라 타겟 추가 불필요. `tuist generate` 만 재실행.

## 8. 테스트 전략 (Swift Testing)

- `ClipFramingTests`(신규, Models 또는 CompositionServiceTests): 
  - 가로/세로/정사각 × 회전 0/90/180/270 × scale 1/2/4 의 `resolvedRect` 기대값.
  - `clampedOffset` — fit(중앙 고정), 부분 줌, 완전 채움 경계.
- `CompositionRenderSizeTests`: 항상 1080×1920 반환.
- `CompositionTransformTests`: 기존 fit 케이스 + `ClipTransform` 적용 시 평행이동/배율 검증(`scale=1,offset=0` 은 기존과 동일해야 함 — 회귀 가드).
- devMock(`ChalNa Dev` 스킴): 권한 없이 fit/줌/팬 + 블러 배경 시각 확인.
- 프리뷰/조정 화면은 `#Preview` 로 상태별(맞춤/줌/팬/회전) 확인.

## 9. 리스크 & 완화

1. **프리뷰 ≠ export 드리프트** (최대 리스크): `ClipFraming` 단일 진실원천으로 양쪽 계산을 강제. 회귀 테스트로 `scale=1,offset=0` 가 기존 출력과 동일함을 고정.
2. **블러 게이팅 변경 부작용**: 애니메이션 툴을 항상 부착하면 렌더 경로가 바뀔 수 있음 → 라벨 OFF + 단일 세로 클립으로 기존과 동일 출력인지 시각 확인.
3. **scale × rotation 좌표계**: offset 을 renderSize 좌표 마지막 적용해 회전 무관 직관 유지. 90/270 회전 + 줌 케이스 테스트 필수.
4. **offset clamp 경계**: fit 상태에서 무의미한 팬 방지(양축 중앙 고정). 부분 줌에서 한 축만 팬 가능.
5. **자막 흔들림**: 라벨 계산에 `ClipTransform` 미적용으로 고정(§4.4).
6. **`thumbnailData` 부재 클립**: 배경 fallback 정의(§5).
7. **테스트 부채**: 기존 renderSize/transform 테스트 재작성.

## 10. 빌드 순서 (검증 기준)

1. **F1 (9:16 고정)** → `tuist generate` 빌드 통과 · `CompositionRenderSizeTests` 재작성 통과 · 혼합 클립 export 가 1080×1920.
2. **F2 모델/수학** (`ClipTransform`·`ClipFraming`·`EditSession`·클라이언트 관통·`transform` 확장) → `ClipFramingTests`/`CompositionTransformTests` 통과 · `scale=1,offset=0` 회귀 동일.
3. **F2 블러 필** (A안 배경 레이어 + 게이팅) → 시뮬레이터 시각 검증(여백이 블러로 채워짐, 라벨 OFF 회귀 OK).
4. **F2 조정 화면** (라우트·Feature·View·진입점·회전 통합) + **프리뷰 WYSIWYG**(PreviewPanel·FilmDetail) → 시뮬레이터에서 핀치/팬/회전/리셋 후 export 결과가 프리뷰와 일치.

각 단계 종료 시 커밋(한국어 메시지). iOS 빌드/실행은 `ios-build-run` 서브에이전트에 위임.

## 11. 범위 밖 (YAGNI)

- 라이브 블러(커스텀 `AVVideoCompositing`) — A안 정지 블러로 충분, 향후 과제.
- 자유 변형(키스톤/기울기), 클립별 크롭 비율 변경.
- 출력 해상도 선택 UI(720p 등) — 9:16/1080×1920 단일 고정.
- 배경을 블러 외 다른 효과(그라디언트/단색 선택)로 바꾸는 옵션.
