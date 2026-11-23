import SwiftUI

public struct ChalNaShadowLayer {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat

    public init(_ color: Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}

/// 종이 배경에서 콘텐츠 위로 뜬 도구와 안내를 구분한다.
public enum ChalNaShadow {
    public static let floating: [ChalNaShadowLayer] = [
        .init(ChalNaColor.textPrimary.opacity(0.14), radius: 12, y: 4),
    ]
}

public extension View {
    @ViewBuilder
    func chalNaShadow(_ layers: [ChalNaShadowLayer]) -> some View {
        layers.reduce(AnyView(self)) { partial, layer in
            AnyView(partial.shadow(color: layer.color,
                                   radius: layer.radius,
                                   x: layer.x,
                                   y: layer.y))
        }
    }
}
