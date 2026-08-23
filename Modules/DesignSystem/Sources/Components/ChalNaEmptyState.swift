import SwiftUI

/// 빈 상태. Home 라이브러리 비었을 때 · FilmDetail 필름 없을 때.
public struct ChalNaEmptyState: View {
    private let icon: ChalNaIconKind
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?

    public init(
        icon: ChalNaIconKind = .film,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: 12) {
            ChalNaIcon(icon, size: 36, weight: .light)
                .foregroundColor(ChalNaColor.textTertiary)

            Text(title)
                .font(ChalNaTypography.title)
                .foregroundColor(ChalNaColor.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(ChalNaTypography.body)
                .foregroundColor(ChalNaColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.chalNa(.secondary, size: .md))
                    .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ChalNaEmptyState(
        title: "아직 만든 필름이 없어요",
        message: "Live Photo와 짧은 영상을 촬영일 순서로 이어 붙여\n한 편의 필름을 만들어 보세요.",
        actionTitle: "첫 Vlog 시작하기"
    ) {}
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ChalNaColor.bg)
}
