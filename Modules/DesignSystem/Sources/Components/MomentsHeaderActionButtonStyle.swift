import SwiftUI

public enum MomentsHeaderActionProminence {
    case standard
    case primary
}

public struct MomentsHeaderActionButtonStyle: ButtonStyle {
    public let prominence: MomentsHeaderActionProminence

    public init(_ prominence: MomentsHeaderActionProminence = .standard) {
        self.prominence = prominence
    }

    public func makeBody(configuration: Configuration) -> some View {
        HeaderActionButtonBody(configuration: configuration, prominence: prominence)
    }
}

private struct HeaderActionButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let prominence: MomentsHeaderActionProminence

    var body: some View {
        if #available(iOS 26.0, *) {
            liquidGlassBody
        } else {
            fallbackBody
        }
    }

    @available(iOS 26.0, *)
    private var liquidGlassBody: some View {
        configuration.label
            .padding(.horizontal, MomentsSpacing.xs)
            .frame(minWidth: MomentsSpacing.minimumHitTarget, minHeight: MomentsSpacing.minimumHitTarget)
            .contentShape(Capsule(style: .continuous))
            .glassEffect(
                .regular.tint(glassTint).interactive(),
                in: Capsule(style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private var fallbackBody: some View {
        configuration.label
            .padding(.horizontal, MomentsSpacing.xs)
            .frame(minWidth: MomentsSpacing.minimumHitTarget, minHeight: MomentsSpacing.minimumHitTarget)
            .contentShape(Capsule(style: .continuous))
            .background {
                Capsule(style: .continuous)
                    .fill(fallbackFill)
            }
            .opacity(configuration.isPressed ? 0.68 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private var glassTint: Color {
        switch prominence {
        case .standard:
            return MomentsColor.ivory.opacity(0.24)
        case .primary:
            return MomentsColor.coral.opacity(0.22)
        }
    }

    private var fallbackFill: Color {
        guard configuration.isPressed else { return .clear }
        switch prominence {
        case .standard:
            return MomentsColor.ivory.opacity(0.62)
        case .primary:
            return MomentsColor.coral.opacity(0.18)
        }
    }
}

public extension ButtonStyle where Self == MomentsHeaderActionButtonStyle {
    static var momentsHeaderAction: MomentsHeaderActionButtonStyle {
        .init(.standard)
    }

    static var momentsHeaderPrimaryAction: MomentsHeaderActionButtonStyle {
        .init(.primary)
    }
}
