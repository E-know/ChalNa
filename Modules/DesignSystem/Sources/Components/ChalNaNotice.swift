import SwiftUI

/// 정보 안내 카드. FilmDetail 의 "영상 파일을 찾을 수 없어요" 등.
public struct ChalNaNotice: View {
    private let icon: ChalNaIconKind
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey

    public init(
        icon: ChalNaIconKind = .film,
        title: LocalizedStringKey,
        message: LocalizedStringKey
    ) {
        self.icon = icon
        self.title = title
        self.message = message
    }

    public var body: some View {
        ChalNaCard {
            HStack(alignment: .top, spacing: 12) {
                ChalNaIcon(icon, size: 20)
                    .foregroundColor(ChalNaColor.textSecondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(ChalNaTypography.headline)
                        .foregroundColor(ChalNaColor.textPrimary)
                    Text(message)
                        .font(ChalNaTypography.label)
                        .foregroundColor(ChalNaColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ChalNaNotice(
        title: "영상 파일을 찾을 수 없어요",
        message: "앱을 다시 설치하셨거나 파일이 삭제되었어요. 재생과 공유는 불가능하고, 라이브러리에서 항목을 정리할 수 있어요."
    )
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ChalNaColor.bg)
}
