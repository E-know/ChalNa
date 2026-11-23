import Testing
import SwiftUI
import UIKit
import DesignSystem

/// 사진집 UI의 본문과 선택·버튼 상태 대비.
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

    @Test func testSelectionRemainsLegible() {
        #expect(contrast(ChalNaColor.accent, ChalNaColor.selection) >= 4.5)
        #expect(contrast(ChalNaColor.textSecondary, ChalNaColor.surface) >= 4.5)
    }

    // MARK: - 서피스 위계

    @Test func testSurfaceLuminanceOrder() {
        let bg = luminance(ChalNaColor.bg)
        let surface = luminance(ChalNaColor.surface)
        let raised = luminance(ChalNaColor.surfaceRaised)
        #expect(surface < bg)
        #expect(bg < raised)
    }

    @Test func testMovieCanvasKeepsTrueBlackAndReadableStamps() {
        #expect(luminance(ChalNaColor.canvas) == 0)
        #expect(contrast(ChalNaColor.onMedia, ChalNaColor.canvas) >= 20)
    }
}
