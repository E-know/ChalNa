import SwiftUI

public extension View {
    /// 화면 최상단 커스텀 네비게이션 바에 입히는 다나와 표준 패턴.
    /// 본문이 스크롤되어 올라온 정도(`scrollProgress` 0→1)에 따라
    /// 흰 배경 + 하단 1px Gray-200 hairline + 미세 shadow 가 등장한다.
    func chalNaHeaderBar(scrollProgress: Double = 0) -> some View {
        modifier(ChalNaHeaderBarModifier(scrollProgress: scrollProgress))
    }
}

private struct ChalNaHeaderBarModifier: ViewModifier {
    let scrollProgress: Double

    private var progress: Double {
        max(0, min(1, scrollProgress))
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                ChalNaColor.cream
                    .opacity(progress)
                    .ignoresSafeArea(edges: .top)
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(ChalNaColor.Gray.g200.opacity(progress))
                    .frame(height: 1)
            }
            .shadow(color: Color.black.opacity(0.06 * progress), radius: 4, x: 0, y: 1)
    }
}
