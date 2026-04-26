import SwiftUI

/// 좌측 여백의 노트북 펀치홀.
public struct PunchHole: View {
    public var size: CGFloat
    public init(size: CGFloat = 14) { self.size = size }

    public var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(hex: 0xD9CEBA),
                        Color(hex: 0xB9AD97),
                        MomentsColor.taupe
                    ],
                    center: UnitPoint(x: 0.4, y: 0.4),
                    startRadius: 0,
                    endRadius: size
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(0.35), lineWidth: 0.5)
                    .blur(radius: 0.5)
                    .offset(y: 0.5)
                    .mask(Circle())
            )
    }
}
