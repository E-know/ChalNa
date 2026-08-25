import CoreGraphics
import Foundation

/// 한 클립을 9:16 캔버스 안에서 사용자가 확대/축소/이동한 상태.
/// 기본값 `.fill` = 센터 크롭(캔버스 꽉 채움). `ClipRotation`/`ClipLabel` 과 동일하게 EditSession 이 들고 다닌다.
///
/// **UX 제약은 없다.** 사용자는 캔버스보다 작게 줄이거나(여백 발생) 캔버스 밖으로 밀어낼 수 있다.
/// 드러나는 여백은 검정이다 — 합성은 `ChalNaVideoCompositor` 의 검정 베이스, 프리뷰는
/// `ChalNaColor.canvas`(= 검정) 가 받는다. `minScale`/`maxScale` 은 **UX 한계가 아니라
/// 산술 안전 가드**이며, 적용 지점은 `sanitized` 하나다.
public struct ClipTransform: Hashable, Sendable {
    /// aspectFill(센터 크롭) 대비 배율. 1.0 = 꽉 채움, <1.0 = 여백 생김, >1.0 = 추가 확대.
    public var scale: CGFloat
    /// 캔버스(renderSize) 기준 정규화 평행이동. x=가로 비율, y=세로 비율(y-down). 제한 없음.
    public var offset: CGPoint

    public init(scale: CGFloat = 1.0, offset: CGPoint = .zero) {
        self.scale = scale
        self.offset = offset
    }

    /// 산술 안전 가드용 배율 범위(0 나눗셈·오버플로 방지). **UX 제약이 아니다.**
    public static let minScale: CGFloat = 0.1
    public static let maxScale: CGFloat = 10.0

    /// 기본 프레이밍: aspectFill 센터 크롭(추가 확대·이동 없음).
    public static let fill = ClipTransform(scale: 1.0, offset: .zero)

    /// 산술 안전 가드를 적용한 값. scale 은 `[minScale, maxScale]` 로 clamp 하고,
    /// non-finite(NaN/Inf) 는 기본값으로 되돌린다. offset 은 범위 제한 없이 유한성만 본다.
    ///
    /// 프리뷰(`ClipFraming.resolvedRect`)와 export(`AVFoundationCompositionService.transform`)가
    /// **둘 다 이걸 경유**해 같은 값을 본다 — 예전엔 export 만 scale 을 clamp 하고 프리뷰는
    /// 하지 않는 비대칭이 있었다.
    public var sanitized: ClipTransform {
        let s = scale.isFinite ? min(max(scale, Self.minScale), Self.maxScale) : 1.0
        return ClipTransform(
            scale: s,
            offset: CGPoint(x: offset.x.isFinite ? offset.x : 0,
                            y: offset.y.isFinite ? offset.y : 0)
        )
    }
}
