import SwiftUI

/// Idle 상태의 하단 4-버튼 툴바 (자르기 · 순서 · 삭제 · 음악).
struct EditToolbar: View {
    var dimmed: Bool = false
    var onTrim: () -> Void = {}
    var onReorder: () -> Void = {}
    var onDelete: () -> Void = {}
    var onMusic: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            item(icon: .scissors, label: "자르기", action: onTrim)
            item(icon: .reorderLines, label: "순서", action: onReorder)
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

    private func item(icon: MomentsIconKind, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                MomentsIcon(icon, size: 20)
                    .foregroundColor(MomentsColor.ink)
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
