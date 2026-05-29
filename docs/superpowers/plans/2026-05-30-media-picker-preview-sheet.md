# 선택된 미디어 미리보기 바텀시트 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `미디어 선택` 화면에서 선택된 미디어의 본문을 탭하면 하단 바텀시트로 Live Photo/영상을 확대해 play/pause로 미리보고, 제거는 코너 X 버튼으로만 하도록 한다.

**Architecture:** TCA `MediaPickerFeature`에 `previewAsset` 상태와 `previewRequested`/`previewDismissed` 액션만 추가(기존 `photoAssetTapped` 제거 로직은 그대로 재사용). 그리드 셀은 단일 `Button`에서 `onTapGesture`(미리보기) + 분리된 X `Button`(제거)로 바꾸고, 신규 `MediaPreviewSheet`(자체 `AVPlayerLayer` 래퍼 포함)를 `.sheet(item:)`으로 띄운다.

**Tech Stack:** Swift 6 / iOS 18+, SwiftUI, The Composable Architecture(TCA), AVFoundation, Swift Testing, Tuist. DesignSystem(`ChalNa*`) 토큰.

**기준 스펙:** `docs/superpowers/specs/2026-05-30-media-picker-preview-sheet-design.md`
**브랜치:** `feature/media-preview-sheet` (이미 최신 `main` 위로 rebase됨)

---

## File Structure

| 파일 | 책임 | 작업 |
|---|---|---|
| `Modules/MediaPickerFeature/Sources/MediaPickerFeature.swift` | TCA 리듀서 — `previewAsset` 상태 + 미리보기 액션 2개 | Modify |
| `Modules/MediaPickerFeature/Sources/MediaPreviewSheet.swift` | 미리보기 바텀시트 뷰 + `fileprivate` 플레이어 래퍼/컨트롤러 | Create |
| `Modules/MediaPickerFeature/Sources/MediaPickerView.swift` | 그리드 셀 인터랙션(본문=미리보기, X=제거) + `.sheet(item:)` 부착 | Modify |
| `Modules/MediaPickerFeature/Tests/MediaPickerPreviewTests.swift` | 리듀서 단위 테스트 (Swift Testing) | Create |
| `Project.swift` | `MediaPickerFeatureTests` 단위 테스트 타겟 등록 | Modify |

> 주의: `MediaPickerFeature.State`는 `source: MediaPickerSource`(내부에 `any DevMediaSourcing`)를 가져 **Equatable이 아니다** → TCA `TestStore` 사용 불가. 리듀서는 `MediaPickerFeature().reduce(into:&state, action:)`를 직접 호출해 개별 필드로 검증한다.

---

## Task 1: 리듀서에 미리보기 상태/액션 추가 (+ 테스트 타겟)

**Files:**
- Modify: `Project.swift` (테스트 타겟 등록)
- Create: `Modules/MediaPickerFeature/Tests/MediaPickerPreviewTests.swift`
- Modify: `Modules/MediaPickerFeature/Sources/MediaPickerFeature.swift`

- [ ] **Step 1: `Project.swift`에 테스트 타겟 등록**

`Project.swift`의 `targets:` 배열에서 마지막 `Module.unitTests(for: "TimelineFeature", ...)` 블록(파일 기준 169~176행) **바로 다음에** 아래를 추가한다(닫는 `),` 뒤, `]` 앞):

```swift
        Module.unitTests(
            for: "MediaPickerFeature",
            dependencies: [
                .target(name: "PhotosService"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
```

- [ ] **Step 2: 실패하는 테스트 작성**

`Modules/MediaPickerFeature/Tests/MediaPickerPreviewTests.swift` 생성:

```swift
import Testing
import ComposableArchitecture
import PhotosService
@testable import MediaPickerFeature

struct MediaPickerPreviewTests {

    private func makeAsset(id: String = "asset-1") -> PhotoLibraryAsset {
        PhotoLibraryAsset(id: id, kind: .livePhoto, capturedAt: nil, pixelSize: .zero)
    }

    @Test func previewRequested_setsPreviewAsset() {
        var state = MediaPickerFeature.State(source: .photoLibrary)
        let asset = makeAsset()

        _ = MediaPickerFeature().reduce(into: &state, action: .previewRequested(asset))

        #expect(state.previewAsset == asset)
    }

    @Test func previewDismissed_clearsPreviewAsset() {
        var state = MediaPickerFeature.State(source: .photoLibrary)
        state.previewAsset = makeAsset()

        _ = MediaPickerFeature().reduce(into: &state, action: .previewDismissed)

        #expect(state.previewAsset == nil)
    }
}
```

