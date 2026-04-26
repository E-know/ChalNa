import SwiftUI

public enum MomentsButtonVariant {
    case coral
    case outline
    case text
}

public struct MomentsButtonStyle: ButtonStyle {
    public let variant: MomentsButtonVariant

    public init(_ variant: MomentsButtonVariant) {
        self.variant = variant
    }

    public func makeBody(configuration: Configuration) -> some View {
        switch variant {
        case .coral:    coral(configuration)
        case .outline:  outline(configuration)
        case .text:     text(configuration)
        }
    }

    // MARK: - Variants

    @ViewBuilder
    private func coral(_ c: Configuration) -> some View {
        c.label
            .font(MomentsTypography.krSemibold(15))
            .tracking(-0.15)
            .foregroundColor(.white)
            .padding(.horizontal, MomentsSpacing.lg)
            .padding(.vertical, MomentsSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: MomentsRadius.button, style: .continuous)
                    .fill(MomentsColor.coral)
                    .overlay(
                        RoundedRectangle(cornerRadius: MomentsRadius.button, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            .padding(1)
                    )
            )
            .momentsShadow(MomentsShadow.md)
            .scaleEffect(c.isPressed ? 0.97 : 1)
            .opacity(c.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: c.isPressed)
    }

    @ViewBuilder
    private func outline(_ c: Configuration) -> some View {
        c.label
            .font(MomentsTypography.krSemibold(15))
            .tracking(-0.15)
            .foregroundColor(MomentsColor.ink)
            .padding(.horizontal, MomentsSpacing.lg)
            .padding(.vertical, MomentsSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: MomentsRadius.button, style: .continuous)
                    .stroke(MomentsColor.ink, lineWidth: 1.25)
            )
            .scaleEffect(c.isPressed ? 0.97 : 1)
            .opacity(c.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: c.isPressed)
    }

    @ViewBuilder
    private func text(_ c: Configuration) -> some View {
        c.label
            .font(MomentsTypography.krBody(14, weight: .medium))
            .foregroundColor(MomentsColor.coral)
            .padding(.horizontal, MomentsSpacing.xs)
            .padding(.vertical, MomentsSpacing.xxs)
            .overlay(alignment: .bottom) {
                DashedLine()
                    .stroke(MomentsColor.coral, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .frame(height: 1)
                    .padding(.horizontal, MomentsSpacing.xs)
            }
            .opacity(c.isPressed ? 0.6 : 1)
    }
}

public extension ButtonStyle where Self == MomentsButtonStyle {
    static var momentsCoral:   MomentsButtonStyle { .init(.coral) }
    static var momentsOutline: MomentsButtonStyle { .init(.outline) }
    static var momentsText:    MomentsButtonStyle { .init(.text) }
}

struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}

#Preview {
    VStack(spacing: 24) {
        Button("Vlog 만들기") {}.buttonStyle(.momentsCoral)
        Button("불러오기") {}.buttonStyle(.momentsOutline)
        Button("나중에 하기 →") {}.buttonStyle(.momentsText)
    }
    .padding(32)
    .background(MomentsColor.cream)
}
