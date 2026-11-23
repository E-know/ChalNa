import CoreGraphics
import Models

struct HorizontalFramingSnap {
    enum Edge: Equatable {
        case leading, trailing, both
    }

    let edge: Edge
    let transform: ClipTransform

    // 화면 포인트 기준. 나갈 때 여유를 더 줘 손가락이 미세하게 움직여도 스냅이 유지된다.
    private static let captureDistance: CGFloat = 7
    private static let releaseDistance: CGFloat = 12

    static func resolve(
        _ raw: ClipTransform, rect: CGRect, canvasWidth: CGFloat,
        isScaling: Bool, retaining edge: Edge?
    ) -> Self? {
        guard canvasWidth > 0, rect.width > 0 else { return nil }
        let leading = -rect.minX
        let trailing = canvasWidth - rect.maxX

        if isScaling || edge == .both {
            let tolerance = edge == .both ? releaseDistance : captureDistance
            let fitScale = raw.scale * (canvasWidth / rect.width)
            if max(abs(leading), abs(trailing)) <= tolerance,
               (ClipTransform.minScale...ClipTransform.maxScale).contains(fitScale) {
                return Self(edge: .both, transform: ClipTransform(
                    scale: fitScale, offset: CGPoint(x: 0, y: raw.offset.y)
                ))
            }
        }

        let nearest: Edge
        if edge == .leading, abs(leading) <= releaseDistance {
            nearest = .leading
        } else if edge == .trailing, abs(trailing) <= releaseDistance {
            nearest = .trailing
        } else {
            guard min(abs(leading), abs(trailing)) <= captureDistance else { return nil }
            nearest = abs(leading) <= abs(trailing) ? .leading : .trailing
        }

        let distance = nearest == .leading ? leading : trailing
        var snapped = raw
        snapped.offset.x += distance / canvasWidth
        return Self(edge: nearest, transform: snapped)
    }
}
