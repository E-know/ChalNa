import Foundation
import CoreGraphics
import Testing
import Models
@testable import CompositionService

#if canImport(UIKit)
import QuartzCore
import UIKit
#endif

/// 박스 자막의 텍스트 실측·자동 축소 SSOT(`Models.ClipLabelMetrics`) 계약.
///
/// 이 스위트의 존재 이유: 같은 실측 코드가 예전에 **3곳**(`LabelAnchorMath.textSize`,
/// `ClipLabelText.measuredSize`, `CompositionService.measureCustomText`)에 복제돼 있었고
/// 한쪽만 고쳐도 컴파일·테스트가 조용히 통과했다. 축소 규칙까지 복제되면 프리뷰와 출력이
/// 서로 다른 폰트를 쓴다.
struct ClipLabelMetricsTests {

    private let longText = "제주 바다에서 보낸 아주 길고 긴 하루의 기록"
    private let shortText = "제주"

    /// 가용폭 = 캔버스 폭 × 0.92 (양쪽 4%씩, `LabelLayout.paddingFraction` 재사용).
    private var availableWidth: CGFloat {
        ClipLabelMetrics.referenceCanvas.width * ClipLabelMetrics.availableWidthFraction
    }

    @Test func availableWidthDerivesFromAutoLabelPadding() {
        #expect(ClipLabelMetrics.availableWidthFraction == 1 - LabelLayout.paddingFraction * 2)
    }

    /// 긴 문구는 패딩 포함 박스가 가용폭 안으로 들어온다.
    @Test func longTextShrinksInsideAvailableWidth() {
        let fraction = ClipLabelMetrics.fittedSizeFraction(text: longText, userSizeFraction: 0.25)
        let px = fraction * ClipLabelMetrics.referenceCanvas.height
        let width = ClipLabelMetrics.paddedBoxSize(longText, fontPx: px).width
        #expect(fraction < 0.25, "긴 문구인데 축소가 걸리지 않았다: \(fraction)")
        #expect(width <= availableWidth + 0.5, "축소 후에도 가용폭 초과: \(width) > \(availableWidth)")
    }

    /// 짧은 문구는 사용자 의도 그대로.
    @Test func shortTextKeepsUserFraction() {
        #expect(ClipLabelMetrics.fittedSizeFraction(text: shortText, userSizeFraction: 0.10) == 0.10)
    }

    /// 배경 ON/OFF 에서 결과가 같다 — 패딩을 ON/OFF 동일하게 유지하므로 판정 입력이 같다.
    /// (`fittedSizeFraction` 이 `hasBackground` 를 아예 받지 않는다는 사실 자체가 계약이다.)
    @Test func fitIsIndependentOfBackgroundToggle() {
        let on = ClipLabel(text: longText, sizeFraction: 0.25, hasBackground: true)
        let off = ClipLabel(text: longText, sizeFraction: 0.25, hasBackground: false)
        let a = ClipLabelMetrics.fittedSizeFraction(text: on.text, userSizeFraction: on.clampedSizeFraction)
        let b = ClipLabelMetrics.fittedSizeFraction(text: off.text, userSizeFraction: off.clampedSizeFraction)
        #expect(a == b)
    }

    /// 하한 8px(기준 캔버스 1080×1920 기준 비율). 가용폭을 못 맞춰도 그 아래로 내리지 않는다.
    @Test func stopsAtMinimumFontEvenIfStillOverflowing() {
        let absurd = String(repeating: "가", count: 400)
        let fraction = ClipLabelMetrics.fittedSizeFraction(text: absurd, userSizeFraction: 0.25)
        let px = fraction * ClipLabelMetrics.referenceCanvas.height
        #expect(abs(px - ClipLabelMetrics.minFontPx) < 0.01, "하한 8px 이 지켜지지 않음: \(px)")
    }

