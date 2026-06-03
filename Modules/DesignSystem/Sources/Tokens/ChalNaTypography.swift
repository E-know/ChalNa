import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Danawa DDS Mobile v2.0 타이포 토큰. 한글 본문은 시스템 폰트, Spec/숫자는 SF Mono.
// 다나와 가이드:
//   본문 15~16px, 14px 이하 사용 제한, 11px 이하 컨텐츠 금지.
//   Title Big1/Big2 24px bold/regular (LH 32, tracking -0.2px)
//   Title Big3/Big4 22px (LH 32) / Medium 20px (LH 30)
//   Header 19px / List 16px
//   Body1 16px (LH 22) / Body2 15px (LH 20) / Spec 14px (LH 22)
public enum ChalNaTypography {

    private enum FontName {
        static let systemMono = "SF Mono"
    }

    // MARK: - KR (기본 시스템 폰트)

    public static func displayKR(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    public static func krSemibold(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: .semibold, design: .default)
    }

    public static func krBody(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    /// 다나와 Title (Big1/Big2) 기본 24pt bold
    public static func title(_ size: CGFloat = Size.h1, weight: Font.Weight = .bold) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    // MARK: - Mono (Spec / Price / 코드용)

    public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(FontName.systemMono, size: size, relativeTo: textStyle(for: size)).weight(weight)
    }

    public static func monoFallback(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(FontName.systemMono, size: size, relativeTo: textStyle(for: size)).weight(weight)
    }

    // MARK: - KERISKEDU (영상 오버레이와 동일 폰트)
    // UIAppFonts 로 앱에 등록된 KERISKEDU 패밀리의 Line(outline) 변형을 우선 사용.
    // CompositionService 의 영상 라벨 폰트 해석과 동일 규칙 — 매칭 실패 시 시스템 bold fallback.
    public static func keris(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        #if canImport(UIKit)
        if let name = kerisFontName, UIFont(name: name, size: size) != nil {
            return Font.custom(name, size: size)
        }
        #endif
        return Font.system(size: size, weight: weight, design: .default)
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

    /// 측정/합성용 UIFont — `keris()` Font 와 같은 family. 실패 시 시스템 bold.
    public static func kerisUIFont(_ size: CGFloat) -> UIFont {
        if let name = kerisFontName, let f = UIFont(name: name, size: size) { return f }
        return .systemFont(ofSize: size, weight: .bold)
    }
    #endif

    // MARK: - Legacy stubs (ChalNa 무드 제거: Fraunces/Caveat/BradleyHand 의존 삭제, Pretendard 로 매핑)
    // Phase 2~5 에서 호출처 정리될 때까지 빌드 호환용으로 둔다.

    public static func displayEN(_ size: CGFloat, italic: Bool = false, weight: Font.Weight = .regular) -> Font {
        krBody(size, weight: weight)
    }

    public static func serifFallback(_ size: CGFloat, italic: Bool = false) -> Font {
        krBody(size, weight: .regular)
    }

    public static func hand(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        krBody(size, weight: weight)
    }

    public static func handFallback(_ size: CGFloat) -> Font {
        krBody(size, weight: .regular)
    }

    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<12: return .caption2
        case ..<15: return .caption
        case ..<18: return .body
        case ..<23: return .title3
        case ..<30: return .title2
        case ..<44: return .title
        default: return .largeTitle
        }
    }

    // MARK: - Scale (다나와 가이드 기준)
    public enum Size {
        // 다나와 11px 이하 컨텐츠 금지 — 최소 12pt
        public static let tag: CGFloat       = 12
        public static let caption: CGFloat   = 12   // Etc 13 → 안전치 12
        public static let small: CGFloat     = 14   // Spec / Menu 2depth (14px 이하 사용 제한)
        public static let body2: CGFloat     = 15   // Body2 (LH 20)
        public static let body: CGFloat      = 16   // Body1 / List / Menu Big (LH 22)
        public static let bodyLg: CGFloat    = 18
        public static let header: CGFloat    = 19   // Mobile Header
        public static let h2: CGFloat        = 20   // Medium1/2 (LH 30)
        public static let big: CGFloat       = 22   // Big3/4 (LH 32)
        public static let h1: CGFloat        = 24   // Big1/2 Title (LH 32)
        public static let displayS: CGFloat  = 28
        public static let displayL: CGFloat  = 32
    }

    // MARK: - Tracking (letter-spacing in points)
    public enum Tracking {
        public static let titleKR: CGFloat   = -0.20   // Big titles
        public static let bodyKR: CGFloat    = -0.30   // Body1/2/Spec
        public static let priceKR: CGFloat   = -0.40   // Price labels

        // Legacy alias (호환)
        public static let displayEN: CGFloat = -0.20
        public static let displayKR: CGFloat = -0.20
        public static let h2KR: CGFloat      = -0.20
        public static let tagLabel: CGFloat  =  0.00
    }
}

// MARK: - View helpers for tag labels

public extension Text {
    func tagLabel(color: Color = ChalNaColor.taupe) -> Text {
        self.font(ChalNaTypography.monoFallback(ChalNaTypography.Size.tag, weight: .medium))
            .tracking(ChalNaTypography.Tracking.tagLabel)
            .foregroundColor(color)
    }
}
