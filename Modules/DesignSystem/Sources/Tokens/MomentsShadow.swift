import SwiftUI

public struct MomentsShadowLayer {
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

// Danawa DDS Mobile v2.0: drop shadow #000000 20% blur 6 표준.
public enum MomentsShadow {

    private static let black10 = Color.black.opacity(0.10)
    private static let black20 = Color.black.opacity(0.20)

    public static let sm: [MomentsShadowLayer] = [
        .init(black10, radius: 2, y: 1),
    ]

    /// 다나와 탭바 표준: #000000 20% blur 6
    public static let md: [MomentsShadowLayer] = [
        .init(black20, radius: 6, y: 2),
    ]

    public static let lg: [MomentsShadowLayer] = [
        .init(black10, radius: 4, y: 2),
        .init(black20, radius: 16, y: 8),
    ]
}

public extension View {
    @ViewBuilder
    func momentsShadow(_ layers: [MomentsShadowLayer]) -> some View {
        layers.reduce(AnyView(self)) { partial, layer in
            AnyView(partial.shadow(color: layer.color,
                                    radius: layer.radius,
                                    x: layer.x,
                                    y: layer.y))
        }
    }
}
