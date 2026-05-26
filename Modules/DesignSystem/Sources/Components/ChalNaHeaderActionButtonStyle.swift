import SwiftUI

public enum ChalNaHeaderActionProminence {
    case standard
    case primary
}

/// 다나와 네비게이션 바 좌·우측 액션 버튼 스타일.
public struct ChalNaHeaderActionButtonStyle: ButtonStyle {
    public let prominence: ChalNaHeaderActionProminence

    public init(_ prominence: ChalNaHeaderActionProminence = .standard) {
        self.prominence = prominence
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .frame(minWidth: 44, minHeight: 44)
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
            return pressed ? ChalNaColor.Gray.g100 : .clear
        case .primary:
            return pressed ? ChalNaColor.Purple.p200.opacity(0.6) : ChalNaColor.Purple.p100.opacity(0.5)
        }
    }
}

public extension ButtonStyle where Self == ChalNaHeaderActionButtonStyle {
    static var chalNaHeaderAction: ChalNaHeaderActionButtonStyle {
        .init(.standard)
    }

    static var chalNaHeaderPrimaryAction: ChalNaHeaderActionButtonStyle {
        .init(.primary)
    }
}
