import Testing
import SwiftUI
import UIKit
import DesignSystem

/// 역할 토큰 ↔ 표준 텍스트 스타일 매핑을 잠근다.
/// 근거: docs/superpowers/specs/2026-07-28-app-redesign-design.md §4.3
struct ChalNaTypographyTests {

    @Test func testRolesMapToStandardTextStyles() {
        #expect(ChalNaTypography.display  == Font.system(.title,    design: .default, weight: .bold))
        #expect(ChalNaTypography.title    == Font.system(.title2,   design: .default, weight: .semibold))
        #expect(ChalNaTypography.headline == Font.system(.headline, design: .default, weight: .semibold))
        #expect(ChalNaTypography.body     == Font.system(.callout,  design: .default, weight: .regular))
        #expect(ChalNaTypography.label    == Font.system(.footnote, design: .default, weight: .medium))
        #expect(ChalNaTypography.caption  == Font.system(.caption,  design: .default, weight: .regular))
    }

    @Test func testMonoUsesMonospacedDesign() {
        #expect(ChalNaTypography.mono() == Font.system(.footnote, design: .monospaced, weight: .regular))
        #expect(ChalNaTypography.mono(.body, weight: .semibold)
                == Font.system(.body, design: .monospaced, weight: .semibold))
    }

    /// 역할이 대응하는 텍스트 스타일의 기본 크기가 스펙의 pt 값과 일치해야 한다.
    /// (다르면 스케일 근거가 무너진 것 — 스펙 §4.3 을 다시 봐야 한다)
    @Test func testDefaultPointSizesMatchSpec() {
        let traits = UITraitCollection(preferredContentSizeCategory: .large)
        func size(_ style: UIFont.TextStyle) -> CGFloat {
            UIFont.preferredFont(forTextStyle: style, compatibleWith: traits).pointSize
        }
        #expect(size(.title1)      == 28, "display")
        #expect(size(.title2)      == 22, "title")
        #expect(size(.headline)    == 17, "headline")
        #expect(size(.callout)     == 16, "body")
        #expect(size(.footnote)    == 13, "label")
        #expect(size(.caption1)    == 12, "caption")
    }

    /// 최소 12pt 규칙: 가장 작은 역할(caption)이 기본 설정에서 12pt 이상이어야 한다.
    @Test func testSmallestRoleIsAtLeast12Points() {
        let traits = UITraitCollection(preferredContentSizeCategory: .large)
        let caption = UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: traits)
        #expect(caption.pointSize >= 12, "8pt·11pt 폰트 금지 규칙의 하한")
    }

    @Test func testKerisFontResolvesToConcreteFont() {
        let font = ChalNaTypography.kerisUIFont(48)
        #expect(font.pointSize == 48)
    }
}
