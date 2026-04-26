import SwiftUI

public enum MaskingTapeTint {
    case coral, sage, ivory
}

/// 45° 스트라이프 반복 + 좌우 잘린 모양(punch)을 가진 마스킹 테이프.
public struct MaskingTape: View {
    public var width: CGFloat
    public var height: CGFloat
    public var tint: MaskingTapeTint

    public init(width: CGFloat, height: CGFloat, tint: MaskingTapeTint = .coral) {
        self.width = width
        self.height = height
        self.tint = tint
    }

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(baseColor)
            Stripes(angle: 135, spacing: 16, stripeWidth: 8, color: stripeColor)
        }
        .frame(width: width, height: height)
        .clipShape(TapeShape(notchRadius: 3))
        .blendMode(.multiply)
        .shadow(color: MomentsColor.ink.opacity(0.12), radius: 1, y: 1)
    }

    private var baseColor: Color {
        MomentsColor.ivory.opacity(0.55)
    }

    private var stripeColor: Color {
        switch tint {
        case .coral:  return MomentsColor.coral.opacity(0.55)
        case .sage:   return MomentsColor.sage.opacity(0.55)
        case .ivory:  return MomentsColor.ivory.opacity(0.7)
        }
    }
}

private struct TapeShape: Shape {
    let notchRadius: CGFloat
    func path(in rect: CGRect) -> Path {
        // 좌우 짧은 반원 노치
        var p = Path()
        let r = notchRadius
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        var y: CGFloat = r
        while y < rect.maxY - r {
            p.addArc(center: CGPoint(x: rect.maxX, y: y + r),
                     radius: r,
                     startAngle: .degrees(-90),
                     endAngle: .degrees(90),
                     clockwise: false)
            y += 2 * r
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: 0, y: rect.maxY))
        y = rect.maxY - r
        while y > r {
            p.addArc(center: CGPoint(x: 0, y: y - r),
                     radius: r,
                     startAngle: .degrees(90),
                     endAngle: .degrees(270),
                     clockwise: false)
            y -= 2 * r
        }
        p.closeSubpath()
        return p
    }
}

private struct Stripes: View {
    let angle: Double
    let spacing: CGFloat
    let stripeWidth: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            Canvas { ctx, size in
                let diag = hypot(size.width, size.height)
                var x: CGFloat = -diag
                while x < diag {
                    let rect = CGRect(x: x, y: -diag, width: stripeWidth, height: diag * 2)
                    ctx.fill(Path(rect), with: .color(color))
                    x += spacing
                }
            }
            .rotationEffect(.degrees(angle), anchor: .center)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
