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

    // MARK: - Mono (타임코드 · 퍼센트 등 순수 숫자 전용)

    /// **한글에 쓰지 않는다.** SF Mono 에 한글 글리프가 없어 폴백되며 자간이 어긋난다.
    public static func mono(_ style: Font.TextStyle = .footnote,
                            weight: Font.Weight = .regular) -> Font {
        .system(style, design: .monospaced, weight: weight)
    }

    // MARK: - Tracking

    public enum Tracking {
        /// 제목류 자간.
        public static let title: CGFloat = -0.20
    }

    // MARK: - KERISKEDU (브랜드 순간 · 영상 라벨 WYSIWYG 전용)

    /// Splash 브랜드 라벨과 영상 오버레이 미리보기에만 쓴다.
    /// 영상 출력과 픽셀 일치해야 하므로 **여기만 pt 를 직접 받는다**(Dynamic Type 비적용).
    public static func keris(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        #if canImport(UIKit)
        if let name = kerisFontName, UIFont(name: name, size: size) != nil {
            return Font.custom(name, size: size)
        }
        #endif
        return .system(size: size, weight: weight, design: .default)
    }

    #if canImport(UIKit)
    private static let kerisFontName: String? = {
        let families = UIFont.familyNames.filter { $0.localizedCaseInsensitiveContains("KERIS") }
        for family in families {
            let names = UIFont.fontNames(forFamilyName: family)
            if let line = names.first(where: {
                let upper = $0.uppercased()
                return upper.contains("LINE") || upper.contains("OUTLINE")
            }) {
                return line
            }
            if let any = names.first { return any }
        }
        return nil
    }()

    /// 측정·합성용 UIFont — `keris()` 와 같은 family. 실패 시 시스템 bold.
    public static func kerisUIFont(_ size: CGFloat) -> UIFont {
        if let name = kerisFontName, let f = UIFont(name: name, size: size) { return f }
        return .systemFont(ofSize: size, weight: .bold)
    }
    #endif
}
