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

public enum MomentsShadow {

    private static let ink08 = Color(hex: 0x3D2E24, opacity: 0.08)
    private static let ink10 = Color(hex: 0x3D2E24, opacity: 0.10)
    private static let ink18 = Color(hex: 0x3D2E24, opacity: 0.18)
    private static let ink22 = Color(hex: 0x3D2E24, opacity: 0.22)
    private static let ink25 = Color(hex: 0x3D2E24, opacity: 0.25)
    private static let ink28 = Color(hex: 0x3D2E24, opacity: 0.28)

    public static let sm: [MomentsShadowLayer] = [
        .init(ink08, radius: 1, y: 1),
        .init(ink10, radius: 2, y: 2),
    ]

    public static let md: [MomentsShadowLayer] = [
        .init(ink08, radius: 2, y: 2),
        .init(ink18, radius: 8, y: 8),
    ]

    public static let lg: [MomentsShadowLayer] = [
        .init(ink08, radius: 4, y: 4),
        .init(ink25, radius: 20, y: 20),
    ]

    public static let polaroid: [MomentsShadowLayer] = [
        .init(ink08, radius: 1,  y: 1),
        .init(ink22, radius: 6,  y: 6),
        .init(ink28, radius: 18, y: 18),
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
