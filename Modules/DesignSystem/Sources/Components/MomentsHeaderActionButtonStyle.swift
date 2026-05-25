import SwiftUI

public enum MomentsHeaderActionProminence {
    case standard
    case primary
}

/// 다나와 네비게이션 바 좌·우측 액션 버튼 스타일.
public struct MomentsHeaderActionButtonStyle: ButtonStyle {
    public let prominence: MomentsHeaderActionProminence

    public init(_ prominence: MomentsHeaderActionProminence = .standard) {
        self.prominence = prominence
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, MomentsSpacing.xs)
            .frame(minWidth: MomentsSpacing.minimumHitTarget, minHeight: MomentsSpacing.minimumHitTarget)
            .contentShape(Capsule(style: .continuous))
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundFill(pressed: configuration.isPressed))
            )
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func backgroundFill(pressed: Bool) -> Color {
        switch prominence {
        case .standard:
            return pressed ? MomentsColor.Gray.g100 : .clear
        case .primary:
            return pressed ? MomentsColor.Purple.p200.opacity(0.6) : MomentsColor.Purple.p100.opacity(0.5)
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
