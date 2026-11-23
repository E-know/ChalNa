import SwiftUI
import DesignSystem

struct EditToolbar: View {
    let adjustActive: Bool
    let labelActive: Bool
    let onAdjust: () -> Void
    let onLabel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            item(.crop, "조정", "timeline.adjust", active: adjustActive, action: onAdjust)
            item(.textLabel, "자막", "timeline.caption", active: labelActive, action: onLabel)
            item(.trash, "삭제", "timeline.delete", action: onDelete)
        }
    }

    private func item(_ icon: ChalNaIconKind, _ label: LocalizedStringKey, _ identifier: String,
                      active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                ChalNaIcon(icon, size: 16)
                Text(label).lineLimit(1).minimumScaleFactor(0.78)
            }
            .font(ChalNaTypography.label)
            .foregroundStyle(active ? ChalNaColor.accent : ChalNaColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(ChalNaColor.surface, in: RoundedRectangle(cornerRadius: ChalNaRadius.xs))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
