import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem

/// 고정 크기 영상 프리뷰 패널. Idle(큰 플레이 + 외부 스크럽바) · Playing(큰 일시정지 + 외부 스크럽바).
struct PreviewPanel: View {
    private static let previewHeight: CGFloat = 224

    @Environment(EditSession.self) private var session

    let store: StoreOf<TimelineFeature>
    let playback: ClipPlaybackController
    let onTogglePlay: () -> Void

    private var currentRotation: ClipRotation {
        guard let id = store.currentClip?.id else { return .r0 }
        return session.rotation(for: id)
    }

    var body: some View {
        VStack(spacing: MomentsSpacing.xs) {
            previewCard
            externalScrubBar
                .padding(.horizontal, MomentsSpacing.sm)
        }
    }

    private var previewCard: some View {
        ZStack {
            MomentsColor.ink
            thumbnail.overlay(hudOverlay)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.previewHeight)
        .clipShape(RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous))
        .momentsShadow(MomentsShadow.md)
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            if let clip = store.currentClip {
                RotatableContent(rotation: currentRotation) {
                    if clip.videoURL != nil && playback.hasVideo {
                        PlayerLayerView(player: playback.player)
                    } else {
                        clip.thumbnailView(contentMode: .fit)
                    }
                }
            } else {
                MomentsColor.ivory
            }
        }
    }

    @ViewBuilder
    private var hudOverlay: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: MomentsSpacing.md) { hudStack }
        } else {
            hudStack
        }
    }

    private var hudStack: some View {
        ZStack {
            topRightClipIndex
            playPauseButton
        }
    }

    @ViewBuilder
    private var topRightClipIndex: some View {
        if #available(iOS 26.0, *) {
            Text(topRightIndexAttributed(foreground: MomentsColor.ink, tail: MomentsColor.taupe))
                .font(MomentsTypography.monoFallback(10, weight: .semibold))
                .foregroundColor(MomentsColor.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .glassEffect(
                    .regular.tint(MomentsColor.ivory.opacity(0.32)),
                    in: Capsule(style: .continuous)
                )
                .padding(MomentsSpacing.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        } else {
            Text(topRightIndexAttributed(foreground: .white, tail: .white.opacity(0.6)))
                .font(MomentsTypography.monoFallback(10, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .padding(MomentsSpacing.sm)
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
    private var playPauseButton: some View {
        Button(action: onTogglePlay) {
            playPauseButtonLabel
        }
        .buttonStyle(.plain)
        .momentsHitTarget(minSize: 64)
        .accessibilityLabel(store.isPlaying ? "일시정지" : "재생")
    }

    @ViewBuilder
    private var playPauseButtonLabel: some View {
        if #available(iOS 26.0, *) {
            MomentsIcon(store.isPlaying ? .pause : .play, size: 22)
                .foregroundColor(MomentsColor.ink)
                .offset(x: store.isPlaying ? 0 : 2)
                .frame(width: 64, height: 64)
                .glassEffect(
                    .regular.tint(MomentsColor.ivory.opacity(0.34)).interactive(),
                    in: Circle()
                )
        } else {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.94))
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.3), radius: 14, y: 10)
                MomentsIcon(store.isPlaying ? .pause : .play, size: 22)
                    .foregroundColor(MomentsColor.ink)
                    .offset(x: store.isPlaying ? 0 : 2)
            }
        }
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
            textColor: MomentsColor.ink,
            secondaryTextColor: MomentsColor.taupe,
            trackColor: MomentsColor.ink.opacity(0.16),
            knobColor: MomentsColor.ivory
        )
        .padding(.horizontal, MomentsSpacing.sm)
        .padding(.vertical, MomentsSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: MomentsRadius.button, style: .continuous)
                .fill(MomentsColor.ivory.opacity(0.92))
                .momentsShadow(MomentsShadow.sm)
        )
    }

    @available(iOS 26.0, *)
    private var liquidGlassBody: some View {
        scrubContent(
            textColor: MomentsColor.ink,
            secondaryTextColor: MomentsColor.taupe,
            trackColor: MomentsColor.ink.opacity(0.18),
            knobColor: MomentsColor.ivory
        )
        .padding(.horizontal, MomentsSpacing.sm)
        .padding(.vertical, MomentsSpacing.xs)
        .glassEffect(
            .regular.tint(MomentsColor.ivory.opacity(0.3)),
            in: RoundedRectangle(cornerRadius: MomentsRadius.button, style: .continuous)
        )
    }

    private func scrubContent(
        textColor: Color,
        secondaryTextColor: Color,
        trackColor: Color,
        knobColor: Color
    ) -> some View {
        HStack(spacing: MomentsSpacing.xs) {
            Text(currentLabel)
                .font(MomentsTypography.monoFallback(11, weight: .semibold))
                .foregroundColor(textColor)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(trackColor)
                        .frame(height: 3)
                    Capsule()
                        .fill(MomentsColor.coral)
                        .frame(width: max(0, proxy.size.width * progress), height: 3)
                    Circle()
                        .fill(knobColor)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(MomentsColor.coral, lineWidth: 2))
                        .overlay(Circle().stroke(MomentsColor.coral.opacity(0.3), lineWidth: 3).padding(-2))
                        .offset(x: max(0, proxy.size.width * progress) - 6)
                }
                .frame(height: 12)
            }
            .frame(height: 12)

            Text(totalLabel)
                .font(MomentsTypography.monoFallback(11, weight: .semibold))
                .foregroundColor(secondaryTextColor)
        }
    }
}
