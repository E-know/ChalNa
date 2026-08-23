import Foundation
import Testing
import CoreGraphics
import QuartzCore
import Models
@testable import CompositionService

#if canImport(UIKit)
import UIKit
#endif

struct CustomLabelLayoutTests {

    // 정중앙(0.5,0.5) 라벨의 좌하단 origin (CoreAnimation y-up).
    // 센터 크롭에서 자막 앵커 기준(placedRect) = 캔버스 전체.
    @Test func customLabelOriginCenter() {
        let placed = CGRect(x: 0, y: 0, width: 1080, height: 1920)
        let origin = AVFoundationCompositionService.customLabelOrigin(
            placedRect: placed,
            position: CGPoint(x: 0.5, y: 0.5),
            textSize: CGSize(width: 200, height: 80),
            renderSize: CGSize(width: 1080, height: 1920)
        )
        // 중심 top-down=(540,960) → y-up center=960 → origin=(440,920)
        #expect(origin.x == 440)
        #expect(origin.y == 920)
    }

    // 상단(0.5,0.1) — 화면 위쪽이면 y-up origin 이 커진다.
    @Test func customLabelOriginTopArea() {
        let placed = CGRect(x: 0, y: 0, width: 1080, height: 1920)
        let origin = AVFoundationCompositionService.customLabelOrigin(
            placedRect: placed,
            position: CGPoint(x: 0.5, y: 0.1),
            textSize: CGSize(width: 300, height: 100),
            renderSize: CGSize(width: 1080, height: 1920)
        )
        // 중심 top-down=(540,192) → y-up center=1728 → origin=(390,1678)
        #expect(origin.x == 390)
        #expect(origin.y == 1678)
    }

    // 정규화 좌표는 0...1 로 클램프된다.
    @Test func customLabelOriginClamps() {
        let placed = CGRect(x: 0, y: 0, width: 1000, height: 2000)
        let origin = AVFoundationCompositionService.customLabelOrigin(
            placedRect: placed,
            position: CGPoint(x: 2.0, y: -1.0),  // → (1, 0)
            textSize: CGSize(width: 100, height: 40),
            renderSize: CGSize(width: 1000, height: 2000)
        )
        // 중심 top-down=(1000,0) → y-up center=2000 → origin=(950,1980)
        #expect(origin.x == 950)
        #expect(origin.y == 1980)
    }

    // MARK: - 배경 박스 ON/OFF (ClipLabel.hasBackground)

    #if canImport(UIKit)
    /// 배경 ON: [배경 박스, 텍스트] 2 레이어. 박스는 흰 면 + 검정 테두리, 글자는 검정.
    @Test func customLabelLayers_BackgroundOn_BoxAndBlackText() {
        let label = ClipLabel(text: "제주 바다", sizeFraction: 0.10,
                              position: CGPoint(x: 0.5, y: 0.5), hasBackground: true)
        let layers = AVFoundationCompositionService.makeCustomLabelLayers(
            label: label,
            placedRect: CGRect(x: 0, y: 0, width: 1080, height: 1920),
            renderSize: CGSize(width: 1080, height: 1920)
        )
        #expect(layers.count == 2, "배경 ON 은 [bg, text] 2 레이어: \(layers.count)")
        #expect(layers[0].backgroundColor == UIColor.white.cgColor, "박스 면은 흰색")
        #expect(layers[0].borderColor == UIColor.black.cgColor, "박스 테두리는 검정")
        #expect(layers[0].borderWidth > 0, "테두리 두께 \(layers[0].borderWidth)")

        let text = layers[1] as? CATextLayer
        let attrs = (text?.string as? NSAttributedString)?.attributes(at: 0, effectiveRange: nil)
        #expect(attrs?[.foregroundColor] as? UIColor == UIColor.black, "글자는 검정")
    }

    /// 배경 OFF: 텍스트 1 레이어만. 글자는 흰색, 장식(그림자·테두리) 없음.
    @Test func customLabelLayers_BackgroundOff_WhiteTextOnly() {
        let label = ClipLabel(text: "제주 바다", sizeFraction: 0.10,
                              position: CGPoint(x: 0.5, y: 0.5), hasBackground: false)
        let layers = AVFoundationCompositionService.makeCustomLabelLayers(
            label: label,
            placedRect: CGRect(x: 0, y: 0, width: 1080, height: 1920),
            renderSize: CGSize(width: 1080, height: 1920)
        )
        #expect(layers.count == 1, "배경 OFF 는 텍스트 1 레이어: \(layers.count)")

        let text = layers[0] as? CATextLayer
        let attrs = (text?.string as? NSAttributedString)?.attributes(at: 0, effectiveRange: nil)
        #expect(attrs?[.foregroundColor] as? UIColor == UIColor.white, "글자는 흰색")
    }

    /// 토글이 글자 위치를 움직이지 않는다 — 패딩을 유지하므로 textLayer.frame 이 동일해야 한다.
    /// (`ClipLabel.hasBackground` doc 의 규칙을 픽셀 기하로 잠근다.)
    @Test func customLabelLayers_ToggleKeepsTextFrame() {
        let placed = CGRect(x: 0, y: 0, width: 1080, height: 1920)
        let render = CGSize(width: 1080, height: 1920)
        let on = AVFoundationCompositionService.makeCustomLabelLayers(
            label: ClipLabel(text: "제주 바다", sizeFraction: 0.12,
                             position: CGPoint(x: 0.3, y: 0.7), hasBackground: true),
            placedRect: placed, renderSize: render
        )
        let off = AVFoundationCompositionService.makeCustomLabelLayers(
            label: ClipLabel(text: "제주 바다", sizeFraction: 0.12,
                             position: CGPoint(x: 0.3, y: 0.7), hasBackground: false),
            placedRect: placed, renderSize: render
        )
        let onText = on.last!.frame
        let offText = off.last!.frame
        #expect(onText == offText, "배경 토글이 글자 프레임을 바꿈: ON \(onText) vs OFF \(offText)")
    }
    #endif
}
