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

/// 섀도우 토큰.
///
/// 다크에서는 그림자가 거의 보이지 않으므로 깊이는
/// `bg → surface → surfaceRaised` 3단 밝기 + 1px hairline 으로 표현한다.
/// 그림자는 **떠 있는 툴바 하나**에만 쓴다.
///
/// 근거: docs/superpowers/specs/2026-07-28-app-redesign-design.md §4.2
public enum ChalNaShadow {

    /// 유일한 그림자. 플로팅 툴바 전용.
    public static let floating: [ChalNaShadowLayer] = [
        .init(Color.black.opacity(0.5), radius: 24, y: 8),
    ]

    // MARK: - Deprecated (P5 에서 삭제)

    @available(*, deprecated, message: "다크에서는 밝기 단계로 깊이를 표현합니다. 필요하면 .floating 만 쓰세요.")
    public static let sm: [ChalNaShadowLayer] = []
    @available(*, deprecated, message: "다크에서는 밝기 단계로 깊이를 표현합니다. 필요하면 .floating 만 쓰세요.")
    public static let md: [ChalNaShadowLayer] = [.init(Color.black.opacity(0.5), radius: 24, y: 8)]
    @available(*, deprecated, message: "다크에서는 밝기 단계로 깊이를 표현합니다. 필요하면 .floating 만 쓰세요.")
    public static let lg: [ChalNaShadowLayer] = [.init(Color.black.opacity(0.5), radius: 24, y: 8)]
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
