import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem

/// 고정 크기 영상 프리뷰 패널. Idle(큰 플레이 + 외부 스크럽바) · Playing(큰 일시정지 + 외부 스크럽바).
struct PreviewPanel: View {
    private static let previewHeight: CGFloat = 300
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
            previewCard
            externalScrubBar
                .padding(.horizontal, 12)
        }
    }

    private var previewCard: some View {
        GeometryReader { proxy in
            let box = LabelBoxGeometry.fittedBox(aspect: 9.0 / 16.0, in: proxy.size)
            clipCanvas(box: box)
                .overlay(autoLabelsOverlay)
                .overlay(labelOverlay)
                .frame(width: box.width, height: box.height)
                .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous))
                .overlay(hudOverlay)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(height: Self.previewHeight)
        .chalNaShadow(ChalNaShadow.md)
    }

    @ViewBuilder
    private func clipCanvas(box: CGSize) -> some View {
        ZStack {
            if let clip = store.currentClip {
                clip.thumbnailView(contentMode: .fill)
                    .frame(width: box.width, height: box.height)
                    .clipped()
                    .blur(radius: 14)
                    .overlay(Color.black.opacity(0.18))

                let t = session.transform(for: clip.id)
                let rrect = ClipFraming.resolvedRect(display: clip.displaySize ?? CGSize(width: 9, height: 16),
                                                     rotation: currentRotation, render: Self.render, transform: t)
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
            } else {
                ChalNaColor.Gray.g50
            }
        }
        .frame(width: box.width, height: box.height)
        .clipped()
    }

    /// 자동 시간/날짜 라벨을 출력과 동일하게 미리보기에 표시(읽기 전용).
    @ViewBuilder
    private var autoLabelsOverlay: some View {
        if let clip = store.currentClip {
            GeometryReader { proxy in
                let aspect = LabelBoxGeometry.displayAspect(displaySize: clip.displaySize, rotation: currentRotation)
                let box = LabelBoxGeometry.fittedBox(aspect: aspect, in: proxy.size)
                AutoLabelsOverlay(box: box, capturedAt: clip.capturedAt)
                    .frame(width: box.width, height: box.height)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .allowsHitTesting(false)
        }
    }

    /// 현재 클립에 설정된 라벨을 미리보기 위에 표시(읽기 전용). 에디터와 동일한
    /// 정규화 좌표(클립 표시 박스 기준)·동일 렌더러(ClipLabelText)로 WYSIWYG 일치.
    @ViewBuilder
    private var labelOverlay: some View {
        let label = currentLabel
        if store.currentClip != nil, label.isVisible {
            GeometryReader { proxy in
                let aspect = LabelBoxGeometry.displayAspect(displaySize: store.currentClip?.displaySize, rotation: currentRotation)
                let box = LabelBoxGeometry.fittedBox(aspect: aspect, in: proxy.size)
                let fontPx = label.clampedSizeFraction * box.height
                ClipLabelText(label: label, fontPx: fontPx)
                    .position(
                        x: (proxy.size.width - box.width) / 2 + label.position.x * box.width,
                        y: (proxy.size.height - box.height) / 2 + label.position.y * box.height
                    )
            }
            .allowsHitTesting(false)
        }
    }

    // 영상 위에는 정보용 인덱스(n / N)만 둔다. 재생/정지/이전/다음 제어는 영상 아래 TransportControls 담당.
    @ViewBuilder
    private var hudOverlay: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 16) { topRightClipIndex }
        } else {
            topRightClipIndex
        }
    }

    @ViewBuilder
    private var topRightClipIndex: some View {
        if #available(iOS 26.0, *) {
            Text(topRightIndexAttributed(foreground: ChalNaColor.Gray.g900, tail: ChalNaColor.Gray.g500))
                .font(ChalNaTypography.monoFallback(10, weight: .semibold))
                .foregroundColor(ChalNaColor.Gray.g900)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .glassEffect(
                    .regular.tint(ChalNaColor.Gray.g50.opacity(0.32)),
                    in: Capsule(style: .continuous)
                )
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        } else {
            Text(topRightIndexAttributed(foreground: .white, tail: .white.opacity(0.6)))
                .font(ChalNaTypography.monoFallback(10, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }

    private func topRightIndexAttributed(foreground: Color, tail tailColor: Color) -> AttributedString {
        var s = AttributedString("\(store.currentIndex + 1) ")
        s.foregroundColor = foreground
        var tail = AttributedString("/ \(store.clips.count)")
        tail.foregroundColor = tailColor
        s.append(tail)
        return s
    }

    @ViewBuilder
    private var externalScrubBar: some View {
        ScrubBar(
            currentLabel: scrubCurrentLabel,
            totalLabel: store.totalClockLabel,
            progress: scrubProgress,
            style: .liquidGlass
        )
    }

    private var scrubCurrentLabel: String {
        store.isPlaying ? store.playheadLabel : "00:00"
    }

    private var scrubProgress: Double {
        guard store.isPlaying else { return 0 }
        return min(1.0, max(0.0, store.playheadSeconds / max(store.totalDuration, 0.001)))
    }
}

private enum ScrubBarStyle {
    case paper
    case liquidGlass
}

private struct ScrubBar: View {
    let currentLabel: String
    let totalLabel: String
    let progress: Double
    var style: ScrubBarStyle = .paper

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *), style == .liquidGlass {
            liquidGlassBody
        } else {
            paperBody
        }
    }

    private var paperBody: some View {
        scrubContent(
            textColor: ChalNaColor.Gray.g900,
            secondaryTextColor: ChalNaColor.Gray.g500,
            trackColor: ChalNaColor.Gray.g900.opacity(0.16),
            knobColor: ChalNaColor.Gray.g50
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: ChalNaRadius.button, style: .continuous)
                .fill(ChalNaColor.Gray.g50.opacity(0.92))
                .chalNaShadow(ChalNaShadow.sm)
        )
    }

    @available(iOS 26.0, *)
    private var liquidGlassBody: some View {
        scrubContent(
            textColor: ChalNaColor.Gray.g900,
            secondaryTextColor: ChalNaColor.Gray.g500,
            trackColor: ChalNaColor.Gray.g900.opacity(0.18),
            knobColor: ChalNaColor.Gray.g50
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(
            .regular.tint(ChalNaColor.Gray.g50.opacity(0.3)),
            in: RoundedRectangle(cornerRadius: ChalNaRadius.button, style: .continuous)
        )
    }

    private func scrubContent(
        textColor: Color,
        secondaryTextColor: Color,
        trackColor: Color,
        knobColor: Color
    ) -> some View {
        HStack(spacing: 8) {
            Text(currentLabel)
                .font(ChalNaTypography.monoFallback(11, weight: .semibold))
                .foregroundColor(textColor)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(trackColor)
                        .frame(height: 3)
                    Capsule()
                        .fill(ChalNaColor.Purple.p600)
                        .frame(width: max(0, proxy.size.width * progress), height: 3)
                    Circle()
                        .fill(knobColor)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(ChalNaColor.Purple.p600, lineWidth: 2))
                        .overlay(Circle().stroke(ChalNaColor.Purple.p600.opacity(0.3), lineWidth: 3).padding(-2))
                        .offset(x: max(0, proxy.size.width * progress) - 6)
                }
                .frame(height: 12)
            }
            .frame(height: 12)

            Text(totalLabel)
                .font(ChalNaTypography.monoFallback(11, weight: .semibold))
                .foregroundColor(secondaryTextColor)
        }
    }
}
