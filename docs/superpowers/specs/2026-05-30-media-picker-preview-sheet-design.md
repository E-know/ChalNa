# 미디어 선택 — 선택된 미디어 미리보기 바텀시트

**날짜**: 2026-05-30
**대상 모듈**: `MediaPickerFeature` (TCA), `DesignSystem` 토큰/컴포넌트 재사용
**상태**: 설계 확정 (구현 대기)
**기준 커밋**: `main`(origin 동기화, 앱 리네임 Moments→ChalNa + PHPicker 기반 리팩터 반영 후)

> 이 스펙은 최초 작성 후 `main`을 origin 기준으로 rebase 하면서 갱신됐다. MediaPicker 가 시스템 PHPicker 기반으로 리팩터되고 브랜드 prefix 가 `ChalNa` 로 바뀐 현재 코드를 전제로 한다.

## 배경 / 문제

`미디어 선택` 화면(`MediaPickerView.photoGrid`)의 그리드는 **시스템 PHPicker 로 골라온 미디어(=선택된 미디어)만** 보여준다 (`selectedAssets`). 즉 그리드의 모든 셀은 "이미 선택된" 상태다.

현재 셀 전체가 하나의 `Button` 이고, 탭하면 `store.send(.photoAssetTapped(asset))` → 리듀서가 해당 항목을 **선택에서 완전히 제거**한다 (`selectedAssetIDs`/`photoAssets`/`media`/`assetThumbnails` 모두 삭제). 셀 코너에는 이미 coral 원 + `ChalNaIcon(.close)` 오버레이(X 모양)가 그려져 있고, 접근성 힌트도 "탭하면 선택에서 제외돼요" 이다.

문제: **선택된 미디어를 탭하면 (X 영역이든 아니든) 곧바로 제거**된다. 사용자는 선택된 미디어의 **본문(코너 X 제외)을 탭하면 제거 대신 Live Photo 내부 동영상(또는 일반 영상)을 하단 바텀시트에서 확대해 play/pause 로 미리보기**하길 원한다. 제거는 코너 **X 버튼으로만** 일어나게 한다.

> 범위는 **이미 선택된 미디어(= 그리드의 모든 셀)의 탭 동작**에 한정한다. 미디어 "추가"는 기존대로 상단 PHPicker 런처(`사진 추가하기`/`다시 고르기`)로 하며 변경하지 않는다.

## 확인된 사실 (현재 코드 근거)

- 그리드는 `selectedAssets`(= `selectedAssetIDs` 로 필터된 `photoAssets`)만 렌더한다. **모든 셀 = 선택된 미디어**. 미선택 셀은 존재하지 않는다.
- 그리드 셀은 Live Photo / 일반 영상만 들어온다. PHPicker `config.filter = .any(of: [.livePhotos, .videos])`.
- `photosPickedFromSystemPicker` 가 picker 결과(`PickedMedia`)로 `media[id]` 를 **즉시(동기)** 채운다 — `thumbnail`, `videoURL`, `duration`, `capturedAt`, `displaySize` 포함. 따라서 미리보기 시점에 **영상이 이미 준비**돼 있다 (로딩 대기 거의 없음). `videoURL == nil` 이면 `videoFailed = true`.
- `photoAssetTapped(asset)` 는 현재 "선택 해제 = 완전 제거" 동작. (그리드가 선택 항목만 표시하므로 토글의 add 분기는 실질적으로 도달하지 않음.)
- 선택 표시는 `ClipThumbCard(state: .selected)` 의 coral 테두리. 코너 X 오버레이(`ChalNaColor.coral` 원 + `ChalNaIcon(.close, size: 10)`)는 `topTrailing` 에 이미 존재(단 셀 Button 안의 비-인터랙티브 오버레이).
- 디자인 시스템: `ChalNaBottomSheet`, `ChalNaIcon(.play/.pause/.close/...)`, `ChalNaRadius.sheet(=16)`, `ChalNaShadow.lg`, `ChalNaColor.{ink,coral,cream,ivory,taupe}`, `ChalNaTypography.*`, `ChalNaChip` 모두 존재.
- 프로젝트 방침: `VideoPlayer` 대신 **커스텀 `AVPlayerLayer` 래퍼 + 커스텀 컨트롤**(TimelineFeature `PlayerLayerView` 주석에 명시). 단 `PlayerLayerView` 는 `internal` 이고 **Feature 끼리 import 금지** 원칙상 재사용 불가 → MediaPickerFeature 내부에 동등한 작은 래퍼를 둔다.

## 인터랙션 모델 (그리드 셀 — 전부 선택된 미디어)

| 탭 위치 | 동작 |
|---|---|
| 코너 **X 버튼** | 선택에서 제거 (`photoAssetTapped`, 기존 동작) |
| X 외 **본문** | 미리보기 바텀시트 열기 (`previewRequested`, 신규) |

구현 방법:
- 셀 전체 `Button` → `ClipThumbCard` + `.contentShape(Rectangle())` + `.onTapGesture { store.send(.previewRequested(asset)) }` 로 변경 (본문 = 미리보기).
- 코너 X 오버레이를 **별도 `Button`** 으로 승격: `Button { store.send(.photoAssetTapped(asset)) } label: { coral 원 + ChalNaIcon(.close) }`.
  - SwiftUI 자식 `Button` 은 자기 프레임 내 탭을 가로채므로 본문 `onTapGesture` 와 충돌하지 않는다 (Button-in-Button 중첩 회피).
  - 시각 크기는 현행 유지(~22pt 원), 터치 영역은 HIG 고려해 `contentShape` + 충분한 패딩으로 ≥44pt 확보.
