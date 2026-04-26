import SwiftUI

/// Idle 상태의 하단 4-버튼 툴바 (회전 · 자르기 · 삭제 · 음악).
/// 클립 순서 변경은 FilmStrip에서 long-press → drag&drop으로 직접 수행한다.
struct EditToolbar: View {
    var dimmed: Bool = false
    /// 현재 클립이 r0이 아닐 때 회전 아이콘 우상단에 coral dot으로 "회전 적용 중" 표시.
    var rotationActive: Bool = false
    var onRotate: () -> Void = {}
    var onTrim: () -> Void = {}
    var onDelete: () -> Void = {}
    var onMusic: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            item(icon: .rotate, label: "회전", action: onRotate, dotIndicator: rotationActive)
            item(icon: .scissors, label: "자르기", action: onTrim)
            item(icon: .trash, label: "삭제", action: onDelete)
            item(icon: .music, label: "음악", action: onMusic)
        }
        .padding(.vertical, MomentsSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(dimmed ? Color.white.opacity(0.7) : .white)
                .momentsShadow(MomentsShadow.md)
        )
        .overlay(
            dimmed
                ? RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                : nil
        )
        .opacity(dimmed ? 0.85 : 1)
    }

    private func item(
        icon: MomentsIconKind,
        label: String,
        action: @escaping () -> Void,
        dotIndicator: Bool = false
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    MomentsIcon(icon, size: 20)
                        .foregroundColor(MomentsColor.ink)
                    if dotIndicator {
                        Circle()
                            .fill(MomentsColor.coral)
                            .frame(width: 6, height: 6)
                            .offset(x: 4, y: -2)
                    }
                }
                if !dimmed {
                    Text(label)
                        .font(MomentsTypography.krBody(10, weight: .medium))
                        .foregroundColor(MomentsColor.ink)
                }
            }
            .opacity(dimmed ? 0.45 : 1)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
