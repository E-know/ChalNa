import SwiftUI

public extension View {
    /// 화면 최상단 커스텀 NavigationBar(헤더)에 입히는 표준 padding + 스크롤 분리 효과.
    /// VStack 첫 자식으로 직접 배치되는 헤더가 cream + grain 배경(`momentsScreen()`) 위에서
    /// 일관된 inset/높이를 갖도록 하고, 본문이 스크롤되어 올라온 정도(`scrollProgress`)에
    /// 맞춰 hairline + 미세 shadow를 등장시킨다.
    ///
    /// - Parameter scrollProgress: 0 → 분리 없음(cream-on-cream), 1 → 완전한 hairline + shadow.
    ///   `View.trackScrollOffset(in:)`이 publish한 offset을 8pt 윈도우로 정규화해 넘긴다.
    func momentsHeaderBar(scrollProgress: Double = 0) -> some View {
        let p = max(0, min(1, scrollProgress))
        return self
            .padding(.horizontal, MomentsSpacing.md + 4)
            .padding(.vertical, MomentsSpacing.sm)
            .frame(maxWidth: .infinity)
            .background {
                if #available(iOS 26.0, *) {
                    Rectangle()
                        .fill(.clear)
                        .glassEffect(
                            .regular.tint(MomentsColor.cream.opacity(0.18)),
                            in: Rectangle()
                        )
                        .opacity(p)
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(MomentsColor.taupe.opacity(0.12 * p))
                    .frame(height: 0.5)
            }
            .shadow(color: Color.black.opacity(0.05 * p), radius: 6, x: 0, y: 4)
    }
}
