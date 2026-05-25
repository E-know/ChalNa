import SwiftUI
import DesignSystem

/// Playing 상태의 3-버튼 전송 컨트롤 (이전 · 재생/일시정지 · 다음).
struct TransportControls: View {
    let isPlaying: Bool
    let onPrev: () -> Void
    let onToggle: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            sideButton(icon: .skipBack, label: "이전 클립", action: onPrev)
            centerButton
            sideButton(icon: .skipForward, label: "다음 클립", action: onNext)
        }
    }

    private func sideButton(icon: MomentsIconKind, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(MomentsColor.ivory).frame(width: 40, height: 40)
                MomentsIcon(icon, size: 14).foregroundColor(MomentsColor.ink)
            }
        }
        .buttonStyle(.plain)
        .momentsHitTarget()
        .accessibilityLabel(label)
    }

    private var centerButton: some View {
        Button(action: onToggle) {
            ZStack {
                Circle().fill(MomentsColor.coral).frame(width: 56, height: 56)
                MomentsIcon(isPlaying ? .pause : .play, size: 18)
                    .foregroundColor(MomentsColor.ink)
                    .offset(x: isPlaying ? 0 : 2)
            }
            .shadow(color: MomentsColor.coral.opacity(0.6), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .momentsHitTarget(minSize: 56)
        .accessibilityLabel(isPlaying ? "일시정지" : "재생")
        .accessibilityHint("현재 클립 재생 상태를 전환합니다.")
    }
}
