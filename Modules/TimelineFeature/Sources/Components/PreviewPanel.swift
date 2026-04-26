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
                .overlay(topRightClipIndex)
                .overlay(playPauseButton)
                .overlay(bottomControls, alignment: .bottom)
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

    // MARK: - Top-right "1 / 12"

    @ViewBuilder
    private var topRightClipIndex: some View {
        Group {
            Text(topRightIndexAttributed)
                .font(MomentsTypography.monoFallback(10, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .padding(MomentsSpacing.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }

    private var topRightIndexAttributed: AttributedString {
        var s = AttributedString("\(model.currentIndex + 1) ")
        var tail = AttributedString("/ \(model.clips.count)")
        tail.foregroundColor = .white.opacity(0.6)
        s.append(tail)
        return s
    }

    // MARK: - Center play/pause

    @ViewBuilder
    private var playPauseButton: some View {
        Button(action: onTogglePlay) {
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
        .buttonStyle(.plain)
    }

    // MARK: - Bottom controls

    @ViewBuilder
    private var bottomControls: some View {
        if model.isPlaying {
            ScrubBar(
                currentLabel: model.playheadLabel,
                totalLabel: model.totalClockLabel,
                progress: min(1.0, max(0.0, model.playheadSeconds / max(model.totalDuration, 0.001)))
            )
            .padding(.horizontal, MomentsSpacing.sm)
            .padding(.bottom, 10)
        } else {
            Text(timecodeIdleAttributed)
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

    private var timecodeIdleAttributed: AttributedString {
        var s = AttributedString("00:00 ")
        var tail = AttributedString("/ \(model.totalClockLabel)")
        tail.foregroundColor = .white.opacity(0.65)
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

private struct ScrubBar: View {
    let currentLabel: String
    let totalLabel: String
    let progress: Double

    var body: some View {
        HStack(spacing: MomentsSpacing.xs) {
            Text(currentLabel)
                .font(MomentsTypography.monoFallback(11, weight: .semibold))
                .foregroundColor(.white)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 3)
                    Capsule()
                        .fill(MomentsColor.coral)
                        .frame(width: max(0, proxy.size.width * progress), height: 3)
                    Circle()
                        .fill(Color.white)
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
                .foregroundColor(.white.opacity(0.7))
        }
    }
}