- [ ] **Step 3: 프로젝트 재생성 후 테스트 실행 → 컴파일 실패 확인 (red)**

```bash
cd /Users/inhochoi/Documents/ProductCode/OneSecMovie/Clone2
tuist generate
xcodebuild -workspace ChalNa.xcworkspace -scheme MediaPickerFeature \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -25
```

Expected: **빌드/컴파일 실패** — `previewAsset`, `.previewRequested`, `.previewDismissed` 미정의(`value of type 'MediaPickerFeature.State' has no member 'previewAsset'` 등). 이것이 red 상태.

- [ ] **Step 4: State에 `previewAsset` 추가**

`MediaPickerFeature.swift`의 `@ObservableState public struct State` 안, `public var confirmation: Confirmation?`(45행) **바로 아래**에 추가:

```swift
        /// 미리보기 시트로 띄울 선택된 미디어. nil 이면 시트가 닫혀 있음.
        public var previewAsset: PhotoLibraryAsset?
```

(`PhotoLibraryAsset?`의 기본값은 옵셔널이라 `init`에서 별도 설정 없이 `nil`로 시작한다.)

- [ ] **Step 5: Action에 미리보기 케이스 2개 추가**

`public enum Action`에서 `case photoAssetTapped(PhotoLibraryAsset)`(87행) **바로 아래**에 추가:

```swift
        // Preview
        case previewRequested(PhotoLibraryAsset)
        case previewDismissed
```

- [ ] **Step 6: 리듀서에 분기 2개 추가**

`Reduce { state, action in switch action {` 내부, `case let .photoAssetTapped(asset):` 블록(260~270행)의 `return .send(.startSyncingMedia(ids: state.selectedAssetIDs))` 직후, `case let .startSyncingMedia(ids):` 바로 **앞**에 추가:

```swift
            case let .previewRequested(asset):
                state.previewAsset = asset
                return .none

            case .previewDismissed:
                state.previewAsset = nil
                return .none
```

- [ ] **Step 7: 테스트 실행 → 통과 확인 (green)**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme MediaPickerFeature \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -25
```

Expected: **TEST SUCCEEDED** — `previewRequested_setsPreviewAsset`, `previewDismissed_clearsPreviewAsset` 통과.

- [ ] **Step 8: 커밋**

```bash
git add Project.swift Modules/MediaPickerFeature/Sources/MediaPickerFeature.swift \
        Modules/MediaPickerFeature/Tests/MediaPickerPreviewTests.swift
git commit -m "✨ feat: MediaPicker 리듀서에 미리보기 상태/액션 추가

선택된 미디어 미리보기 시트용 previewAsset 상태와
previewRequested/previewDismissed 액션 추가. MediaPickerFeatureTests
타겟을 신규 등록하고 리듀서 동작을 Swift Testing으로 검증.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `MediaPreviewSheet` 뷰 + 플레이어 래퍼 생성

**Files:**
- Create: `Modules/MediaPickerFeature/Sources/MediaPreviewSheet.swift`

- [ ] **Step 1: 파일 생성 — 시트 뷰 + 컨트롤러 + 플레이어 래퍼 전체 작성**

`Modules/MediaPickerFeature/Sources/MediaPreviewSheet.swift`:

