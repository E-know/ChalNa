import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem

/// 영상 프리뷰 패널.
///
/// **고정 높이를 갖지 않는다** — 부모(TimelineView)가 준 공간을 채우고
/// `ChalNaCanvas` 가 9:16 으로 aspect-fit 한다. 이것이 SE 세로 예산의 핵심이다.
/// (기존에는 `previewHeight = 300` 고정이라 SE 에서 세로가 넘쳤다)
struct PreviewPanel: View {
    private static let render = CGSize(width: 1080, height: 1920)

    @Environment(EditSession.self) private var session

    let store: StoreOf<TimelineFeature>
    let playback: ClipPlaybackController

    private var currentRotation: ClipRotation {
        guard let id = store.currentClip?.id else { return .r0 }
        return session.rotation(for: id)
    }

    private var currentLabel: ClipLabel {
        guard let id = store.currentClip?.id else { return .default }
        return session.label(for: id)
    }

    var body: some View {
        VStack(spacing: 8) {
            ChalNaCanvas { box in
                clipContent(box: box)
            } overlay: { box in
                ZStack {
                    autoLabelsOverlay(box: box)
                    labelOverlay(box: box)
                    clipIndexBadge
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            scrubBar
        }
    }

    // MARK: - Clip content

    @ViewBuilder
    private func clipContent(box: CGSize) -> some View {
        if let clip = store.currentClip {
            let transform = session.transform(for: clip.id)
            let rrect = ClipFraming.resolvedRect(
                display: clip.displaySize ?? CGSize(width: 9, height: 16),
                rotation: currentRotation,
                render: Self.render,
                transform: transform
            )
            let factor = box.width / Self.render.width

            RotatableContent(rotation: currentRotation) {
                if clip.videoURL != nil && playback.hasVideo {
                    PlayerLayerView(player: playback.player)
                } else {
                    clip.thumbnailView(contentMode: .fill)
                }
            }
            .frame(width: rrect.width * factor, height: rrect.height * factor)
            .position(x: rrect.midX * factor, y: rrect.midY * factor)
        }
    }

    // MARK: - Overlays

    /// 자동 시간/날짜 라벨을 출력과 동일하게 표시(읽기 전용).
    /// 센터 크롭에서는 보이는 클립 영역 = 캔버스 전체 → 캔버스 박스를 renderSize 로 간주.
    @ViewBuilder
    private func autoLabelsOverlay(box: CGSize) -> some View {
        if let clip = store.currentClip {
            AutoLabelsOverlay(box: box, capturedAt: clip.capturedAt)
                .frame(width: box.width, height: box.height)
                .allowsHitTesting(false)
        }
    }

    /// 현재 클립 라벨을 에디터와 동일한 정규화 좌표·렌더러로 표시(WYSIWYG).
    @ViewBuilder
    private func labelOverlay(box: CGSize) -> some View {
        let label = currentLabel
        if store.currentClip != nil, label.isVisible {
            ClipLabelText(label: label, fontPx: label.clampedSizeFraction * box.height)
                .position(x: label.position.x * box.width,
                          y: label.position.y * box.height)
                .frame(width: box.width, height: box.height)
                .allowsHitTesting(false)
        }
    }

    /// 영상 위에는 정보용 인덱스만 둔다. 재생 제어는 아래 TransportControls 담당.
    private var clipIndexBadge: some View {
        ChalNaTag("\(store.currentIndex + 1) / \(store.clips.count)", variant: .neutral)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(10)
            .allowsHitTesting(false)
    }

    // MARK: - Scrub bar

    private var scrubBar: some View {
        HStack(spacing: 8) {
            Text(verbatim: store.isPlaying ? store.playheadLabel : "00:00")
                .font(ChalNaTypography.caption)
                .monospacedDigit()
                .foregroundColor(ChalNaColor.textPrimary)

            ChalNaProgressBar(progress: scrubProgress, height: 3)

            Text(verbatim: store.totalClockLabel)
                .font(ChalNaTypography.caption)
                .monospacedDigit()
                .foregroundColor(ChalNaColor.textSecondary)
        }
        .frame(height: 20)
    }

    private var scrubProgress: Double {
        guard store.isPlaying else { return 0 }
        return min(1.0, max(0.0, store.playheadSeconds / max(store.totalDuration, 0.001)))
    }
}
