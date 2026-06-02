import CoreGraphics

/// 클립을 9:16 캔버스 안에 배치하는 기하의 단일 진실원천(SSOT).
/// 프리뷰·조정 화면·영상 합성(export)이 **모두 이 계산을 공유**해 WYSIWYG 가 어긋나지 않게 한다.
/// 좌표계는 SwiftUI/CG 표준(y-down). `display` 는 `preferredTransform` 적용 후 표시 크기.
public enum ClipFraming {
    /// 사용자 회전 반영 표시 크기.
    public static func orientedSize(_ display: CGSize, rotation: ClipRotation) -> CGSize {
        rotation.swapsAxes ? CGSize(width: display.height, height: display.width) : display
    }

    /// renderSize 안 aspectFit 배율(회전 반영). 0/NaN/Inf 가드.
    public static func fitScale(display: CGSize, rotation: ClipRotation, render: CGSize) -> CGFloat {
        let s = orientedSize(display, rotation: rotation)
        let w = max(s.width, 1), h = max(s.height, 1)
        let raw = min(render.width / w, render.height / h)
        return (raw.isFinite && raw > 0) ? raw : 1
    }

    /// 전경이 renderSize 를 덮을 때 가장자리 밖 여백이 보이지 않도록 offset(정규화 비율)을 clamp.
    /// 덮지 못하는(작은) 축은 0(중앙)으로 고정. proposed/return 모두 renderSize 대비 비율.
    public static func clampedOffset(
        _ proposed: CGPoint, display: CGSize, rotation: ClipRotation, render: CGSize, scale: CGFloat
    ) -> CGPoint {
        let s = orientedSize(display, rotation: rotation)
        let fit = fitScale(display: display, rotation: rotation, render: render)
        let scaledW = s.width * fit * scale
        let scaledH = s.height * fit * scale
        let maxFracX = render.width > 0 ? max(0, (scaledW - render.width) / 2) / render.width : 0
        let maxFracY = render.height > 0 ? max(0, (scaledH - render.height) / 2) / render.height : 0
        return CGPoint(
            x: min(max(proposed.x, -maxFracX), maxFracX),
            y: min(max(proposed.y, -maxFracY), maxFracY)
        )
    }

    /// 캔버스(render) 좌표계(y-down)에서 전경이 차지하는 사각형. scale·offset(clamp 적용) 반영.
    public static func resolvedRect(
        display: CGSize, rotation: ClipRotation, render: CGSize, transform: ClipTransform
    ) -> CGRect {
        let s = orientedSize(display, rotation: rotation)
        let fit = fitScale(display: display, rotation: rotation, render: render)
        let size = CGSize(width: s.width * fit * transform.scale, height: s.height * fit * transform.scale)
        let clamped = clampedOffset(transform.offset, display: display, rotation: rotation, render: render, scale: transform.scale)
        let center = CGPoint(x: render.width / 2 + clamped.x * render.width,
                             y: render.height / 2 + clamped.y * render.height)
        return CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                      width: size.width, height: size.height)
    }
}