```swift
import SwiftUI
import AVFoundation
import UIKit
import ComposableArchitecture
import DesignSystem
import PhotosService

/// 선택된 미디어(Live Photo paired video / 일반 영상)를 하단 바텀시트에서
/// 확대해 보여주고 탭으로 play/pause 하는 미리보기 시트.
struct MediaPreviewSheet: View {
    let asset: PhotoLibraryAsset
    let store: StoreOf<MediaPickerFeature>

    @State private var controller = PreviewPlaybackController()

    /// 시트가 떠 있는 동안 store에서 reactively 읽는 미디어 상태.
    private var media: MediaLoadState {
        store.media[asset.id] ?? MediaLoadState(kind: asset.kind)
    }

    var body: some View {
        ZStack {
            ChalNaColor.cream.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                metaRow
                stage
                hint
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(ChalNaRadius.sheet)
        .onAppear { startIfPossible() }
        .onDisappear { controller.stop() }
        .onChange(of: media.videoURL) { _, _ in startIfPossible() }
    }

    // MARK: - Meta

    private var metaRow: some View {
        HStack(spacing: 8) {
            switch media.kind {
            case .livePhoto: ChalNaChip("LIVE", variant: .live)
            case .video:     ChalNaChip("VIDEO", variant: .video, icon: .film)
            case .image, .unknown: EmptyView()
            }

            if let duration = media.duration, duration > 0 {
                Text(String(format: "%.1f초", duration))
                    .font(ChalNaTypography.monoFallback(13, weight: .medium))
                    .foregroundColor(ChalNaColor.taupe)
            }

            Spacer()
        }
    }

    // MARK: - Video stage

    private var stage: some View {
        ZStack {
            ChalNaColor.ink

            if media.videoURL != nil {
                PreviewPlayerLayerView(player: controller.player)
                if !controller.isPlaying {
                    pausedOverlay
                }
            } else if media.videoFailed {
                failureContent
            } else {
                loadingContent
            }
        }
        .aspectRatio(stageAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: 380)
        .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            guard media.videoURL != nil else { return }
            controller.toggle()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(controller.isPlaying ? "재생 중. 탭하면 멈춰요" : "일시정지. 탭하면 재생돼요")
    }

    private var pausedOverlay: some View {
        Circle()
            .fill(Color.white.opacity(0.92))
            .frame(width: 64, height: 64)
            .overlay(ChalNaIcon(.play, size: 26).foregroundColor(ChalNaColor.ink).offset(x: 2))
    }

    private var failureContent: some View {
        VStack(spacing: 10) {
            thumbnailImage
            Text("영상을 불러오지 못했어요")
                .font(ChalNaTypography.krBody(13, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(16)
    }

    private var loadingContent: some View {
        ZStack {
            thumbnailImage
            ProgressView().tint(ChalNaColor.coral)
        }
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        if let data = media.thumbnail, let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable().scaledToFit()
        } else {
            ChalNaColor.ivory.opacity(0.2)
        }
    }

    private var hint: some View {
        Text(media.videoURL != nil ? "영상을 탭하면 재생/일시정지돼요." : "원본 영상이 없는 미디어예요.")
            .font(ChalNaTypography.krBody(12))
            .foregroundColor(ChalNaColor.taupe)
    }

    // MARK: - Derived

    private var stageAspectRatio: CGFloat {
        if let size = media.displaySize, size.width > 0, size.height > 0 {
            return size.width / size.height
        }
        return 3.0 / 4.0
    }

    private func startIfPossible() {
        if let url = media.videoURL {
            controller.start(url: url)
        }
    }
}

// MARK: - Playback controller

/// 미리보기용 단일 AVPlayer 루프 재생 컨트롤러. GCD 미사용 — 종료 감지는 NotificationCenter만 사용.
@Observable
final class PreviewPlaybackController {
    let player = AVPlayer()
    private(set) var isPlaying = false

    private var endObserver: NSObjectProtocol?
    private var currentURL: URL?

    func start(url: URL) {
        if currentURL == url, player.currentItem != nil {
            player.play()
            isPlaying = true
            return
        }
        stop()
        currentURL = url

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.seek(to: .zero)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }
        player.play()
        isPlaying = true
    }

    func toggle() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func stop() {
        player.pause()
        isPlaying = false
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        player.replaceCurrentItem(with: nil)
        currentURL = nil
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }
}

// MARK: - AVPlayerLayer 래퍼 (TimelineFeature PlayerLayerView 의 로컬 미러)

private struct PreviewPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PreviewPlayerHostView {
        let view = PreviewPlayerHostView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: PreviewPlayerHostView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}

private final class PreviewPlayerHostView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

// MARK: - Preview

#Preview("MediaPreviewSheet — 영상 없음") {
    let asset = PhotoLibraryAsset(id: "p1", kind: .livePhoto, capturedAt: nil, pixelSize: .zero)
    var state = MediaPickerFeature.State(source: .photoLibrary)
    state.photoAssets = [asset]
    state.selectedAssetIDs = [asset.id]
    var loaded = MediaLoadState(kind: .livePhoto)
    loaded.videoFailed = true   // 캔버스엔 실제 영상 URL이 없으니 실패 상태로 시각 검증
    loaded.duration = 1.5
    state.media[asset.id] = loaded

    return Color.clear.sheet(isPresented: .constant(true)) {
        MediaPreviewSheet(
            asset: asset,
            store: Store(initialState: state) { MediaPickerFeature() }
        )
    }
}
```

