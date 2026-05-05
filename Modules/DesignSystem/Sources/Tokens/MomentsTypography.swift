import SwiftUI

public enum MomentsTypography {

    private enum FontName {
        static let fraunces         = "Fraunces"
        static let frauncesItalic   = "Fraunces-Italic"
        static let pretendard       = "Pretendard"
        static let caveat           = "Caveat"
        static let jetbrainsMono    = "JetBrains Mono"
        static let bradleyHand      = "Bradley Hand"
        static let systemSerif      = "Georgia"
        static let systemSerifItalic = "Georgia-Italic"
        static let systemMono       = "SF Mono"
    }

    // MARK: - Display EN (Fraunces, italic light preferred)

    public static func displayEN(
        _ size: CGFloat,
        italic: Bool = true,
        weight: Font.Weight = .light
    ) -> Font {
        let custom = italic ? FontName.frauncesItalic : FontName.fraunces
        return Font.custom(custom, size: size, relativeTo: textStyle(for: size))
            .weight(weight)
            // fallback: system serif with .italic() 스타일은 캡처 모디파이어에서 처리
    }

    public static func serifFallback(_ size: CGFloat, italic: Bool = true) -> Font {
        let custom = italic ? FontName.systemSerifItalic : FontName.systemSerif
        return Font.custom(custom, size: size, relativeTo: textStyle(for: size))
    }

    // MARK: - Display KR (Pretendard 700)

    public static func displayKR(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        Font.custom(FontName.pretendard, size: size, relativeTo: textStyle(for: size)).weight(weight)
    }

    public static func krSemibold(_ size: CGFloat) -> Font {
        Font.custom(FontName.pretendard, size: size, relativeTo: textStyle(for: size)).weight(.semibold)
    }

    public static func krBody(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(FontName.pretendard, size: size, relativeTo: textStyle(for: size)).weight(weight)
    }

    // MARK: - Handwriting (Caveat / Bradley Hand fallback)

    public static func hand(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(FontName.caveat, size: size, relativeTo: textStyle(for: size)).weight(weight)
    }

    public static func handFallback(_ size: CGFloat) -> Font {
        Font.custom(FontName.bradleyHand, size: size, relativeTo: textStyle(for: size))
    }

    // MARK: - Mono (JetBrains Mono / SF Mono fallback)

    public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(FontName.jetbrainsMono, size: size, relativeTo: textStyle(for: size)).weight(weight)
    }

    public static func monoFallback(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(FontName.systemMono, size: size, relativeTo: textStyle(for: size)).weight(weight)
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

    // MARK: - Scale
    public enum Size {
        public static let tag: CGFloat       = 10
        public static let caption: CGFloat   = 14
        public static let body: CGFloat      = 16
        public static let bodyLg: CGFloat    = 18
        public static let h2: CGFloat        = 24
        public static let h1: CGFloat        = 32
        public static let displayS: CGFloat  = 48
        public static let displayL: CGFloat  = 72
    }

    // MARK: - Tracking
    public enum Tracking {
        public static let displayEN: CGFloat = -0.025 * 72   // approx em→pt @ 72
        public static let displayKR: CGFloat = -0.02  * 48
        public static let h2KR: CGFloat      = -0.01  * 24
        public static let tagLabel: CGFloat  =  0.14  * 10
    }
}

// MARK: - View helpers for tag labels (uppercase, mono, tracked)

public extension Text {
    func tagLabel(color: Color = MomentsColor.taupe) -> Text {
        self.font(MomentsTypography.monoFallback(10, weight: .medium))
            .tracking(MomentsTypography.Tracking.tagLabel)
            .foregroundColor(color)
    }
}
