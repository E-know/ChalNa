import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem

/// 클립 1개를 9:16 캔버스 안에서 핀치 줌·드래그·회전으로 프레이밍(센터 크롭 조정)하는 풀스크린 화면.
/// 전경은 aspectFill(센터 크롭) 기준 + ClipFraming.resolvedRect 배치 → export 와 픽셀 일치(WYSIWYG).
/// 편집은 EditSession 에 live 반영(회전 기존 동작과 동일, 별도 취소 없음).
///
/// 인터랙션(UX 리서치 반영):
/// - 드래그가 크롭 한계를 넘으면 UIScrollView 러버밴드(c=0.55)로 저항, 손을 떼면 오버슛 없는 스프링 스냅백.
/// - 한계에 닿는 순간 1회 rigid 햅틱(상태-diff, 스팸 금지).
/// - 드래그 중에만 3분할 그리드 표시(Apple Photos 패턴).
/// - 더블탭 = 기본 프레이밍(센터 크롭) 리셋.
public struct ClipAdjustView: View {
    @Environment(EditSession.self) private var session

    let store: StoreOf<ClipAdjustFeature>
    @State private var playback = ClipPlaybackController()
    /// 제스처 중 무한 누적되는 원시 변환(러버밴드 미적용). nil = 제스처 없음.
    @State private var raw: ClipTransform? = nil
    /// 화면 표시 변환(러버밴드 적용). nil = committed 그대로.
    @State private var working: ClipTransform? = nil
    /// 드래그/핀치 진행 중 여부 — 3분할 그리드 표시 조건.
    @State private var isAdjusting = false
    /// 한계 도달 상태 — false→true 전이 때만 햅틱 1회.
    @State private var atEdge = false

    public init(store: StoreOf<ClipAdjustFeature>) {
        self.store = store
    }

    private static let render = CGSize(width: 1080, height: 1920)
    private static let snapBack: Animation = .spring(response: 0.35, dampingFraction: 0.85)

