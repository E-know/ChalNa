import CoreGraphics

/// 클립을 9:16 캔버스 안에 배치하는 기하의 단일 진실원천(SSOT).
/// 프리뷰·조정 화면·영상 합성(export)이 **모두 이 계산을 공유**해 WYSIWYG 가 어긋나지 않게 한다.
/// 좌표계는 SwiftUI/CG 표준(y-down). `display` 는 `preferredTransform` 적용 후 표시 크기.
///
/// 기준 배율은 **aspectFill(센터 크롭)** — `ClipTransform.fill`(scale 1, offset 0)이면 클립이
/// 캔버스를 꽉 덮는다. 하지만 사용자 scale·offset 에는 **제약이 없다**: scale < 1 이면 캔버스보다
/// 작아지고, offset 은 캔버스 밖까지 자유롭게 나갈 수 있다. 드러나는 여백은 검정이다
/// (합성은 `ChalNaVideoCompositor` 의 검정 베이스, 프리뷰는 `ChalNaColor.canvas`).
public enum ClipFraming {
    /// 사용자 회전 반영 표시 크기.
    public static func orientedSize(_ display: CGSize, rotation: ClipRotation) -> CGSize {
        rotation.swapsAxes ? CGSize(width: display.height, height: display.width) : display
    }

    /// renderSize 를 꽉 덮는 aspectFill 배율(회전 반영). 0/NaN/Inf 가드. 모든 배치의 기준 배율.
    public static func fillScale(display: CGSize, rotation: ClipRotation, render: CGSize) -> CGFloat {
        let s = orientedSize(display, rotation: rotation)
        let w = max(s.width, 1), h = max(s.height, 1)
        let raw = max(render.width / w, render.height / h)
        return (raw.isFinite && raw > 0) ? raw : 1
    }

    /// 캔버스(render) 좌표계(y-down)에서 전경이 차지하는 사각형. scale·offset 을 **clamp 없이** 반영한다.
    /// `transform` 은 `ClipTransform.sanitized` 의 산술 안전 가드만 통과한다 —
    /// export 경로(`AVFoundationCompositionService.transform`)도 같은 가드를 쓴다.
    public static func resolvedRect(
        display: CGSize, rotation: ClipRotation, render: CGSize, transform: ClipTransform
    ) -> CGRect {
        let t = transform.sanitized
        let s = orientedSize(display, rotation: rotation)
        let fill = fillScale(display: display, rotation: rotation, render: render)
        let size = CGSize(width: s.width * fill * t.scale, height: s.height * fill * t.scale)
        let center = CGPoint(x: render.width / 2 + t.offset.x * render.width,
                             y: render.height / 2 + t.offset.y * render.height)
        return CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                      width: size.width, height: size.height)
    }
}