- [ ] **Step 2: 모듈 빌드로 컴파일 확인**

```bash
cd /Users/inhochoi/Documents/ProductCode/OneSecMovie/Clone2
tuist generate
xcodebuild -workspace ChalNa.xcworkspace -scheme MediaPickerFeature \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -20
```

Expected: **BUILD SUCCEEDED**. (Xcode에서 `MediaPreviewSheet.swift`의 `#Preview`로 "영상 없음" 레이아웃 시각 확인 가능.)

- [ ] **Step 3: 커밋**

```bash
git add Modules/MediaPickerFeature/Sources/MediaPreviewSheet.swift
git commit -m "✨ feat: 미디어 미리보기 바텀시트(MediaPreviewSheet) 추가

선택된 Live Photo/영상을 ink letterbox stage에서 자동재생+루프로
보여주고 탭으로 play/pause. AVPlayerLayer 래퍼와 NotificationCenter
기반 루프 컨트롤러를 동일 파일에 fileprivate로 포함(GCD 미사용).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 그리드 셀 인터랙션 변경 + 시트 연결

**Files:**
- Modify: `Modules/MediaPickerFeature/Sources/MediaPickerView.swift`

- [ ] **Step 1: `.sheet(item:)`로 미리보기 시트 연결**

`MediaPickerView.body`에서 시스템 PHPicker `.sheet(isPresented:)` 블록(97~112행)의 닫는 `}` **바로 다음**, `.overlay {`(113행) **앞**에 추가:

```swift
        .sheet(
            item: Binding(
                get: { store.previewAsset },
                set: { if $0 == nil { store.send(.previewDismissed) } }
            )
        ) { asset in
            MediaPreviewSheet(asset: asset, store: store)
        }
```

- [ ] **Step 2: 그리드 셀을 본문 탭(미리보기) + 별도 X 버튼(제거)로 교체**

`photoGrid`의 `ForEach(Array(selectedAssets.enumerated()), id: \.element.id) { idx, asset in ... }` 본문(409~439행)을 아래로 **통째 교체**한다:

```swift
                    ForEach(Array(selectedAssets.enumerated()), id: \.element.id) { idx, asset in
                        ClipThumbCard(
                            state: .selected,
                            size: CGSize(width: 84, height: 108)
                        ) {
                            photoThumbnail(for: asset)
                        }
                        .overlay(alignment: .topLeading) {
                            kindChip(for: asset.kind)
                                .scaleEffect(0.78, anchor: .topLeading)
                                .fixedSize(horizontal: true, vertical: true)
                                .offset(x: -5, y: -7)
                                .allowsHitTesting(false)
                        }
                        .overlay(alignment: .topTrailing) {
                            removeBadge(for: asset)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissTitleKeyboard()
                            store.send(.previewRequested(asset))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(thumbnailAccessibilityLabel(for: asset, index: idx, isSelected: true))
                        .accessibilityHint("탭하면 미리보기가 열려요")
                    }
```

- [ ] **Step 3: `removeBadge(for:)` 헬퍼 추가**

`MediaPickerView`의 `kindChip(for:)` 함수(525~532행) **바로 다음**에 추가:

```swift
    /// 선택된 미디어를 선택에서 제외하는 코너 X 버튼. 본문 탭(미리보기)과 분리된 히트 영역.
    private func removeBadge(for asset: PhotoLibraryAsset) -> some View {
        Button {
            dismissTitleKeyboard()
            store.send(.photoAssetTapped(asset))
        } label: {
            ChalNaIcon(.close, size: 10)
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(ChalNaColor.coral))
                .frame(width: 40, height: 40, alignment: .topTrailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("선택에서 제외")
        .accessibilityHint("\(asset.kind == .video ? "비디오" : "라이브 포토")를 선택에서 빼요")
    }
```

> 셀(84×108)에 맞춰 X 시각 크기(22pt 원)는 유지하고, 탭 히트 영역만 40×40으로 키워 우상단 정렬한다. 본문 `onTapGesture`는 이 Button 프레임 밖에서만 동작하므로 X와 미리보기가 충돌하지 않는다.

- [ ] **Step 4: fresh 빌드 + 시뮬레이터 실행으로 시각 검증**

```bash
cd /Users/inhochoi/Documents/ProductCode/OneSecMovie/Clone2
tuist generate
xcodebuild -workspace ChalNa.xcworkspace -scheme "ChalNa Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -20
```

Expected: **BUILD SUCCEEDED**.

수동 확인(또는 `ios-build-run` 서브에이전트 위임 — `ChalNa Dev` 스킴은 devMock fixture로 사진 권한 없이 플로우 검증 가능):
1. 홈 → 미디어 선택 진입, PHPicker(또는 dev fixture)로 미디어 선택.
2. 선택된 셀 **본문 탭** → 하단 바텀시트가 올라오고 영상이 자동재생+루프되는지.
3. 시트의 영상 **탭** → play/pause 토글, 일시정지 시 coral play 아이콘 표시.
4. 드래그 인디케이터/아래로 스와이프로 시트 닫힘 → 선택 유지(제거 안 됨).
5. 셀 **코너 X 탭** → 해당 미디어가 선택에서 제거(시트 안 열림).

- [ ] **Step 5: 전체 테스트 회귀 확인**

```bash
xcodebuild -workspace ChalNa.xcworkspace -scheme MediaPickerFeature \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -15
```

Expected: **TEST SUCCEEDED** (Task 1의 리듀서 테스트 그대로 통과).

- [ ] **Step 6: 커밋**

```bash
git add Modules/MediaPickerFeature/Sources/MediaPickerView.swift
git commit -m "✨ feat: 선택 미디어 본문 탭→미리보기, 코너 X→제거로 분리

그리드 셀의 단일 Button을 본문 onTapGesture(previewRequested)와
별도 X Button(photoAssetTapped 제거)으로 분리하고 MediaPreviewSheet를
.sheet(item:)으로 연결. 접근성 라벨/힌트도 미리보기/제거에 맞게 조정.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review 결과

**1. Spec coverage**
- 인터랙션(본문=미리보기 / X=제거) → Task 3 Step 2·3 ✅
- 상태(`previewAsset` + 액션 2개) → Task 1 ✅
- `MediaPreviewSheet`(detents·자동재생·루프·탭 토글·엣지) → Task 2 ✅
- 플레이어 래퍼(로컬 미러, GCD 미사용) → Task 2 Step 1 ✅
- 범위(photoLibrary만, dev는 미변경) → `photoGrid`만 수정, `devGrid` 손대지 않음 ✅
- 테스트(리듀서) → Task 1 ✅ / UI는 `#Preview` → Task 2 ✅
- 시트 바인딩 코드 → Task 3 Step 1 ✅

**2. Placeholder scan:** "TODO/TBD/적절히 처리" 류 없음. 모든 코드 스텝에 실제 코드 포함 ✅

**3. Type consistency:**
- `previewAsset: PhotoLibraryAsset?` ↔ `previewRequested(PhotoLibraryAsset)` ↔ 테스트의 `state.previewAsset == asset` 일치.
- `MediaPreviewSheet(asset:store:)` 시그니처가 Task 2 정의와 Task 3 호출에서 동일.
- `PreviewPlaybackController`(`player`/`isPlaying`/`start`/`toggle`/`stop`)·`PreviewPlayerLayerView`/`PreviewPlayerHostView` 모두 Task 2 내 정의·사용 일치.
- `removeBadge(for:)`/`MediaPreviewSheet` 등 사용된 심볼이 모두 계획 내 정의됨 ✅

**4. Ambiguity:** 삽입 위치를 행 번호 + 인접 코드로 명시. 한 가지 환경 의존(시뮬레이터에 실제 video URL 없음)은 `#Preview`에서 `videoFailed` 상태로 우회 ✅

## 비목표 (YAGNI)
- dev fixtures 미리보기 / 스크럽바 / 음소거 토글 / `PlayerLayerView` 공용화 / 미디어 추가(PHPicker) 변경.
