import CoreGraphics

/// 라디우스 토큰. 커머스 카드용 4px 단위를 버리고 미디어 카드에 맞게 키웠다.
/// 근거: docs/superpowers/specs/2026-07-28-app-redesign-design.md §4.4
public enum ChalNaRadius {
    /// 10×6pt 급 초소형 인디케이터용. `xs` 이상은 이 크기에서 캡슐이 되어버린다.
    public static let xxs: CGFloat = 2
    /// 태그 · 작은 썸네일.
    public static let xs: CGFloat = 6
    /// 버튼 · 입력 필드.
    public static let sm: CGFloat = 10
    /// 카드 · 프리뷰 캔버스.
    public static let md: CGFloat = 14
    /// 바텀시트 · 플로팅 툴바.
    public static let lg: CGFloat = 20
}