    /// 같은 입력 → 같은 출력(결정론). 이분 탐색 반복수가 고정이어야 성립한다.
    @Test func isDeterministic() {
        let a = ClipLabelMetrics.fittedSizeFraction(text: longText, userSizeFraction: 0.25)
        let b = ClipLabelMetrics.fittedSizeFraction(text: longText, userSizeFraction: 0.25)
        #expect(a == b)
    }

    /// 비율은 캔버스 크기와 무관하다 → 프리뷰(작은 박스)와 출력(1080)이 **같은 비율**을 쓴다.
    @Test func fontPxScalesLinearlyWithCanvasHeight() {
        let out = ClipLabelMetrics.fontPx(text: longText, userSizeFraction: 0.25, canvasHeight: 1920)
        let preview = ClipLabelMetrics.fontPx(text: longText, userSizeFraction: 0.25, canvasHeight: 533)
        #expect(abs(preview - out * 533 / 1920) < 1e-9,
                "프리뷰/출력 폰트가 비례하지 않는다: preview \(preview), out \(out)")
    }

    /// 축소가 걸려도 **저장 모델의 사용자 의도는 변하지 않는다**(파생값이다).
    @Test func fitDoesNotMutateStoredSizeFraction() {
        var label = ClipLabel(text: longText, sizeFraction: 0.25)
        _ = ClipLabelMetrics.fittedSizeFraction(text: label.text, userSizeFraction: label.clampedSizeFraction)
        #expect(label.sizeFraction == 0.25)
        label.text = shortText
        #expect(label.sizeFraction == 0.25, "문구를 줄이면 사용자 의도가 그대로 복귀해야 한다")
    }

    #if canImport(UIKit)
    /// **합성이 실제로 이 SSOT 를 쓰는가.** 레이어에 박힌 폰트 크기를 직접 읽어 비교한다.
    @Test func compositionUsesFittedFontPx() {
        let label = ClipLabel(text: longText, sizeFraction: 0.25, position: CGPoint(x: 0.5, y: 0.5))
        let layers = AVFoundationCompositionService.makeCustomLabelLayers(
            label: label,
            placedRect: CGRect(origin: .zero, size: ClipLabelMetrics.referenceCanvas),
            renderSize: ClipLabelMetrics.referenceCanvas
        )
        let text = layers.last as? CATextLayer
        let attrs = (text?.string as? NSAttributedString)?.attributes(at: 0, effectiveRange: nil)
        let font = attrs?[.font] as? UIFont
        let expected = ClipLabelMetrics.fontPx(
            text: label.text, userSizeFraction: label.clampedSizeFraction,
            canvasHeight: ClipLabelMetrics.referenceCanvas.height
        )
        #expect(font != nil, "합성 텍스트 레이어에 폰트가 없다")
        #expect(abs((font?.pointSize ?? 0) - expected) < 0.01,
                "합성 폰트 \(font?.pointSize ?? 0) != SSOT \(expected)")
    }

    /// 오버레이 비트맵 크롭(`stampBounds`)은 레이어 frame 을 읽으므로 축소를 자동으로 따라간다.
    /// 별도 조치가 필요 없다는 것을 확인만 한다 — 축소된 라벨 박스는 캔버스 폭을 넘지 않는다.
    @Test func shrunkLabelDoesNotWidenLayerBox() {
        let layers = AVFoundationCompositionService.makeCustomLabelLayers(
            label: ClipLabel(text: longText, sizeFraction: 0.25, position: CGPoint(x: 0.5, y: 0.5)),
            placedRect: CGRect(origin: .zero, size: ClipLabelMetrics.referenceCanvas),
            renderSize: ClipLabelMetrics.referenceCanvas
        )
        let union = layers.reduce(CGRect.null) { $0.union($1.frame) }
        #expect(union.width <= ClipLabelMetrics.referenceCanvas.width,
                "축소된 라벨 박스가 캔버스 폭을 넘는다: \(union.width)")
    }
    #endif
}
