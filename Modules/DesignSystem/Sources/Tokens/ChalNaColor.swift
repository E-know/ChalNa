import SwiftUI

/// 사진집의 종이와 인쇄색. 영상 위의 색은 출력 프레임과 같은 밝기를 유지한다.
public enum ChalNaColor {
    public static let bg = Color(hex: 0xF8F6F0)
    public static let surface = Color(hex: 0xEEEBE3)
    public static let surfaceRaised = Color.white
    public static let canvas = Color.black

    public static let border = Color(hex: 0xCFC9BE)
    public static let borderStrong = Color(hex: 0x938C83)
    public static let textPrimary = Color(hex: 0x211F1C)
    public static let textSecondary = Color(hex: 0x655F58)
    public static let textTertiary = Color(hex: 0x898278)

    public static let accent = Color(hex: 0x913A2C)
    public static let selection = Color(hex: 0xF2DDD4)
    public static let accentFill = textPrimary
    public static let accentPressed = Color(hex: 0x702D22)
    public static let onAccent = Color.white
    public static let danger = accent
    public static let dangerPressed = accentPressed
    public static let brandDeep = accent
    public static let scrim = Color.black.opacity(0.55)
    public static let onMedia = Color.white
    public static let onMediaDark = Color.black
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
