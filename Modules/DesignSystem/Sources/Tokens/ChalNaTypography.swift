import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 역할 기반 타이포 토큰.
///
/// 6개 역할이 **표준 iOS 텍스트 스타일에 정확히 대응**한다 —
/// display 28=`.title`, title 22=`.title2`, headline 17=`.headline`,
/// body 16=`.callout`, label 13=`.footnote`, caption 12=`.caption`.
/// 그래서 별도 스케일링 코드 없이 Dynamic Type 을 그대로 따른다.
///
/// 앱은 **시스템 기본 폰트(SF Pro) 하나만** 쓴다 — 번들 커스텀 폰트도, 다른 `design`
/// (monospaced 등)도 없다. 숫자 폭이 흔들리면 안 되는 곳은 폰트를 바꾸지 말고
/// `Text.monospacedDigit()`(같은 폰트의 tabular figure)을 붙인다.
///
/// 앱 전역 상한은 `RootView` 의 `.dynamicTypeSize(...DynamicTypeSize.accessibility1)`.
///
/// 근거: `docs/superpowers/specs/2026-07-28-app-redesign-design.md` §4.3
public enum ChalNaTypography {

    // MARK: - Roles

    /// 화면 대제목 (28pt bold 상당).
    public static var display: Font  { .system(.title,    design: .default, weight: .bold) }
    /// 섹션 제목 (22pt semibold 상당).
    public static var title: Font    { .system(.title2,   design: .default, weight: .semibold) }
    /// 카드 제목 · 버튼 라벨 (17pt semibold 상당).
    public static var headline: Font { .system(.headline, design: .default, weight: .semibold) }
    /// 본문 (16pt 상당).
    public static var body: Font     { .system(.callout,  design: .default, weight: .regular) }
    /// 메타 · 태그 (13pt medium 상당). 구 `tagLabel()` 대체.
    public static var label: Font    { .system(.footnote, design: .default, weight: .medium) }
    /// 캡션 · 힌트 (12pt 상당). 최소 크기.
    public static var caption: Font  { .system(.caption,  design: .default, weight: .regular) }

    // MARK: - Tracking

    public enum Tracking {
        /// 제목류 자간.
        public static let title: CGFloat = -0.20
    }

    // MARK: - Fixed size (영상 라벨 WYSIWYG · 스플래시 브랜드 전용)

    /// 기본 폰트를 **pt 로 직접** 받는 토큰 — Dynamic Type 비적용.
    ///
    /// 두 곳만 쓴다:
    /// - 자동 시간/날짜 오버레이 미리보기. 합성(`CATextLayer`)의 `UIFont` 측정값과
    ///   픽셀 단위로 일치해야 해서 스케일되는 역할 토큰을 쓸 수 없다.
    /// - 스플래시 브랜드 라벨. 아이콘과 크기 비율이 고정이라 스케일되면 안 된다.
    public static func fixed(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    #if canImport(UIKit)
    /// `fixed(_:weight:)` 의 UIKit 짝 — 오버레이 라벨 실측용. 둘은 같은 폰트여야 한다.
    public static func fixedUIFont(_ size: CGFloat) -> UIFont {
        .systemFont(ofSize: size, weight: .bold)
    }
    #endif
}
