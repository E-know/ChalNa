import SwiftUI

// Danawa DDS Mobile v2.0 타이포 토큰. 한글 본문은 시스템 폰트, Spec/숫자는 SF Mono.
// 다나와 가이드:
//   본문 15~16px, 14px 이하 사용 제한, 11px 이하 컨텐츠 금지.
//   Title Big1/Big2 24px bold/regular (LH 32, tracking -0.2px)
//   Title Big3/Big4 22px (LH 32) / Medium 20px (LH 30)
//   Header 19px / List 16px
//   Body1 16px (LH 22) / Body2 15px (LH 20) / Spec 14px (LH 22)
public enum MomentsTypography {

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

    // MARK: - Legacy stubs (Moments 무드 제거: Fraunces/Caveat/BradleyHand 의존 삭제, Pretendard 로 매핑)
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
    func tagLabel(color: Color = MomentsColor.taupe) -> Text {
        self.font(MomentsTypography.monoFallback(MomentsTypography.Size.tag, weight: .medium))
            .tracking(MomentsTypography.Tracking.tagLabel)
            .foregroundColor(color)
    }
}
