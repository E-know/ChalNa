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
/// - 확대·축소·이동에 **제약이 없다.** 캔버스보다 작게 줄이거나 캔버스 밖으로 밀어낼 수 있고,
///   드러나는 여백은 검정(`ChalNaColor.canvas`)이다 — export 도 동일(컴포지터의 검정 베이스).
///   따라서 러버밴드 저항·스프링 스냅백·한계 도달 햅틱은 없다(저항할 경계가 없다).
///   배율은 `ClipTransform.sanitized` 의 산술 안전 가드([0.1, 10])만 통과한다.
/// - 드래그/핀치 중에만 3분할 그리드 표시(Apple Photos 패턴).
/// - 더블탭 = 기본 프레이밍(센터 크롭) 리셋. 스프링 애니메이션은 이 리셋에만 남는다.
public struct ClipAdjustView: View {
    @Environment(EditSession.self) private var session

    let store: StoreOf<ClipAdjustFeature>
    @State private var playback = ClipPlaybackController()
    /// 제스처 중 누적되는 표시 변환(안전 가드만 적용). nil = 제스처 없음 → committed 그대로.
    @State private var live: ClipTransform? = nil
    /// 드래그/핀치 진행 중 여부 — 3분할 그리드 표시 조건.
    @State private var isAdjusting = false

    public init(store: StoreOf<ClipAdjustFeature>) {
        self.store = store
    }

    private static let render = CGSize(width: 1080, height: 1920)
    private static let snapBack: Animation = ChalNaMotion.spring

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
        ChalNaNavBar(
            title: "조정",
            leading: .back { store.send(.backTapped) },
            trailing: .text("완료") { store.send(.doneTapped) },
            showsDivider: true
        )
    }

    private var canvas: some View {
        ChalNaCanvas { box in
            let factor = box.width / Self.render.width
            let rrect = ClipFraming.resolvedRect(
                display: displaySize, rotation: rotation,
                render: Self.render, transform: live ?? committed
            )

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
                onEnded: { commitLive() }
            )
            .frame(width: box.width, height: box.height)
            .onTapGesture(count: 2) { resetToCenterCrop() }
        }
        .padding(.horizontal, 20)
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

    private var adjustHint: some View {
        Text("드래그로 옮기고 핀치로 크기를 바꿔요. 더블탭 = 초기화")
            .font(ChalNaTypography.caption)
            .foregroundColor(ChalNaColor.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
    }

    private func rotate() {
        session.cycleRotation(for: store.clipID)
        // 진행 중이던 제스처 상태는 옛 회전 좌표계 값이므로 무효화.
        // (offset 재클램프는 없다 — 이동 한계 자체가 사라졌으므로 "스테일 offset" 개념이 없다.)
        live = nil
        isAdjusting = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// 기본 프레이밍(센터 크롭)으로 리셋 — 더블탭/초기화 버튼 공용.
    private func resetToCenterCrop() {
        isAdjusting = false
        // 시각 변화는 committed(EditSession) 갱신에서 오므로 세션 뮤테이션까지
        // withAnimation 안에 둬야 스프링이 실제로 애니메이션된다.
        withAnimation(Self.snapBack) {
            live = nil
            session.resetTransform(for: store.clipID)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func handleGestureChange(_ scaleFactor: CGFloat, _ translation: CGSize, viewBox: CGSize) {
        var base = live ?? committed
        base.scale *= scaleFactor
        base.offset.x += viewBox.width > 0 ? translation.width / viewBox.width : 0
        base.offset.y += viewBox.height > 0 ? translation.height / viewBox.height : 0
        // 제약이 없으니 표시값 = 원시값. 산술 안전 가드만 통과시킨다(idempotent).
        live = base.sanitized
        isAdjusting = true
    }

    private func commitLive() {
        guard let final = live else { return }
        session.setTransform(final, for: store.clipID)
        live = nil
        isAdjusting = false
    }
}
