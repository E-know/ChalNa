import Testing
import SwiftUI
import UIKit
import DesignSystem

/// 다크 토큰의 WCAG 대비 규칙을 잠근다.
/// 값 근거: docs/superpowers/specs/2026-07-28-app-redesign-design.md §4.1
struct ChalNaColorContrastTests {

    // MARK: - WCAG 2.1 상대 휘도 / 대비비

    private func luminance(_ color: Color) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    private func contrast(_ a: Color, _ b: Color) -> Double {
        let l1 = luminance(a), l2 = luminance(b)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    // MARK: - 본문 텍스트: 4.5:1 이상

    @Test func testTextPrimaryPassesEnhancedContrast() {
        let ratio = contrast(ChalNaColor.textPrimary, ChalNaColor.bg)
        #expect(ratio >= 7.0, "textPrimary/bg 는 AAA(7:1) 이상이어야 한다 — 실제 \(ratio)")
    }

    @Test func testTextSecondaryPassesBodyContrast() {
        let ratio = contrast(ChalNaColor.textSecondary, ChalNaColor.bg)
        #expect(ratio >= 4.5, "textSecondary/bg 는 본문 기준(4.5:1) 이상 — 실제 \(ratio)")
    }

    @Test func testAccentPassesBodyContrastOnBackground() {
        let ratio = contrast(ChalNaColor.accent, ChalNaColor.bg)
        #expect(ratio >= 4.5, "accent 는 텍스트·아이콘에 쓰이므로 4.5:1 이상 — 실제 \(ratio)")
    }

    @Test func testOnAccentPassesOnAccentFill() {
        let ratio = contrast(ChalNaColor.onAccent, ChalNaColor.accentFill)
        #expect(ratio >= 4.5, "면형 버튼 라벨은 4.5:1 이상 — 실제 \(ratio)")
    }

    // MARK: - 설계상 대비가 낮은 토큰: 오용 방지를 규칙으로 고정

    @Test func testTextTertiaryIsDisabledOnly() {
        let ratio = contrast(ChalNaColor.textTertiary, ChalNaColor.bg)
        #expect(ratio >= 3.0, "비활성 텍스트도 형태 식별은 되어야 한다 — 실제 \(ratio)")
        #expect(ratio < 4.5, "본문 기준을 넘으면 disabled 전용이라는 의미가 흐려진다 — 실제 \(ratio)")
    }

    @Test func testBrandDeepIsNotUsableForInteraction() {
        let ratio = contrast(ChalNaColor.brandDeep, ChalNaColor.bg)
        #expect(ratio < 3.0,
                "brandDeep 은 Splash·브랜드 면 전용. 이 값이 3:1 을 넘으면 인터랙션 금지 근거가 무너진다 — 실제 \(ratio)")
    }

    // MARK: - 서피스 위계

    @Test func testSurfaceLuminanceOrder() {
        let bg = luminance(ChalNaColor.bg)
        let surface = luminance(ChalNaColor.surface)
        let raised = luminance(ChalNaColor.surfaceRaised)
        #expect(bg < surface, "surface 는 bg 보다 밝아야 한다")
        #expect(surface < raised, "surfaceRaised 는 surface 보다 밝아야 한다")
    }

    @Test func testCanvasIsIndistinguishableFromBackground() {
        let ratio = contrast(ChalNaColor.canvas, ChalNaColor.bg)
        #expect(ratio < 1.2,
                "영상 캔버스와 화면 배경이 눈에 띄게 다르면 '검은 섬' 문제가 남는다 — 실제 \(ratio)")
    }
}
