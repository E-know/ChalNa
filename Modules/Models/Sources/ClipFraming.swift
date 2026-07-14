import CoreGraphics

/// 클립을 9:16 캔버스 안에 배치하는 기하의 단일 진실원천(SSOT).
/// 프리뷰·조정 화면·영상 합성(export)이 **모두 이 계산을 공유**해 WYSIWYG 가 어긋나지 않게 한다.
/// 좌표계는 SwiftUI/CG 표준(y-down). `display` 는 `preferredTransform` 적용 후 표시 크기.
///
/// 기준 배율은 **aspectFill(센터 크롭)** — 클립이 항상 캔버스를 꽉 덮는다(여백/블러 배경 없음).
/// 사용자 scale(≥1)은 fill 대비 추가 확대, offset 은 크롭 창 안에서 보이는 영역 이동을 뜻한다.
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

    /// renderSize 를 꽉 덮는 aspectFill 배율(회전 반영). 0/NaN/Inf 가드. 모든 배치의 기준 배율.
    public static func fillScale(display: CGSize, rotation: ClipRotation, render: CGSize) -> CGFloat {
        let s = orientedSize(display, rotation: rotation)
        let w = max(s.width, 1), h = max(s.height, 1)
        let raw = max(render.width / w, render.height / h)
        return (raw.isFinite && raw > 0) ? raw : 1
    }

    /// 축별 offset 이동 한계(renderSize 대비 정규화 비율, ±값).
    /// fill 기준이라 항상 한 축 이상은 캔버스를 초과해 이동 여지가 생기고, 딱 맞는 축은 0.
    public static func maxOffsetFraction(
        display: CGSize, rotation: ClipRotation, render: CGSize, scale: CGFloat
    ) -> CGPoint {
        let s = orientedSize(display, rotation: rotation)
        let fill = fillScale(display: display, rotation: rotation, render: render)
        let scaledW = s.width * fill * scale
        let scaledH = s.height * fill * scale
        let maxFracX = render.width > 0 ? max(scaledW - render.width, 0) / 2 / render.width : 0
        let maxFracY = render.height > 0 ? max(scaledH - render.height, 0) / 2 / render.height : 0
        return CGPoint(x: maxFracX, y: maxFracY)
    }

    /// 전경이 캔버스 밖 여백을 드러내지 않도록 offset(정규화 비율)을 clamp.
    /// proposed/return 모두 renderSize 대비 비율.
    public static func clampedOffset(
        _ proposed: CGPoint, display: CGSize, rotation: ClipRotation, render: CGSize, scale: CGFloat
    ) -> CGPoint {
        let limit = maxOffsetFraction(display: display, rotation: rotation, render: render, scale: scale)
        return CGPoint(
            x: min(max(proposed.x, -limit.x), limit.x),
            y: min(max(proposed.y, -limit.y), limit.y)
        )
    }

    /// 캔버스(render) 좌표계(y-down)에서 전경이 차지하는 사각형. scale·offset(clamp 적용) 반영.
    public static func resolvedRect(
        display: CGSize, rotation: ClipRotation, render: CGSize, transform: ClipTransform
    ) -> CGRect {
        let s = orientedSize(display, rotation: rotation)
        let fill = fillScale(display: display, rotation: rotation, render: render)
        let size = CGSize(width: s.width * fill * transform.scale, height: s.height * fill * transform.scale)
        let clamped = clampedOffset(transform.offset, display: display, rotation: rotation, render: render, scale: transform.scale)
        let center = CGPoint(x: render.width / 2 + clamped.x * render.width,
                             y: render.height / 2 + clamped.y * render.height)
        return CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                      width: size.width, height: size.height)
    }
}
