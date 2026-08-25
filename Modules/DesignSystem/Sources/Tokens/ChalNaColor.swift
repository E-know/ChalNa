import SwiftUI

/// 다크 전용 시맨틱 색 토큰.
///
/// 화면은 **역할 이름만** 쓴다. 과거의 수치 스케일(`Purple`/`Blue`/`Gray`)은
/// Task 26 에서 삭제됐다.
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
    /// **disabled 전용.** `bg` 대비 3.6:1 로 본문 기준(4.5)에 미달한다.
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
    /// `danger` 의 눌림 톤. `accentPressed` 가 `accent` 에 대해 하는 역할과 동일.
    /// 이게 없으면 파괴적 ghost 버튼이 눌린 동안 보라(`accentPressed`)로 바뀐다.
    public static let dangerPressed = Color(hex: 0xFF8F8B)

    // MARK: - Brand

    /// 앱 아이콘 색 그 자체. `bg` 대비 2.6:1 이므로
    /// **인터랙션(버튼·텍스트)에 쓰지 않는다.** Splash · 브랜드 면 전용.
    public static let brandDeep = Color(hex: 0x462DE2)

    // MARK: - Overlay

    public static let scrim = Color.black.opacity(0.6)

    // MARK: - Media overlay
    // 임의의 사용자 미디어 위에 놓이는 마크. 테마와 무관하게 고정이다 —
    // 아래 픽셀이 사진/영상이라 배경 밝기를 가정할 수 없다.
    /// 가이드선 · 라벨 등 밝은 마크.
    public static let onMedia     = Color.white
    /// 외곽선 · 스크림 등 어두운 마크.
    public static let onMediaDark = Color.black
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
