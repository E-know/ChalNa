import CoreGraphics
import Foundation

/// 한 클립을 9:16 캔버스 안에서 사용자가 확대/이동한 상태.
/// 기본값 `.fit` = 맞춤(여백 발생). `ClipRotation`/`ClipLabel` 과 동일하게 EditSession 이 들고 다닌다.
public struct ClipTransform: Hashable, Sendable {
    /// 맞춤(fit) 대비 배율. 1.0 = 맞춤, <1.0 = 축소(프레임보다 작게), >1.0 = 확대. 권장 범위 [0.5, 4.0].
    public var scale: CGFloat
    /// 캔버스(renderSize) 기준 정규화 평행이동. x=가로 비율, y=세로 비율(y-down). clamp 는 `ClipFraming`.
    public var offset: CGPoint

    public init(scale: CGFloat = 1.0, offset: CGPoint = .zero) {
        self.scale = scale
        self.offset = offset
    }

    /// 맞춤(원본 그대로 aspectFit, 이동 없음).
    public static let fit = ClipTransform(scale: 1.0, offset: .zero)
}
