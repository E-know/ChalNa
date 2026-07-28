import SwiftUI

/// 다크 전용 시맨틱 색 토큰.
///
/// 화면은 **역할 이름만** 쓴다. 수치 스케일(`Purple`/`Blue`/`Gray`)은 마이그레이션
/// 기간 동안만 deprecated 로 남아 있고 P5 에서 삭제된다.
///
/// 값·대비 근거: `docs/superpowers/specs/2026-07-28-app-redesign-design.md` §4.1
public enum ChalNaColor {

    // MARK: - Surfaces

    /// 화면 배경. 무채색이 아니라 아주 옅은 인디고 캐스트.
    public static let bg            = Color(hex: 0x0B0A10)
    /// 카드 · 리스트 행.
    public static let surface       = Color(hex: 0x16151D)
    /// 바텀시트 · 플로팅 툴바.
    public static let surfaceRaised = Color(hex: 0x201F29)
    /// 영상 · 크롭 캔버스. 출력과 동일한 진짜 검정을 유지한다.
    /// `bg` 와 거의 같은 밝기라 화면 위에 '검은 섬'으로 뜨지 않는다.
    public static let canvas        = Color.black

    // MARK: - Lines

    /// 1px hairline.
    public static let border       = Color(hex: 0x2C2A38)
    /// 입력 필드 · 강조 경계.
    public static let borderStrong = Color(hex: 0x3D3A4D)

    // MARK: - Text

    /// 순백이 아니다 — 다크에서 순백은 헐레이션을 만든다.
    public static let textPrimary   = Color(hex: 0xF5F4F7)
    public static let textSecondary = Color(hex: 0xA3A0AE)
    /// **disabled 전용.** `bg` 대비 3.7:1 로 본문 기준(4.5)에 미달한다.
    /// 활성 텍스트에 쓰지 않는다.
    public static let textTertiary  = Color(hex: 0x6B6878)

    // MARK: - Accent

    /// 텍스트 · 아이콘 · 스트로크용 액센트.
    public static let accent        = Color(hex: 0x8B7BFF)
    /// 면형 버튼 배경.
    public static let accentFill    = Color(hex: 0x5B45E8)
    public static let accentPressed = Color(hex: 0xA091FF)
    /// `accentFill` 위의 라벨 색.
    public static let onAccent      = Color.white

    // MARK: - Status

    /// 파괴적 액션 · LIVE dot. 다크용으로 밝힌 레드.
    public static let danger  = Color(hex: 0xFF6B66)
    public static let success = Color(hex: 0x3DD9A0)

    // MARK: - Brand

    /// 앱 아이콘 색 그 자체. `bg` 대비 2.4:1 이므로
    /// **인터랙션(버튼·텍스트)에 쓰지 않는다.** Splash · 브랜드 면 전용.
    public static let brandDeep = Color(hex: 0x462DE2)

    // MARK: - Overlay

    public static let scrim = Color.black.opacity(0.6)

    // MARK: - Deprecated: 커머스 DDS 수치 스케일 (P5 에서 삭제)

    @available(*, deprecated, message: "시맨틱 토큰을 사용하세요 (accent/accentFill/textPrimary 등). P5 에서 삭제됩니다.")
    public enum Purple {
        public static let p100 = Color(hex: 0xE0D1FF)
        public static let p200 = Color(hex: 0xBFA0FF)
        public static let p300 = Color(hex: 0xAA82FF)
        public static let p400 = Color(hex: 0x9868FC)
        public static let p500 = Color(hex: 0x9849FD)
        public static let p600 = Color(hex: 0x8B38E5)
        public static let p700 = Color(hex: 0x693DE8)
        public static let p800 = Color(hex: 0x553DE8)
        public static let p900 = Color(hex: 0x462DE2)
    }

    @available(*, deprecated, message: "시맨틱 토큰을 사용하세요. P5 에서 삭제됩니다.")
    public enum Blue {
        public static let b50  = Color(hex: 0xF7FAFF)
        public static let b100 = Color(hex: 0xEBF3FF)
        public static let b200 = Color(hex: 0xDDEBFF)
        public static let b300 = Color(hex: 0x7EB2FF)
        public static let b400 = Color(hex: 0x448FFF)
        public static let b500 = Color(hex: 0x2070EB)
        public static let b600 = Color(hex: 0x0E68F0)
        public static let b700 = Color(hex: 0x005BE4)
        public static let b800 = Color(hex: 0x094FE5)
        public static let b900 = Color(hex: 0x0B3EAB)
    }

    @available(*, deprecated, message: "시맨틱 토큰을 사용하세요 (bg/surface/textPrimary 등). P5 에서 삭제됩니다.")
    public enum Gray {
        public static let g50  = Color(hex: 0xF8F8F8)
        public static let g100 = Color(hex: 0xEFEFEF)
        public static let g200 = Color(hex: 0xD9D9D9)
        public static let g300 = Color(hex: 0xBDBDBD)
        public static let g400 = Color(hex: 0xA0A0A0)
        public static let g500 = Color(hex: 0x919191)
        public static let g600 = Color(hex: 0x6E6E6E)
        public static let g700 = Color(hex: 0x4F4F4F)
        public static let g800 = Color(hex: 0x2C2C2C)
        public static let g900 = Color(hex: 0x1A1A1A)
    }

    @available(*, deprecated, message: "ChalNaTag 를 사용하세요. P5 에서 삭제됩니다.")
    public enum Chip {
        public static let liveBackground  = Color(hex: 0xFADAD9)
        public static let liveForeground  = Color(hex: 0xE53B38)
        public static let videoBackground = Color(hex: 0xE0D1FF)
        public static let videoForeground = Color(hex: 0x8B38E5)
        public static let filmBackground  = Color(hex: 0xDDEBFF)
        public static let filmForeground  = Color(hex: 0x2070EB)
    }

    @available(*, deprecated, renamed: "danger", message: "P5 에서 삭제됩니다.")
    public static let info = Color(hex: 0x02B8D3)
}

extension Color {
    /// 토큰 정의 전용 hex 이니셜라이저. 화면에서 직접 호출하지 않는다.
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
