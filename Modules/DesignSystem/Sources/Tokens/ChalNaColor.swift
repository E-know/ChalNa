import SwiftUI

// Danawa DDS Mobile v2.0 색상 토큰. ChalNa 식별자명은 그대로 두고 값만 다나와 톤으로 교체.
public enum ChalNaColor {
    public static let cream = Color("ChalNaCream", bundle: .module)  // White (#FFFFFF) - Background
    public static let ivory = Color("ChalNaIvory", bundle: .module)  // Gray-50 (#F8F8F8) - Surface
    public static let coral = Color("ChalNaCoral", bundle: .module)  // Purple-600 (#8B38E5) - Primary
    public static let sage  = Color("ChalNaSage",  bundle: .module)  // Cyan (#02B8D3) - Success / Info accent
    public static let denim = Color("ChalNaDenim", bundle: .module)  // Blue-500 (#2070EB) - Link / Secondary
    public static let ink   = Color("ChalNaInk",   bundle: .module)  // Gray-900 (#1A1A1A) - Text Primary
    public static let taupe = Color("ChalNaTaupe", bundle: .module)  // Gray-500 (#919191) - Text Sub

    // MARK: - Purple scale (Primary line, 9 step)
    public enum Purple {
        public static let p100 = Color(hex: 0xE0D1FF)
        public static let p200 = Color(hex: 0xBFA0FF)
        public static let p300 = Color(hex: 0xAA82FF)
        public static let p400 = Color(hex: 0x9868FC)
        public static let p500 = Color(hex: 0x9849FD)
        public static let p600 = Color(hex: 0x8B38E5)  // = .coral (Primary)
        public static let p700 = Color(hex: 0x693DE8)
        public static let p800 = Color(hex: 0x553DE8)
        public static let p900 = Color(hex: 0x462DE2)
    }

    // MARK: - Blue scale (Link / Info, 다나와 가격비교 메인)
    public enum Blue {
        public static let b50  = Color(hex: 0xF7FAFF)
        public static let b100 = Color(hex: 0xEBF3FF)
        public static let b200 = Color(hex: 0xDDEBFF)
        public static let b300 = Color(hex: 0x7EB2FF)
        public static let b400 = Color(hex: 0x448FFF)
        public static let b500 = Color(hex: 0x2070EB)  // = .denim
        public static let b600 = Color(hex: 0x0E68F0)
        public static let b700 = Color(hex: 0x005BE4)
        public static let b800 = Color(hex: 0x094FE5)
        public static let b900 = Color(hex: 0x0B3EAB)
    }

    // MARK: - Gray scale (Neutral)
    public enum Gray {
        public static let g50  = Color(hex: 0xF8F8F8)  // = .ivory
        public static let g100 = Color(hex: 0xEFEFEF)
        public static let g200 = Color(hex: 0xD9D9D9)
        public static let g300 = Color(hex: 0xBDBDBD)
        public static let g400 = Color(hex: 0xA0A0A0)
        public static let g500 = Color(hex: 0x919191)  // = .taupe
        public static let g600 = Color(hex: 0x6E6E6E)
        public static let g700 = Color(hex: 0x4F4F4F)
        public static let g800 = Color(hex: 0x2C2C2C)
        public static let g900 = Color(hex: 0x1A1A1A)  // = .ink
    }

    // MARK: - Status
    public static let success = Color(hex: 0x06B87F)  // Green-500
    public static let danger  = Color(hex: 0xE53B38)  // Red-500 (Live / Error)
    public static let info    = Color(hex: 0x02B8D3)  // Cyan = .sage

    // MARK: - Chip variants (Live / Video / Film)
    public enum Chip {
        // LIVE: Red 톤 — Live Photo 강조
        public static let liveBackground  = Color(hex: 0xFADAD9)
        public static let liveForeground  = Color(hex: 0xE53B38)
        // Video: Primary Purple 톤
        public static let videoBackground = Color(hex: 0xE0D1FF)
        public static let videoForeground = Color(hex: 0x8B38E5)
        // Film: Blue 보조 톤
        public static let filmBackground  = Color(hex: 0xDDEBFF)
        public static let filmForeground  = Color(hex: 0x2070EB)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
