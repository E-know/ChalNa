import CoreGraphics

// Danawa DDS Mobile v2.0: 라운딩 4px 단위 규칙.
public enum ChalNaRadius {
    public static let film: CGFloat   = 4    // 작은 chip / thumb 모서리
    public static let button: CGFloat = 4    // 다나와 표준 버튼 라운딩
    public static let card: CGFloat   = 8    // 카드 / list item
    public static let sheet: CGFloat  = 16   // 모달 / 바텀시트 상단
    public static let pill: CGFloat   = 999  // 칩 / 토글
}
