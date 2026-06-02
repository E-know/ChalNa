import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem

/// 클립 1개를 9:16 캔버스 안에서 핀치 줌·드래그·회전으로 프레이밍하는 풀스크린 화면.
/// 배경=블러 필, 전경=ClipFraming.resolvedRect 로 배치 → export 와 픽셀 일치(WYSIWYG).
/// 편집은 EditSession 에 live 반영(회전 기존 동작과 동일, 별도 취소 없음).
public struct ClipAdjustView: View {
    @Environment(EditSession.self) private var session
    @Environment(AppRouter.self) private var router

    let store: StoreOf<ClipAdjustFeature>
    @State private var playback = ClipPlaybackController()
    @GestureState private var gestureScale: CGFloat = 1
    @GestureState private var gestureDrag: CGSize = .zero

    public init(store: StoreOf<ClipAdjustFeature>) {
        self.store = store
    }

    private static let render = CGSize(width: 1080, height: 1920)
    private static let minScale: CGFloat = 1.0
    private static let maxScale: CGFloat = 4.0

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
        HStack {
            Button { router.pop() } label: {
                HStack(spacing: 2) {
                    ChalNaIcon(.chevronLeft, size: 14)
                    Text("뒤로").font(ChalNaTypography.krBody(14, weight: .medium))
                }
                .foregroundColor(ChalNaColor.taupe)
            }
            .buttonStyle(.chalNaHeaderAction)
            Spacer()
            Text("조정").font(ChalNaTypography.krSemibold(15)).foregroundColor(ChalNaColor.ink)
            Spacer()
            Button {
                store.send(.doneTapped)
                router.pop()
            } label: {
                Text("완료").font(ChalNaTypography.krBody(14, weight: .semibold)).foregroundColor(ChalNaColor.coral)
            }
            .buttonStyle(.chalNaHeaderAction)
        }
        .padding(.horizontal, 16)
        .chalNaHeaderBar(scrollProgress: 1)
    }

    private var canvas: some View {
        GeometryReader { proxy in
            let box = LabelBoxGeometry.fittedBox(aspect: 9.0 / 16.0, in: proxy.size)
            let factor = box.width / Self.render.width
            let live = liveTransform(viewBox: box)
            let rrect = ClipFraming.resolvedRect(display: displaySize, rotation: rotation, render: Self.render, transform: live)

            ZStack {
                if let clip {
                    clip.thumbnailView(contentMode: .fill)
                        .frame(width: box.width, height: box.height)
                        .clipped()
                        .blur(radius: 18)
                        .overlay(Color.black.opacity(0.18))
                }
                RotatableContent(rotation: rotation) {
                    foreground
                }
                .frame(width: rrect.width * factor, height: rrect.height * factor)
                .position(x: rrect.midX * factor, y: rrect.midY * factor)
            }
            .frame(width: box.width, height: box.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous))
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture().updating($gestureScale) { v, s, _ in s = v },
                    DragGesture().updating($gestureDrag) { v, s, _ in s = v.translation }
                )
                .onEnded { value in
                    let magnify = value.first ?? 1
                    let drag = value.second?.translation ?? .zero
                    commitGesture(magnify: magnify, drag: drag, viewBox: box)
                }
            )
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .padding(.horizontal, 24)
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

    private var controls: some View {
        HStack(spacing: 12) {
            Button { rotate() } label: {
                HStack(spacing: 6) {
                    ChalNaIcon(.rotate, size: 16)
                    Text("회전")
                }
            }
            .buttonStyle(.chalNaOutlined)

            Button { reset() } label: {
                Text("맞춤으로 리셋")
            }
            .buttonStyle(.chalNaOutlined)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private func rotate() {
        session.cycleRotation(for: store.clipID)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func reset() {
        session.resetTransform(for: store.clipID)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func liveTransform(viewBox: CGSize) -> ClipTransform {
        let scale = min(max(committed.scale * gestureScale, Self.minScale), Self.maxScale)
        let fx = viewBox.width > 0 ? gestureDrag.width / viewBox.width : 0
        let fy = viewBox.height > 0 ? gestureDrag.height / viewBox.height : 0
        let offset = ClipFraming.clampedOffset(
            CGPoint(x: committed.offset.x + fx, y: committed.offset.y + fy),
            display: displaySize, rotation: rotation, render: Self.render, scale: scale
        )
        return ClipTransform(scale: scale, offset: offset)
    }

    private func commitGesture(magnify: CGFloat, drag: CGSize, viewBox: CGSize) {
        let scale = min(max(committed.scale * magnify, Self.minScale), Self.maxScale)
        let fx = viewBox.width > 0 ? drag.width / viewBox.width : 0
        let fy = viewBox.height > 0 ? drag.height / viewBox.height : 0
        let offset = ClipFraming.clampedOffset(
            CGPoint(x: committed.offset.x + fx, y: committed.offset.y + fy),
            display: displaySize, rotation: rotation, render: Self.render, scale: scale
        )
        session.setTransform(ClipTransform(scale: scale, offset: offset), for: store.clipID)
    }
}
