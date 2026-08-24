import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// 박스 자막(`ClipLabel`)의 **폰트 · 실측 · 자동 축소** 단일 진실 공급원.
///
/// 예전엔 같은 실측 코드가 3곳(`LabelAnchorMath.textSize`, `ClipLabelText.measuredSize`,
/// `CompositionService.measureCustomText`)에 바이트 단위로 복제돼 있었다 — 한쪽만 고치면
/// 프리뷰와 출력이 다른 폭을 갖는데 컴파일도 테스트도 조용했다.
///
/// **왜 DesignSystem 이 아니라 Models 인가**: `CompositionService` 는 `DesignSystem`·
/// `TimelineFeature` 를 볼 수 없다. 합성과 프리뷰가 공유할 수 있는 유일한 자리가 Models 다
/// (`LabelLayout`·`LabelText` 가 이미 같은 이유로 여기 있다).
///
/// **자동 축소는 기준 캔버스(`referenceCanvas`, 출력과 동일한 1080×1920)에서 계산해 *비율*을
/// 돌려준다.** 그래서 프리뷰(작은 박스)와 합성(1080)이 근사치가 아니라 **정확히 같은 비율**을
/// 쓴다. 하한도 px 이 아니라 `minFontPx / referenceCanvas.height` 비율로 표현한다.
public enum ClipLabelMetrics {

    /// 축소 판정 기준 캔버스 — 출력 캔버스(`AVFoundationCompositionService.outputSize`)와 동일.
    public static let referenceCanvas = CGSize(width: 1080, height: 1920)

    /// 폰트 하한(기준 캔버스 픽셀). 가용폭을 못 맞춰도 이 아래로는 내리지 않고 넘침을 허용한다.
    public static let minFontPx: CGFloat = 8

    /// 라벨 박스가 쓸 수 있는 가로 비율 — 양쪽 각각 캔버스 폭의 4%를 비운다.
    /// 자동 시각/날짜 라벨과 **같은 상수**(`LabelLayout.paddingFraction`)를 재사용해
    /// 화면 전체에서 라벨 여백이 일관되게 한다.
    public static var availableWidthFraction: CGFloat { 1 - LabelLayout.paddingFraction * 2 }

    /// 이분 탐색 반복수. **고정값이어야 결과가 결정론적이다**(합성·프리뷰·에디터가 같은 입력에
    /// 같은 값을 내야 한다). 24회면 [8, 480] px 구간이 ~3e-5px 까지 좁혀진다.
    private static let searchIterations = 24

    // MARK: - Font

    #if canImport(UIKit)
    /// 박스 자막 폰트 — 시스템 light 고정. 합성(`CATextLayer`)·프리뷰가 공유한다.
    public static func uiFont(px: CGFloat) -> UIFont {
        .systemFont(ofSize: px, weight: .light)
    }
    #endif

    // MARK: - Measurement

    /// 텍스트(패딩 제외) 실측 크기. `ceil` 반올림까지 포함해야 프리뷰·합성 박스가 맞는다.
    /// - 비-UIKit(테스트 호스트): 실측 불가 → 글자 수 근사(`LabelText.measure` 와 같은 방식).
    public static func textSize(_ text: String, fontPx: CGFloat) -> CGSize {
        #if canImport(UIKit)
        let measured = NSAttributedString(string: text, attributes: [
            .font: uiFont(px: fontPx),
            .kern: ClipLabel.BoxStyle.letterSpacing(for: fontPx),
        ]).size()
        return CGSize(width: ceil(measured.width), height: ceil(measured.height))
        #else
        return CGSize(width: fontPx * CGFloat(max(text.count, 1)), height: fontPx * 1.4)
        #endif
    }

    /// 패딩 포함 박스 크기. 패딩은 배경 ON/OFF 에서 **동일**하다(합성 정합 유지).
    public static func paddedBoxSize(_ text: String, fontPx: CGFloat) -> CGSize {
        let t = textSize(text, fontPx: fontPx)
        let padX = fontPx * ClipLabel.BoxStyle.horizontalPaddingFraction
        let padY = fontPx * ClipLabel.BoxStyle.verticalPaddingFraction
        return CGSize(width: t.width + padX * 2, height: t.height + padY * 2)
    }

    // MARK: - Auto shrink

    /// 사용자 의도(`sizeFraction`)를 가용폭에 맞춰 축소한 **파생** 비율.
    ///
    /// 저장 모델은 건드리지 않는다 — 슬라이더 값이 제멋대로 튀지 않고, 문구를 짧게 고치면
    /// 원래 크기로 복귀한다. 판정 대상은 **패딩 포함** 박스 폭이므로 배경 ON/OFF 결과가 같다.
    /// 세로(높이) 맞춤은 하지 않는다(자막은 1줄 고정).
    public static func fittedSizeFraction(text: String, userSizeFraction: CGFloat) -> CGFloat {
        let height = referenceCanvas.height
        let available = referenceCanvas.width * availableWidthFraction
        let userPx = userSizeFraction * height
        guard userPx > 0, available > 0 else { return userSizeFraction }
        guard paddedBoxSize(text, fontPx: userPx).width > available else { return userSizeFraction }

        // 하한에서도 넘치면 넘침을 허용하고 하한으로 고정(초장문 방어).
        guard paddedBoxSize(text, fontPx: minFontPx).width <= available else {
            return minFontPx / height
        }
        // 패딩·자간이 fontPx 비례라 대체로 선형이지만 `ceil` 과 kern 때문에 완전 선형은 아니다.
        // 반복수를 고정한 이분 탐색으로 좁히고, 항상 "만족하는 쪽"(lo)을 돌려준다.
        var lo = minFontPx
        var hi = userPx
        for _ in 0..<searchIterations {
            let mid = (lo + hi) / 2
            if paddedBoxSize(text, fontPx: mid).width <= available { lo = mid } else { hi = mid }
        }
        return lo / height
    }

    /// 실제 렌더 폰트(point/pixel). 프리뷰·에디터·합성이 **모두 이 함수를 부른다.**
    public static func fontPx(text: String, userSizeFraction: CGFloat, canvasHeight: CGFloat) -> CGFloat {
        fittedSizeFraction(text: text, userSizeFraction: userSizeFraction) * canvasHeight
    }
}

public extension ClipLabel {
    /// 이 라벨이 실제로 렌더될 폰트 비율(사용자 의도 ∧ 가용폭 맞춤).
    /// 저장값 `sizeFraction` 은 사용자 의도로 그대로 남고, 이 값이 파생된다.
    var renderedSizeFraction: CGFloat {
        ClipLabelMetrics.fittedSizeFraction(text: text, userSizeFraction: clampedSizeFraction)
    }

    /// 주어진 캔버스 높이에서의 실제 렌더 폰트 크기.
    func fontPx(canvasHeight: CGFloat) -> CGFloat {
        renderedSizeFraction * canvasHeight
    }
}
