import CoreGraphics
import Foundation

/// 한 클립을 9:16 캔버스 안에서 사용자가 확대/이동한 상태.
/// 기본값 `.fill` = 센터 크롭(캔버스 꽉 채움). `ClipRotation`/`ClipLabel` 과 동일하게 EditSession 이 들고 다닌다.
public struct ClipTransform: Hashable, Sendable {
    /// aspectFill(센터 크롭) 대비 배율. 1.0 = 꽉 채움(크롭 기본), >1.0 = 추가 확대. 유효 범위 [1.0, 4.0].
    public var scale: CGFloat
    /// 캔버스(renderSize) 기준 정규화 평행이동. x=가로 비율, y=세로 비율(y-down). clamp 는 `ClipFraming`.
    public var offset: CGPoint

    public init(scale: CGFloat = 1.0, offset: CGPoint = .zero) {
        self.scale = scale
        self.offset = offset
    }

    /// 사용자 scale 하한(= aspectFill 그대로. 이보다 축소하면 여백이 드러나므로 금지)과 상한.
    public static let minScale: CGFloat = 1.0
    public static let maxScale: CGFloat = 4.0

    /// 기본 프레이밍: aspectFill 센터 크롭(추가 확대·이동 없음).
    public static let fill = ClipTransform(scale: 1.0, offset: .zero)
}
