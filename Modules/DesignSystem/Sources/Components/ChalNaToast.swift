import SwiftUI

/// 하단 토스트. 2.2초 후 자동으로 사라진다.
public struct ChalNaToast: View {
    private let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        Text(verbatim: message)
            .font(ChalNaTypography.label)
            .foregroundColor(ChalNaColor.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(ChalNaColor.surfaceRaised))
            .overlay(Capsule().strokeBorder(ChalNaColor.border, lineWidth: 1))
            .chalNaShadow(ChalNaShadow.floating)
    }
}

public extension View {
    /// `message` 가 nil 이 아니면 하단에 토스트를 띄우고 2.2초 뒤 `onDismiss` 를 부른다.
    func chalNaToast(message: String?, onDismiss: @escaping () -> Void) -> some View {
        overlay(alignment: .bottom) {
            if let message {
                ChalNaToast(message: message)
                    .padding(.bottom, 64)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .task(id: message) {
                        try? await Task.sleep(nanoseconds: 2_200_000_000)
                        onDismiss()
                    }
            }
        }
        .animation(ChalNaMotion.standard, value: message)
    }
}

#Preview {
    Color.clear
        .chalNaToast(message: "사진 보관함에 저장했어요") {}
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChalNaColor.bg)
}
