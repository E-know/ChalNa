import SwiftUI

public enum MomentsColor {
    public static let cream = Color("MomentsCream", bundle: .main)
    public static let ivory = Color("MomentsIvory", bundle: .main)
    public static let coral = Color("MomentsCoral", bundle: .main)
    public static let sage  = Color("MomentsSage",  bundle: .main)
    public static let denim = Color("MomentsDenim", bundle: .main)
    public static let ink   = Color("MomentsInk",   bundle: .main)
    public static let taupe = Color("MomentsTaupe", bundle: .main)

    public enum Chip {
        public static let liveBackground  = Color(hex: 0xF3D5CE)
        public static let liveForeground  = Color(hex: 0x8A3B2E)
        public static let videoBackground = Color(hex: 0xDAE2D3)
        public static let videoForeground = Color(hex: 0x3F5336)
        public static let filmBackground  = Color(hex: 0xEAD7C8)
        public static let filmForeground  = Color(hex: 0x6B3E2A)
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
