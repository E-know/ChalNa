import SwiftUI
import Testing
import Foundation
import CoreGraphics
import QuartzCore
import Models
@testable import TimelineFeature
@testable import CompositionService

#if canImport(UIKit)
import UIKit
#endif

/// 박스 자막 색 팔레트가 합성(`CATextLayer`)과 같은 규칙을 쓰는지 값 수준에서 잠근다.
/// 합성 쪽 대응 가드는 `CompositionServiceTests/CustomLabelLayoutTests` 다 —
/// 두 렌더 경로가 색을 따로 결정하면 WYSIWYG 가 조용히 어긋난다.
struct ClipLabelBoxPaletteTests {

    /// 배경 ON: 흰 박스 위 검정 글씨.
    @Test func foregroundWithBackgroundIsBlack() {
        #expect(ClipLabelBoxPalette.foreground(hasBackground: true, placeholder: false) == Color.black)
    }

    /// 배경 OFF: 영상 위 직접이라 흰 글씨.
    @Test func foregroundWithoutBackgroundIsWhite() {
        #expect(ClipLabelBoxPalette.foreground(hasBackground: false, placeholder: false) == Color.white)
    }

    /// placeholder 는 같은 색의 50% — 배경 유무와 무관하게 같은 규칙.
    @Test func placeholderDimsSameBase() {
        #expect(ClipLabelBoxPalette.foreground(hasBackground: true, placeholder: true)
                == Color.black.opacity(0.5))
        #expect(ClipLabelBoxPalette.foreground(hasBackground: false, placeholder: true)
                == Color.white.opacity(0.5))
    }

    /// 박스 면·테두리 색은 합성(bgLayer)과 동일해야 한다.
    @Test func boxColorsMatchComposition() {
        #expect(ClipLabelBoxPalette.boxFill == Color.white)
        #expect(ClipLabelBoxPalette.boxBorder == Color.black)
    }

    // MARK: - 실제 컴포지터 출력과의 교차 비교
    //
    // 위 테스트들은 팔레트 자기 값만 재확인한다 — 한쪽 모듈만 바꾸고 그 모듈 테스트만 고치면
    // 프리뷰·export 색이 조용히 갈라져도 이 파일은 계속 그린이었다. `TimelineFeatureTests` 는
    // `CompositionService` 에 이미 의존하므로(Project.swift), 팔레트 값을
    // `AVFoundationCompositionService.makeCustomLabelLayers` 가 실제로 만드는 레이어와 직접 비교한다.
#if canImport(UIKit)

    /// 팔레트 값을 실제 컴포지터 출력과 비교한다 — 글자색은 배경 ON/OFF 둘 다,
    /// 박스 면·테두리색은 배경 ON(박스가 존재하는 경우)만.
    @Test func paletteMatchesCompositorOutputForBothBackgroundStates() {
        for hasBackground in [true, false] {
            let label = ClipLabel(text: "제주 바다", sizeFraction: 0.10,
                                  position: CGPoint(x: 0.5, y: 0.5), hasBackground: hasBackground)
            let layers = AVFoundationCompositionService.makeCustomLabelLayers(
                label: label,
                placedRect: CGRect(x: 0, y: 0, width: 1080, height: 1920),
                renderSize: CGSize(width: 1080, height: 1920)
            )

            // 글자색: CATextLayer.foregroundColor.
            let textLayer = layers.last as? CATextLayer
            let attrs = (textLayer?.string as? NSAttributedString)?.attributes(at: 0, effectiveRange: nil)
            let compositorTextColor = attrs?[.foregroundColor] as? UIColor
            let paletteTextColor = ClipLabelBoxPalette.foreground(hasBackground: hasBackground, placeholder: false)

            #expect(compositorTextColor != nil, "컴포지터 텍스트 레이어에 foregroundColor 없음 (hasBackground=\(hasBackground))")
            #expect(
                rgbaComponents(paletteTextColor) == rgbaComponents(compositorTextColor ?? .clear),
                "글자색 hasBackground=\(hasBackground): 팔레트 \(rgbaComponents(paletteTextColor)) vs 컴포지터 \(rgbaComponents(compositorTextColor ?? .clear))"
            )

            // 박스 면·테두리색: bgLayer 는 배경 ON 에서만 존재([bg, text] 2 레이어).
            guard hasBackground else { continue }
            #expect(layers.count == 2, "배경 ON 은 [bg, text] 2 레이어여야 비교 가능하다: \(layers.count)")
            guard let bgLayer = layers.first, layers.count == 2 else { continue }

            let compositorFill = bgLayer.backgroundColor.map { UIColor(cgColor: $0) }
            let compositorBorder = bgLayer.borderColor.map { UIColor(cgColor: $0) }

            #expect(
                rgbaComponents(ClipLabelBoxPalette.boxFill) == rgbaComponents(compositorFill ?? .clear),
                "면색: 팔레트 \(rgbaComponents(ClipLabelBoxPalette.boxFill)) vs 컴포지터 \(rgbaComponents(compositorFill ?? .clear))"
            )
            #expect(
                rgbaComponents(ClipLabelBoxPalette.boxBorder) == rgbaComponents(compositorBorder ?? .clear),
                "테두리색: 팔레트 \(rgbaComponents(ClipLabelBoxPalette.boxBorder)) vs 컴포지터 \(rgbaComponents(compositorBorder ?? .clear))"
            )
        }
    }

    /// SwiftUI `Color` 와 `UIColor` 를 색공간이 다를 수 있는 `CGColor`/`UIColor` 객체 비교 없이
    /// RGBA 성분(0...1, 소수 3자리로 반올림)으로 통일해 값 비교한다.
    private func rgbaComponents(_ color: Color) -> [CGFloat] {
        rgbaComponents(UIColor(color))
    }

    private func rgbaComponents(_ color: UIColor) -> [CGFloat] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let scale: CGFloat = 1000  // 소수 3자리로 반올림해 색공간 변환 오차를 흡수(허용오차 역할)
        return [r, g, b, a].map { (($0 * scale).rounded()) / scale }
    }
#endif
}