    private var clip: Clip? { session.clips.first { $0.id == store.clipID } }
    private var rotation: ClipRotation { session.rotation(for: store.clipID) }
    private var committed: ClipTransform { session.transform(for: store.clipID) }
    private var displaySize: CGSize { clip?.displaySize ?? CGSize(width: 9, height: 16) }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 0)
            canvas
            Spacer(minLength: 0)
            adjustHint
            controls
        }
        .chalNaScreen()
        .onAppear {
            playback.load(clip: clip)
            playback.play()
        }
        .onDisappear { playback.pause() }
    }

    private var topBar: some View {
        ChalNaNavigationBar(titleKey: "조정") {
            ChalNaHeaderBackButton { store.send(.backTapped) }
        } trailing: {
            ChalNaHeaderTextAction("완료") {
                store.send(.doneTapped)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .chalNaHeaderBar(scrollProgress: 1)
    }

    private var canvas: some View {
        GeometryReader { proxy in
            let box = LabelBoxGeometry.fittedBox(aspect: 9.0 / 16.0, in: proxy.size)
            let factor = box.width / Self.render.width
            let live = working ?? committed
            // 제스처 중에만 러버밴드 오버슛을 그대로 그리고(unclamped), 휴지 상태는
            // 항상 clamp 된 사각형으로 렌더 — PreviewPanel/export 와 픽셀 일치(WYSIWYG).
            let rrect = raw != nil
                ? resolvedRectUnclamped(transform: live)
                : ClipFraming.resolvedRect(display: displaySize, rotation: rotation, render: Self.render, transform: live)

            ZStack {
                // 러버밴드 오버슛 순간 드러나는 배경 — 스크롤 바운스처럼 검정.
                Color.black
                RotatableContent(rotation: rotation) {
                    foreground
                }
                .frame(width: rrect.width * factor, height: rrect.height * factor)
                .position(x: rrect.midX * factor, y: rrect.midY * factor)

                thirdsGrid(box: box)
                    .opacity(isAdjusting ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isAdjusting)
            }
            .frame(width: box.width, height: box.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous))
            .overlay(
                PinchPanGesture(
                    onChange: { handleGestureChange($0, $1, viewBox: box) },
                    onEnded: { commitWorking() }
                )
                .frame(width: box.width, height: box.height)
            )
            .onTapGesture(count: 2) { resetToCenterCrop() }
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .padding(.horizontal, 24)
    }

    /// 러버밴드 오버슛을 그대로 반영해야 하므로 clamp 없는 배치 사각형을 직접 계산한다.
    /// (한계 안 값은 `ClipFraming.resolvedRect` 와 동일 — scale·offset 산식 공유)
    private func resolvedRectUnclamped(transform: ClipTransform) -> CGRect {
        let s = ClipFraming.orientedSize(displaySize, rotation: rotation)
        let fill = ClipFraming.fillScale(display: displaySize, rotation: rotation, render: Self.render)
        let size = CGSize(width: s.width * fill * transform.scale, height: s.height * fill * transform.scale)
        let center = CGPoint(x: Self.render.width / 2 + transform.offset.x * Self.render.width,
                             y: Self.render.height / 2 + transform.offset.y * Self.render.height)
        return CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                      width: size.width, height: size.height)
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

    /// 3분할(rule of thirds) 그리드 — 드래그 중에만 표시.
    /// 밝은/어두운 영상 모두에서 보이도록 이중 스트로크(어두운 밑선 + 흰 윗선).
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
            context.stroke(path, with: .color(.black.opacity(0.35)), lineWidth: 2.5)
            context.stroke(path, with: .color(.white.opacity(0.85)), lineWidth: 1)
        }
        .frame(width: box.width, height: box.height)
        .allowsHitTesting(false)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button { rotate() } label: {
                HStack(spacing: 6) {
                    ChalNaIcon(.rotate, size: 16)
                    Text("회전")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.chalNa(.standardOutlined, size: .lg, fillWidth: true))
            .frame(maxWidth: .infinity)

            Button { resetToCenterCrop() } label: {
                HStack(spacing: 6) {
                    ChalNaIcon(.move, size: 16)
                    Text("초기화")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.chalNa(.standardOutlined, size: .lg, fillWidth: true))
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
    }

    private var adjustHint: some View {
        Text("드래그로 보이는 부분을 옮기고, 핀치로 확대해요. 더블탭 = 초기화")
            .font(ChalNaTypography.krBody(ChalNaTypography.Size.small))
            .foregroundColor(ChalNaColor.Gray.g500)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
    }

    private func rotate() {
        session.cycleRotation(for: store.clipID)
        // 회전으로 offset 이동 한계가 바뀌므로(가로↔세로 swap) committed 를 새 회전 기준으로
        // 재클램프해 세션에 반영 — 한계 밖 offset 이 남아 조정/프리뷰/export 가 어긋나는 것을 방지.
        let newRotation = rotation
        let current = committed
        let reclamped = ClipFraming.clampedOffset(
            current.offset, display: displaySize, rotation: newRotation, render: Self.render, scale: current.scale
        )
        if reclamped != current.offset {
            session.setTransform(ClipTransform(scale: current.scale, offset: reclamped), for: store.clipID)
        }
        // 진행 중이던 제스처 상태는 옛 회전 좌표계 값이므로 무효화.
        raw = nil
        working = nil
        atEdge = false
        isAdjusting = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// 기본 프레이밍(센터 크롭)으로 리셋 — 더블탭/초기화 버튼 공용.
    private func resetToCenterCrop() {
        raw = nil
        atEdge = false
        isAdjusting = false
        // 시각 변화는 committed(EditSession) 갱신에서 오므로 세션 뮤테이션까지
        // withAnimation 안에 둬야 스프링 스냅백이 실제로 애니메이션된다.
        withAnimation(Self.snapBack) {
            working = nil
            session.resetTransform(for: store.clipID)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func handleGestureChange(_ scaleFactor: CGFloat, _ translation: CGSize, viewBox: CGSize) {
        // 원시 값 누적(러버밴드는 표시 단계에서만) — 감쇠 값에 다시 감쇠가 쌓이는 이중 적용 방지.
        var base = raw ?? committed
        base.scale *= scaleFactor
        base.offset.x += viewBox.width > 0 ? translation.width / viewBox.width : 0
        base.offset.y += viewBox.height > 0 ? translation.height / viewBox.height : 0
        raw = base
        isAdjusting = true

        // 표시 scale: [1, 4] 초과분 러버밴드.
        let displayScale = RubberBand.value(
            proposed: base.scale, min: ClipTransform.minScale, max: ClipTransform.maxScale
        )
        // offset 한계는 커밋될 scale(clamp 값) 기준 — 스냅백 후 좌표계와 일치시킨다.
        let commitScale = min(max(base.scale, ClipTransform.minScale), ClipTransform.maxScale)
        let limit = ClipFraming.maxOffsetFraction(
            display: displaySize, rotation: rotation, render: Self.render, scale: commitScale
        )
        let displayOffset = CGPoint(
            x: RubberBand.value(proposed: base.offset.x, min: -limit.x, max: limit.x),
            y: RubberBand.value(proposed: base.offset.y, min: -limit.y, max: limit.y)
        )
        working = ClipTransform(scale: displayScale, offset: displayOffset)

        // 한계 도달 순간 1회 햅틱(상태-diff) — 경계에 붙어 있는 동안 반복 발화 금지.
        let hitEdge = abs(base.offset.x) > limit.x + 0.0001
            || abs(base.offset.y) > limit.y + 0.0001
            || base.scale > ClipTransform.maxScale
            || base.scale < ClipTransform.minScale
        if hitEdge && !atEdge {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
        atEdge = hitEdge
    }

    private func commitWorking() {
        guard let base = raw else { return }
        let commitScale = min(max(base.scale, ClipTransform.minScale), ClipTransform.maxScale)
        let clampedOffset = ClipFraming.clampedOffset(
            base.offset, display: displaySize, rotation: rotation, render: Self.render, scale: commitScale
        )
        let final = ClipTransform(scale: commitScale, offset: clampedOffset)
        // 오버슛 → 한계값으로 스프링 스냅백(오버슛 없는 파라미터).
        withAnimation(Self.snapBack) { working = final }
        session.setTransform(final, for: store.clipID)
        raw = nil
        atEdge = false
        isAdjusting = false
    }
}
