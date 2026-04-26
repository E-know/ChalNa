import SwiftUI

/// Reordering 상태의 하단 2-버튼 바 (취소 · 여기로 이동).
struct ReorderConfirmBar: View {
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        HStack(spacing: MomentsSpacing.xs) {
            button(label: "취소", icon: .close, style: .secondary, action: onCancel)
            button(label: "여기로 이동", icon: .check, style: .primary, action: onConfirm)
        }
        .padding(MomentsSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .momentsShadow(MomentsShadow.md)
        )
    }

    private enum ButtonStyleKind { case primary, secondary }

    private func button(label: String, icon: MomentsIconKind, style: ButtonStyleKind, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                MomentsIcon(icon, size: 14)
                Text(label)
                    .font(MomentsTypography.krSemibold(14))
            }
            .foregroundColor(style == .primary ? .white : MomentsColor.taupe)
            .frame(maxWidth: .infinity)
            .padding(.vertical, MomentsSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: MomentsRadius.button, style: .continuous)
                    .fill(style == .primary ? MomentsColor.coral : MomentsColor.ivory)
            )
            .shadow(color: style == .primary ? MomentsColor.coral.opacity(0.6) : .clear, radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}
