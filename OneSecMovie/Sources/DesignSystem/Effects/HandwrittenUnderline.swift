import SwiftUI

/// 손글씨 느낌의 물결형 밑줄. Coral 색상, 텍스트 아래 4~8pt 영역에 그린다.
public struct HandwrittenUnderlineShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var p = Path()
        let midY = rect.midY
        let amplitude = rect.height * 0.35
        p.move(to: CGPoint(x: rect.minX + 2, y: midY + amplitude * 0.3))
        p.addQuadCurve(
            to: CGPoint(x: rect.midX, y: midY - amplitude * 0.2),
            control: CGPoint(x: rect.minX + rect.width * 0.25, y: midY - amplitude)
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - 2, y: midY),
            control: CGPoint(x: rect.midX + rect.width * 0.25, y: midY + amplitude * 0.6)
        )
        return p
    }
}

public extension View {
    func handwrittenUnderline(color: Color = MomentsColor.coral, height: CGFloat = 8) -> some View {
        self.overlay(alignment: .bottom) {
            HandwrittenUnderlineShape()
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(height: height)
                .offset(y: height * 0.5 + 2)
        }
    }
}
