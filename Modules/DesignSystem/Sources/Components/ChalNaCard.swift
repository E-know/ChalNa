import SwiftUI

/// surface + 1px border 컨테이너.
/// 화면 8곳에 복붙돼 있던 `RoundedRectangle().fill().overlay(strokeBorder())` 조합을 대체한다.
public struct ChalNaCard<Content: View>: View {
    private let padding: CGFloat
    private let showsBorder: Bool
    private let content: () -> Content

    public init(
        padding: CGFloat = 16,
        showsBorder: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.showsBorder = showsBorder
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ChalNaRadius.md, style: .continuous)
                    .fill(ChalNaColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChalNaRadius.md, style: .continuous)
                    .strokeBorder(showsBorder ? ChalNaColor.border : Color.clear, lineWidth: 1)
            )
    }
}

#Preview {
    VStack(spacing: 12) {
        ChalNaCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("제주도, 우리의 봄").font(ChalNaTypography.headline)
                    .foregroundColor(ChalNaColor.textPrimary)
                Text(verbatim: "8 클립 · 01:40").font(ChalNaTypography.label)
                    .foregroundColor(ChalNaColor.textSecondary)
            }
        }
        ChalNaCard(padding: 0) {
            Text("padding 0 · 리스트 행 컨테이너")
                .font(ChalNaTypography.body)
                .foregroundColor(ChalNaColor.textPrimary)
                .padding(16)
        }
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ChalNaColor.bg)
}
