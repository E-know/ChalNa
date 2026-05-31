import SwiftUI
import DesignSystem

/// Idle 상태의 하단 2-버튼 툴바 (회전 · 삭제).
/// 클립 순서 변경은 FilmStrip에서 long-press → drag&drop으로 직접 수행한다.
struct EditToolbar: View {
    var dimmed: Bool = false
    /// 현재 클립이 r0이 아닐 때 회전 아이콘 우상단에 coral dot으로 "회전 적용 중" 표시.
    var rotationActive: Bool = false
    /// 현재 클립에 라벨이 있을 때 라벨 아이콘 우상단 coral dot.
    var labelActive: Bool = false
    var canSave: Bool = true
    var onRotate: () -> Void = {}
    var onLabel: () -> Void = {}
    var onDelete: () -> Void = {}
    var onSave: () -> Void = {}

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            liquidGlassToolbar
        } else {
            paperToolbar
        }
    }

    private var paperToolbar: some View {
        HStack(spacing: 0) {
            item(icon: .rotate, label: "회전", action: onRotate, dotIndicator: rotationActive)
            item(icon: .textLabel, label: "라벨", action: onLabel, dotIndicator: labelActive)
            item(icon: .trash, label: "삭제", action: onDelete, tone: .destructive)
            item(icon: .check, label: "저장", action: onSave, disabled: !canSave)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(dimmed ? Color.white.opacity(0.7) : .white)
                .chalNaShadow(ChalNaShadow.md)
        )
        .overlay(
            dimmed
                ? RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                : nil
        )
        .opacity(dimmed ? 0.85 : 1)
        .allowsHitTesting(!dimmed)
        .accessibilityHidden(dimmed)
    }

    @available(iOS 26.0, *)
    private var liquidGlassToolbar: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                glassItem(icon: .rotate, label: "회전", action: onRotate, dotIndicator: rotationActive)
                glassItem(icon: .textLabel, label: "라벨", action: onLabel, dotIndicator: labelActive)
                glassItem(icon: .trash, label: "삭제", action: onDelete, tone: .destructive)
                glassItem(icon: .check, label: "저장", action: onSave, disabled: !canSave)
            }
            .padding(.vertical, 4)
        }
        .opacity(dimmed ? 0.82 : 1)
        .allowsHitTesting(!dimmed)
        .accessibilityHidden(dimmed)
    }

    private func item(
        icon: ChalNaIconKind,
        label: String,
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
                        .font(ChalNaTypography.krBody(10, weight: .medium))
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

    @available(iOS 26.0, *)
    private func glassItem(
        icon: ChalNaIconKind,
        label: String,
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
                        .font(ChalNaTypography.krBody(10, weight: .medium))
                        .foregroundColor(tone.foregroundColor)
                }
            }
            .opacity(dimmed ? 0.45 : (disabled ? 0.4 : 1))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
        }
        .buttonStyle(.glass)
        .frame(maxWidth: .infinity)
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

    var accessibilityHint: String {
        switch self {
        case .normal:      return ""
        case .destructive: return "선택한 클립을 삭제합니다."
        }
    }
}
