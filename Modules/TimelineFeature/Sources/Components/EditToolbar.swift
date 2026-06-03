import SwiftUI
import DesignSystem

/// Idle 상태의 하단 2-버튼 툴바 (조정 · 삭제).
/// 클립 순서 변경은 FilmStrip에서 long-press → drag&drop으로 직접 수행한다.
struct EditToolbar: View {
    var dimmed: Bool = false
    /// 현재 클립에 조정(회전/줌/이동)이 적용돼 있으면 아이콘 우상단 coral dot.
    var adjustActive: Bool = false
    /// 현재 클립에 라벨이 있을 때 라벨 아이콘 우상단 coral dot.
    var labelActive: Bool = false
    var canSave: Bool = true
    var onAdjust: () -> Void = {}
    var onLabel: () -> Void = {}
    var onDelete: () -> Void = {}
    var onSave: () -> Void = {}

    @ViewBuilder
    var body: some View {
        paperToolbar
    }

    private var paperToolbar: some View {
        HStack(spacing: 0) {
            item(icon: .move, label: "조정", action: onAdjust, dotIndicator: adjustActive)
            item(icon: .textLabel, label: "라벨", action: onLabel, dotIndicator: labelActive)
            item(icon: .trash, label: "삭제", action: onDelete, tone: .destructive)
            item(icon: .check, label: "저장", action: onSave, disabled: !canSave)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: ChalNaRadius.sheet, style: .continuous)
                .fill(dimmed ? Color.white.opacity(0.7) : .white)
                .chalNaShadow(ChalNaShadow.md)
        )
        .overlay(
            dimmed
                ? RoundedRectangle(cornerRadius: ChalNaRadius.sheet, style: .continuous).fill(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.sheet, style: .continuous))
                : nil
        )
        .opacity(dimmed ? 0.85 : 1)
        .allowsHitTesting(!dimmed)
        .accessibilityHidden(dimmed)
    }

    private func item(
        icon: ChalNaIconKind,
        label: LocalizedStringKey,
        action: @escaping () -> Void,
        dotIndicator: Bool = false,
        tone: ToolbarItemTone = .normal,
        disabled: Bool = false
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    ChalNaIcon(icon, size: 20)
                        .foregroundColor(tone.foregroundColor)
                    if dotIndicator {
                        Circle()
                            .fill(ChalNaColor.coral)
                            .frame(width: 6, height: 6)
                            .offset(x: 4, y: -2)
                    }
                }
                if !dimmed {
                    Text(label)
                        .font(ChalNaTypography.krBody(ChalNaTypography.Size.caption, weight: .medium))
                        .foregroundColor(tone.foregroundColor)
                }
            }
            .opacity(dimmed ? 0.45 : (disabled ? 0.4 : 1))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .chalNaHitTarget()
        .disabled(dimmed || disabled)
        .accessibilityLabel(label)
        .accessibilityHint(tone.accessibilityHint)
    }

}

private enum ToolbarItemTone {
    case normal
    case destructive

    var foregroundColor: Color {
        switch self {
        case .normal:      return ChalNaColor.ink
        case .destructive: return ChalNaColor.coral
        }
    }

    var accessibilityHint: LocalizedStringKey {
        switch self {
        case .normal:      return ""
        case .destructive: return "선택한 클립을 삭제합니다."
        }
    }
}
