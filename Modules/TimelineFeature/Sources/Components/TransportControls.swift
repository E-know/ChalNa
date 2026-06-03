import SwiftUI
import DesignSystem

/// Playing 상태의 3-버튼 전송 컨트롤 (이전 · 재생/일시정지 · 다음).
struct TransportControls: View {
    let isPlaying: Bool
    let onPrev: () -> Void
    let onToggle: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            sideButton(icon: .skipBack, label: "이전 클립", action: onPrev)
            centerButton
            sideButton(icon: .skipForward, label: "다음 클립", action: onNext)
        }
    }

    private func sideButton(icon: ChalNaIconKind, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(ChalNaColor.ivory).frame(width: 36, height: 36)
                ChalNaIcon(icon, size: 13).foregroundColor(ChalNaColor.ink)
            }
        }
        .buttonStyle(.plain)
        .chalNaHitTarget()
        .accessibilityLabel(label)
    }

    private var centerButton: some View {
        Button(action: onToggle) {
            ZStack {
                Circle().fill(ChalNaColor.coral).frame(width: 48, height: 48)
                ChalNaIcon(isPlaying ? .pause : .play, size: 16)
                    .foregroundColor(ChalNaColor.ink)
                    .offset(x: isPlaying ? 0 : 2)
            }
            .shadow(color: ChalNaColor.coral.opacity(0.6), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .chalNaHitTarget(minSize: 48)
        .accessibilityLabel(isPlaying ? LocalizedStringKey("일시정지") : LocalizedStringKey("재생"))
        .accessibilityHint("현재 클립 재생 상태를 전환합니다.")
    }
}
