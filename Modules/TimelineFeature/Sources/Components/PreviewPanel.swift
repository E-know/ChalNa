import SwiftUI
import AppCore
import Models
import DesignSystem

/// 고정 크기 영상 프리뷰 패널. Idle(큰 플레이) · Playing(큰 일시정지 + 스크럽바) · Reordering(디밍 + 배너).
/// 콘텐츠 비율과 무관하게 박스 크기는 항상 같고, 내부 사진/영상은 letterbox 로 fit.
struct PreviewPanel: View {
    /// Figma 노드 `39:81` 기준 고정 높이.
    private static let previewHeight: CGFloat = 224

    @Environment(EditSession.self) private var session

    let model: TimelineModel
    let playback: ClipPlaybackController
    let onTogglePlay: () -> Void

    private var currentRotation: ClipRotation {
        guard let id = model.currentClip?.id else { return .r0 }
        return session.rotation(for: id)
    }

    var body: some View {
        ZStack {
            // letterbox 베이스 — 가로/세로 비율이 다른 콘텐츠에서 띠 영역의 색.
            MomentsColor.ink
            thumbnail
                .overlay(hudOverlay)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.previewHeight)
        .clipShape(RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                .stroke(glowStrokeColor, lineWidth: glowStrokeWidth)
        )
        .shadow(color: glowColor, radius: 18, x: 0, y: 10)
        .momentsShadow(MomentsShadow.md)
    }

    // MARK: - Thumb

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            if let clip = model.currentClip {
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
            // Playing 상태에서 하단 코랄 글로우 워시
            if model.isPlaying {
                RadialGradient(
                    colors: [MomentsColor.coral.opacity(0.25), .clear],
                    center: UnitPoint(x: 0.5, y: 1.0),
                    startRadius: 0,
                    endRadius: 260
                )
            }
        }
    }

    @ViewBuilder
    private var hudOverlay: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: MomentsSpacing.md) {
                hudStack
            }
        } else {
            hudStack
        }
    }

    private var hudStack: some View {
        ZStack {
            topRightClipIndex
            playPauseButton
            bottomControls
        }
    }

    // MARK: - Top-right "1 / 12"

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
        var s = AttributedString("\(model.currentIndex + 1) ")
        s.foregroundColor = foreground
        var tail = AttributedString("/ \(model.clips.count)")
        tail.foregroundColor = tailColor
        s.append(tail)
        return s
    }

    // MARK: - Center play/pause

    @ViewBuilder
    private var playPauseButton: some View {
        Button(action: onTogglePlay) {
            playPauseButtonLabel
        }
        .buttonStyle(.plain)
        .momentsHitTarget(minSize: 64)
        .accessibilityLabel(model.isPlaying ? "일시정지" : "재생")
        .accessibilityHint("타임라인 미리보기 재생 상태를 전환합니다.")
    }

    @ViewBuilder
    private var playPauseButtonLabel: some View {
        if #available(iOS 26.0, *) {
            MomentsIcon(model.isPlaying ? .pause : .play, size: 22)
                .foregroundColor(MomentsColor.ink)
                .offset(x: model.isPlaying ? 0 : 2)
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
                MomentsIcon(model.isPlaying ? .pause : .play, size: 22)
                    .foregroundColor(MomentsColor.ink)
                    .offset(x: model.isPlaying ? 0 : 2)
            }
        }
    }

    // MARK: - Bottom controls

    @ViewBuilder
    private var bottomControls: some View {
        if model.isPlaying {
            ScrubBar(
                currentLabel: model.playheadLabel,
                totalLabel: model.totalClockLabel,
                progress: min(1.0, max(0.0, model.playheadSeconds / max(model.totalDuration, 0.001))),
                style: .liquidGlass
            )
            .padding(.horizontal, MomentsSpacing.sm)
            .padding(.bottom, 10)
        } else {
            idleTimecodePill
        }
    }

    @ViewBuilder
    private var idleTimecodePill: some View {
        if #available(iOS 26.0, *) {
            Text(timecodeIdleAttributed(foreground: MomentsColor.ink, tail: MomentsColor.taupe))
                .font(MomentsTypography.monoFallback(11, weight: .semibold))
                .foregroundColor(MomentsColor.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .glassEffect(
                    .regular.tint(MomentsColor.ivory.opacity(0.3)),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .padding(.horizontal, MomentsSpacing.sm)
                .padding(.bottom, MomentsSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(timecodeIdleAttributed(foreground: .white, tail: .white.opacity(0.65)))
                .font(MomentsTypography.monoFallback(11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.55)))
                .padding(.horizontal, MomentsSpacing.sm)
                .padding(.bottom, MomentsSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func timecodeIdleAttributed(foreground: Color, tail tailColor: Color) -> AttributedString {
        var s = AttributedString("00:00 ")
        s.foregroundColor = foreground
        var tail = AttributedString("/ \(model.totalClockLabel)")
        tail.foregroundColor = tailColor
        s.append(tail)
        return s
    }

    // MARK: - Glow (coral ring when playing)

    private var glowStrokeColor: Color {
        model.isPlaying ? MomentsColor.coral.opacity(0.35) : .clear
    }
    private var glowStrokeWidth: CGFloat {
        model.isPlaying ? 2 : 0
    }
    private var glowColor: Color {
        model.isPlaying ? MomentsColor.coral.opacity(0.35) : .clear
    }
}

// MARK: - Scrub bar (재생 중)

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
            textColor: .white,
            secondaryTextColor: .white.opacity(0.7),
            trackColor: .white.opacity(0.3),
            knobColor: .white
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
