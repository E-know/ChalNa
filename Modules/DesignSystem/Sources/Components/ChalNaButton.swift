import SwiftUI

/// 버튼 변형. 3종으로 줄이고 파괴적 여부를 **플래그로** 분리했다.
///
/// 이전에는 각 호출처가 "삭제는 무슨 색?"을 스스로 판단해서
/// EditToolbar 는 Primary 보라, FilmDetail 은 danger 레드를 썼다.
/// `destructive: true` 하나로 결정을 컴포넌트가 가져간다.
///
/// 근거: `docs/superpowers/specs/2026-07-28-app-redesign-design.md` §5.2
public enum ChalNaButtonVariant {
    /// 면형. accentFill 배경 + onAccent 라벨.
    case primary
    /// 선형. surface 배경 + border.
    case secondary
    /// 텍스트만.
    case ghost
}

public enum ChalNaButtonSize {
    case lg   // 52pt
    case md   // 44pt
    case sm   // 36pt

    fileprivate var height: CGFloat {
        switch self {
        case .lg: return 52
        case .md: return 44
        case .sm: return 36
        }
    }

    fileprivate var horizontalPadding: CGFloat {
        switch self {
        case .lg, .md: return 20
        case .sm:      return 12
        }
    }

    fileprivate var font: Font {
        switch self {
        case .lg, .md: return ChalNaTypography.headline
        case .sm:      return ChalNaTypography.label
        }
    }
}

public struct ChalNaButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public let variant: ChalNaButtonVariant
    public let size: ChalNaButtonSize
    public let fillWidth: Bool
    public let destructive: Bool

    public init(
        _ variant: ChalNaButtonVariant,
        size: ChalNaButtonSize = .lg,
        fillWidth: Bool = false,
        destructive: Bool = false
    ) {
        self.variant = variant
        self.size = size
        self.fillWidth = fillWidth
        self.destructive = destructive
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .tracking(ChalNaTypography.Tracking.title)
            .foregroundColor(foreground(pressed: configuration.isPressed))
            .frame(minHeight: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: fillWidth ? .infinity : nil)
            .background(background(pressed: configuration.isPressed))
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.sm, style: .continuous))
            .animation(ChalNaMotion.fast, value: configuration.isPressed)
    }

    /// 강조색. `destructive` 면 danger 계열로 바뀐다.
    private var tint: Color { destructive ? ChalNaColor.danger : ChalNaColor.accent }
    private var tintFill: Color { destructive ? ChalNaColor.danger : ChalNaColor.accentFill }

    private func foreground(pressed: Bool) -> Color {
        guard isEnabled else { return ChalNaColor.textTertiary }
        switch variant {
        case .primary:
            return ChalNaColor.onAccent
        case .secondary:
            return destructive ? ChalNaColor.danger : ChalNaColor.textPrimary
        case .ghost:
            // pressed 도 destructive 계열을 유지해야 한다. accentPressed 를 무조건 쓰면
            // 파괴적 ghost 버튼이 눌린 동안 red -> 보라로 바뀐다(ChalNaMotion.fast 로 실제 보임).
            return pressed
                ? (destructive ? ChalNaColor.dangerPressed : ChalNaColor.accentPressed)
                : tint
        }
    }

    @ViewBuilder
    private func background(pressed: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: ChalNaRadius.sm, style: .continuous)
        if !isEnabled {
            switch variant {
            case .primary:            shape.fill(ChalNaColor.surface)
            case .secondary:          shape.fill(ChalNaColor.surface)
            case .ghost:              shape.fill(Color.clear)
            }
        } else {
            switch variant {
            case .primary:   shape.fill(pressed ? tint : tintFill)
            case .secondary: shape.fill(pressed ? ChalNaColor.surfaceRaised : ChalNaColor.surface)
            case .ghost:     shape.fill(Color.clear)
            }
        }
    }

    @ViewBuilder
    private var border: some View {
        let shape = RoundedRectangle(cornerRadius: ChalNaRadius.sm, style: .continuous)
        switch variant {
        case .secondary:
            shape.strokeBorder(isEnabled ? ChalNaColor.border : ChalNaColor.border.opacity(0.5), lineWidth: 1)
        case .primary, .ghost:
            Color.clear
        }
    }
}

public extension ButtonStyle where Self == ChalNaButtonStyle {
    static var chalNaPrimary: ChalNaButtonStyle   { .init(.primary) }
    static var chalNaSecondary: ChalNaButtonStyle { .init(.secondary) }
    static var chalNaGhost: ChalNaButtonStyle     { .init(.ghost) }

    static func chalNa(
        _ variant: ChalNaButtonVariant,
        size: ChalNaButtonSize = .lg,
        fillWidth: Bool = false,
        destructive: Bool = false
    ) -> ChalNaButtonStyle {
        .init(variant, size: size, fillWidth: fillWidth, destructive: destructive)
    }
}

#Preview {
    VStack(spacing: 12) {
        Button("저장하기") {}.buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
        Button("공유") {}.buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))
        Button("홈으로") {}.buttonStyle(.chalNaGhost)
        Button("필름 삭제") {}.buttonStyle(.chalNa(.ghost, destructive: true))
        Button("전부 삭제") {}.buttonStyle(.chalNa(.secondary, size: .md, destructive: true))
        Button("비활성") {}.buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true)).disabled(true)
        Button("작은 버튼") {}.buttonStyle(.chalNa(.secondary, size: .sm))
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ChalNaColor.bg)
}
