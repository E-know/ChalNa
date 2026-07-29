import SwiftUI

public extension View {
    /// 본문이 스크롤되어 올라온 정도(0→1)에 따라 헤더 하단 hairline 이 나타난다.
    ///
    /// 구 `chalNaHeaderBar` 는 배경 흰색을 같이 페이드했지만, 다크에서는 헤더 배경이
    /// 이미 `bg` 라 페이드가 무의미하다. hairline 만 남긴다.
    func chalNaScrollHairline(progress: Double) -> some View {
        let clamped = max(0, min(1, progress))
        return overlay(alignment: .bottom) {
            Rectangle()
                .fill(ChalNaColor.border.opacity(clamped))
                .frame(height: 1)
        }
    }
}
