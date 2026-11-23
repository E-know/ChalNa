import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem

/// 클립 1개를 9:16 캔버스 안에서 핀치 줌·드래그·회전으로 프레이밍하는 풀스크린 화면.
/// 전경은 aspectFill(센터 크롭) 기준 + ClipFraming.resolvedRect 배치 → export 와 픽셀 일치(WYSIWYG).
/// 편집은 EditSession 에 live 반영(회전 기존 동작과 동일, 별도 취소 없음).
///
/// 인터랙션:
/// - 좌우 가장자리에 가까워지면 잠시 정렬되고, 핀치 중 양쪽이 가까우면 캔버스 폭에 맞춘다.
///   계속 움직여 스냅 범위를 벗어나면 캔버스보다 작게 줄이거나 밖으로 밀어낼 수 있다.
/// - 드래그/핀치 중에는 3분할 격자를 더 선명하게 표시한다.
/// - 더블탭 = 기본 프레이밍(센터 크롭) 리셋. 스프링 애니메이션은 이 리셋에만 남는다.
public struct ClipAdjustView: View {
    @Environment(EditSession.self) private var session

    let store: StoreOf<ClipAdjustFeature>
    @State private var playback = ClipPlaybackController()
    /// 스냅으로 보정한 위치를 다음 제스처 델타에 누적하면 가장자리에서 떠날 수 없다.
    @State private var rawFraming: ClipTransform?
    @State private var horizontalSnap: HorizontalFramingSnap?

    public init(store: StoreOf<ClipAdjustFeature>) {
        self.store = store
    }

    private static let render = CGSize(width: 1080, height: 1920)
    private static let snapBack: Animation = ChalNaMotion.spring

    private var clip: Clip? { session.clips.first { $0.id == store.clipID } }
    private var rotation: ClipRotation { session.rotation(for: store.clipID) }
    private var committed: ClipTransform { session.transform(for: store.clipID) }
    private var displaySize: CGSize { clip?.displaySize ?? CGSize(width: 9, height: 16) }
    private var displayedFraming: ClipTransform { horizontalSnap?.transform ?? rawFraming ?? committed }

    public var body: some View {
        ClipEditorWorkspace(title: "화면 조정") {
            canvas
        } controls: {
            VStack(spacing: 12) {
                adjustHint
                controls
                Button("편집에 적용") { store.send(.doneTapped) }
                    .buttonStyle(.chalNa(.primary, size: .md, fillWidth: true))
                    .accessibilityIdentifier("timeline.adjust.apply")
            }
        }
        .onAppear {
            playback.load(clip: clip)
            playback.play()
        }
        .onDisappear { playback.pause() }
    }

    private var canvas: some View {
        ChalNaCanvas { box in
            let factor = box.width / Self.render.width
            let rrect = ClipFraming.resolvedRect(
                display: displaySize, rotation: rotation,
                render: Self.render, transform: displayedFraming
            )

            RotatableContent(rotation: rotation) {
                foreground
            }
            .frame(width: rrect.width * factor, height: rrect.height * factor)
            .position(x: rrect.midX * factor, y: rrect.midY * factor)

            if let clip { AutoLabelsOverlay(box: box, capturedAt: clip.capturedAt) }
            thirdsGrid(box: box)
                .opacity(rawFraming == nil ? 0.55 : 1)
                .animation(ChalNaMotion.fast, value: rawFraming != nil)
        } overlay: { box in
            PinchPanGesture(
                onChange: { handleGestureChange($0, $1, viewBox: box) },
                onEnded: { commitLive() }
            )
            .frame(width: box.width, height: box.height)
            .onTapGesture(count: 2) { resetToCenterCrop() }
        }
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

    /// 3분할(rule of thirds) 격자.
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
            context.stroke(path, with: .color(ChalNaColor.onMediaDark.opacity(0.35)), lineWidth: 2.5)
            context.stroke(path, with: .color(ChalNaColor.onMedia.opacity(0.85)), lineWidth: 1)
        }
        .frame(width: box.width, height: box.height)
        .allowsHitTesting(false)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button { rotate() } label: {
                HStack(spacing: 6) {
                    ChalNaIcon(.rotate, size: 16, weight: .semibold)
                    Text("90° 회전")
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

    }

    private var adjustHint: some View {
        Text("드래그로 위치를 옮기고 두 손가락으로 크기를 조정해요.")
            .font(ChalNaTypography.caption)
            .foregroundColor(ChalNaColor.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
    }

    private func rotate() {
        store.send(.rotateTapped)
        clearGesture()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// 기본 프레이밍(센터 크롭)으로 리셋 — 더블탭/초기화 버튼 공용.
    private func resetToCenterCrop() {
        // 시각 변화는 committed(EditSession) 갱신에서 오므로 세션 뮤테이션까지
        // withAnimation 안에 둬야 스프링이 실제로 애니메이션된다.
        withAnimation(Self.snapBack) {
            clearGesture()
            store.send(.resetTapped)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func handleGestureChange(_ scaleFactor: CGFloat, _ translation: CGSize, viewBox: CGSize) {
        guard viewBox.width > 0, viewBox.height > 0 else { return }
        var raw = rawFraming ?? committed
        raw.scale *= scaleFactor
        raw.offset.x += translation.width / viewBox.width
        raw.offset.y += translation.height / viewBox.height
        raw = raw.sanitized
        rawFraming = raw

        let previousEdge = horizontalSnap?.edge
        let isScaling = scaleFactor != 1
        guard isScaling || translation.width != 0 || previousEdge != nil else { return }
        let rect = ClipFraming.resolvedRect(display: displaySize, rotation: rotation, render: viewBox, transform: raw)
        horizontalSnap = HorizontalFramingSnap.resolve(
            raw, rect: rect, canvasWidth: viewBox.width, isScaling: isScaling, retaining: previousEdge
        )
        if let edge = horizontalSnap?.edge, edge != previousEdge, previousEdge != .both {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private func commitLive() {
        guard rawFraming != nil else { return }
        store.send(.framingChanged(displayedFraming))
        clearGesture()
    }

    private func clearGesture() {
        rawFraming = nil
        horizontalSnap = nil
    }
}

/// 구도와 자막 편집에서 사용하는 가변 9:16 작업 공간.
struct ClipEditorWorkspace<Canvas: View, Controls: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let canvas: () -> Canvas
    @ViewBuilder let controls: () -> Controls

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 16) {
                if ChalNaLayout.isSplit(proxy.size) {
                    HStack(spacing: 44) {
                        canvas().frame(maxWidth: .infinity, maxHeight: .infinity)
                        controls().frame(maxWidth: .infinity)
                    }
                } else {
                    canvas().frame(maxWidth: .infinity, maxHeight: .infinity)
                    controls()
                }
            }
            .foregroundStyle(ChalNaColor.textPrimary)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
        .chalNaScreen()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
