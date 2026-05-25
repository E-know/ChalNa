import SwiftUI

// Danawa DDS Mobile v2.0 버튼.
// XLarge / Large / Medium / Small × 강조형(면형/선형) / 표준형(면형/선형) / 텍스트.

public enum MomentsButtonVariant {
    case filled            // 강조형 면형: Purple-600 bg
    case outlined          // 강조형 선형: Purple-600 border
    case standardFilled    // 표준형 면형: Ink bg
    case standardOutlined  // 표준형 선형: Gray-300 border
    case text              // 텍스트 버튼
}

public enum MomentsButtonSize {
    case xl   // 56pt
    case lg   // 48pt (기본)
    case md   // 40pt
    case sm   // 32pt

    fileprivate var height: CGFloat {
        switch self {
        case .xl: return 56
        case .lg: return 48
        case .md: return 40
        case .sm: return 32
        }
    }

    fileprivate var horizontalPadding: CGFloat {
        switch self {
        case .xl, .lg, .md: return MomentsSpacing.md   // 16pt (다나와 권장 최소)
        case .sm:           return MomentsSpacing.sm   // 12pt
        }
    }

    fileprivate var font: Font {
        switch self {
        case .xl, .lg: return MomentsTypography.krBody(MomentsTypography.Size.body, weight: .semibold)
        case .md:      return MomentsTypography.krBody(MomentsTypography.Size.body2, weight: .semibold)
        case .sm:      return MomentsTypography.krBody(MomentsTypography.Size.small, weight: .medium)
        }
    }
}

public struct MomentsButtonStyle: ButtonStyle {
    public let variant: MomentsButtonVariant
    public let size: MomentsButtonSize
    public let fillWidth: Bool

    public init(_ variant: MomentsButtonVariant, size: MomentsButtonSize = .lg, fillWidth: Bool = false) {
        self.variant = variant
        self.size = size
        self.fillWidth = fillWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .tracking(MomentsTypography.Tracking.titleKR)
            .foregroundColor(foreground)
            .frame(minHeight: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: fillWidth ? .infinity : nil)
            .background(backgroundShape)
            .overlay(borderShape)
            .clipShape(RoundedRectangle(cornerRadius: MomentsRadius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch variant {
        case .filled:            return .white
        case .standardFilled:    return .white
        case .outlined:          return MomentsColor.coral
        case .standardOutlined:  return MomentsColor.ink
        case .text:              return MomentsColor.coral
        }
    }

    @ViewBuilder
    private var backgroundShape: some View {
        switch variant {
        case .filled:
            RoundedRectangle(cornerRadius: MomentsRadius.button, style: .continuous)
                .fill(MomentsColor.coral)
        case .standardFilled:
            RoundedRectangle(cornerRadius: MomentsRadius.button, style: .continuous)
                .fill(MomentsColor.ink)
        case .outlined, .standardOutlined:
            RoundedRectangle(cornerRadius: MomentsRadius.button, style: .continuous)
                .fill(Color.white)
        case .text:
            Color.clear
        }
    }

    @ViewBuilder
    private var borderShape: some View {
        switch variant {
        case .outlined:
            RoundedRectangle(cornerRadius: MomentsRadius.button, style: .continuous)
                .strokeBorder(MomentsColor.coral, lineWidth: 1.2)
        case .standardOutlined:
            RoundedRectangle(cornerRadius: MomentsRadius.button, style: .continuous)
                .strokeBorder(MomentsColor.Gray.g300, lineWidth: 1)
        default:
            Color.clear
        }
    }
}

public extension ButtonStyle where Self == MomentsButtonStyle {
    static var momentsFilled:   MomentsButtonStyle { .init(.filled) }
    static var momentsOutlined: MomentsButtonStyle { .init(.outlined) }
    static var momentsText:     MomentsButtonStyle { .init(.text) }

    // Legacy alias (Phase 5 호출처 정리 전까지 호환)
    static var momentsCoral:   MomentsButtonStyle { .init(.filled) }
    static var momentsOutline: MomentsButtonStyle { .init(.standardOutlined) }

    static func moments(_ variant: MomentsButtonVariant, size: MomentsButtonSize = .lg, fillWidth: Bool = false) -> MomentsButtonStyle {
        .init(variant, size: size, fillWidth: fillWidth)
    }
}

#Preview {
    VStack(spacing: 16) {
        Button("강조형 면형 (Filled · L)") {}.buttonStyle(.moments(.filled, size: .lg, fillWidth: true))
        Button("강조형 선형 (Outlined · L)") {}.buttonStyle(.moments(.outlined, size: .lg, fillWidth: true))
        Button("표준형 면형 (Standard Filled)") {}.buttonStyle(.moments(.standardFilled, size: .lg, fillWidth: true))
        Button("표준형 선형 (Standard Outlined)") {}.buttonStyle(.moments(.standardOutlined, size: .lg, fillWidth: true))
        Button("텍스트 버튼") {}.buttonStyle(.momentsText)
    }
    .padding(24)
    .background(MomentsColor.cream)
}