- 접근성:
  - 셀 본문: `accessibilityLabel(...)` + `accessibilityHint("탭하면 미리보기가 열려요")` (기존 "탭하면 선택에서 제외돼요" 힌트는 셀 본문에서 제거하고 X 버튼으로 이동).
  - X 버튼: `accessibilityLabel("선택에서 제외")`.

## 상태 변경 (TCA, 최소 추가)

`MediaPickerFeature.State`:
- 추가: `public var previewAsset: PhotoLibraryAsset?` (`PhotoLibraryAsset` 은 Hashable → Equatable/Identifiable 충족)

`MediaPickerFeature.Action`:
- 추가: `case previewRequested(PhotoLibraryAsset)` → `state.previewAsset = asset`, `.none`
- 추가: `case previewDismissed` → `state.previewAsset = nil`, `.none`

`photoAssetTapped` 로직은 **변경하지 않는다** (X 버튼이 그대로 재사용).

시트 바인딩(View): 닫힘만 액션으로 보내는 단방향.
```swift
.sheet(item: Binding(
    get: { store.previewAsset },
    set: { if $0 == nil { store.send(.previewDismissed) } }
)) { asset in
    MediaPreviewSheet(asset: asset, store: store)
}
```

## 신규 뷰 `MediaPreviewSheet`

위치: `Modules/MediaPickerFeature/Sources/MediaPreviewSheet.swift`

- 입력: `asset: PhotoLibraryAsset` + `store: StoreOf<MediaPickerFeature>`.
  - `StoreOf` 는 Observable 이므로 시트 내부에서 `store.media[asset.id]` 를 직접 읽으면 reactively 갱신된다(혹시 모를 늦은 로딩 대응).
- 시트 chrome: `.presentationDetents([.medium, .large])` + `.presentationDragIndicator(.visible)` + `.presentationCornerRadius(ChalNaRadius.sheet)` → 하단에서 올라오는 바텀시트.
- 레이아웃 (배경 `ChalNaColor.cream`):
  - 영상 stage: `ChalNaColor.ink` 배경 위 letterbox, `displaySize` 비율 유지(`aspectRatio(_, contentMode: .fit)`), 최대 높이 제한.
  - 메타: LIVE/VIDEO `ChalNaChip` + 길이(`duration`) 표기 (`ChalNaTypography`).
  - 재생 힌트 텍스트(예: "탭하면 멈춰요").
- 재생 동작:
  - 열리면 **자동재생 + 루프**.
  - 영상 영역 탭 → play/pause 토글. 일시정지 시 coral `ChalNaIcon(.play)` 오버레이, 재생 중엔 숨김.
  - 루프: `AVPlayerItemDidPlayToEndTime` 옵저버 → `seek(.zero)` + `play()`.
  - `onDisappear` 에서 `pause()` + 옵저버 정리.
- 엣지 케이스:
  - `videoURL == nil && !videoFailed`(로딩 중, 드묾): 썸네일 + `ProgressView`.
  - `videoFailed`(또는 `videoURL == nil`): 썸네일 + "영상을 불러오지 못했어요" 안내, 컨트롤 없음.

### 플레이어 래퍼 (동일 파일 내 `fileprivate`)

- 작은 `UIViewRepresentable`(약 20줄)로 `AVPlayerLayer` 호스트. TimelineFeature `PlayerLayerView` 의 미러.
- `videoGravity = .resizeAspect`.
- GCD 미사용: 종료 옵저버는 `NotificationCenter`, 필요 시 시간 옵저버는 `ClipPlaybackController` 와 동일하게 `addPeriodicTimeObserver(queue: .main)` 만 사용. `DispatchQueue`/`DispatchGroup` 직접 호출 없음.
- **수용한 트레이드오프**: `PlayerLayerView` 와 ~20줄 중복. Feature 간 import 금지 + DesignSystem 에 AVFoundation 의존 추가 회피를 위해 의도적 로컬 복제. 공용 추출은 별도 작업.

## 범위

- **photoLibrary 그리드만** 적용. `devGrid`(dev fixtures)는 실제 영상 URL 이 없으므로 **변경 없음**.
- Live Photo 와 일반 영상 **둘 다** 미리보기 지원 (`videoURL` 기반, 코드 경로 동일).

## 테스트

- TCA 리듀서 테스트 (Swift Testing, `MediaPickerFeatureTests` 신규 또는 적합 타겟):
  - `previewRequested(asset)` 전송 → `state.previewAsset == asset`.
  - `previewDismissed` 전송 → `state.previewAsset == nil`.
- 시트/플레이어 UI 는 프로젝트 관례대로 `#Preview` 로 시각 검증 (정상 / 로딩 / 실패 3상태).

## 변경 파일 요약

- `Modules/MediaPickerFeature/Sources/MediaPickerFeature.swift` — State 1필드 + Action 2케이스 + 리듀서 2분기 추가.
- `Modules/MediaPickerFeature/Sources/MediaPickerView.swift` — `photoGrid` 셀: 본문 `onTapGesture`(미리보기) + 코너 X를 별도 `Button`(제거)으로 분리, `.sheet(item:)` 부착, 접근성 라벨/힌트 조정.
- `Modules/MediaPickerFeature/Sources/MediaPreviewSheet.swift` — **신규** (시트 + `fileprivate` 플레이어 래퍼).
- 리듀서 테스트 파일 — **신규/추가**.

## 비목표 (YAGNI)

- dev fixtures 미리보기.
- 스크럽바/타임라인 슬라이더 등 고급 재생 컨트롤 (단순 play/pause + 루프만).
- 미디어 추가(PHPicker) 플로우 변경.
- `PlayerLayerView` 공용 모듈로의 추출.
