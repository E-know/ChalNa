import SwiftUI

/// 섹션 사이에 놓이는 scallop (작은 점) 구분선.
public struct ScallopDivider: View {
    public var dotSize: CGFloat
    public var spacing: CGFloat
    public var color: Color

    public init(dotSize: CGFloat = 3, spacing: CGFloat = 11, color: Color = MomentsColor.ink) {
        self.dotSize = dotSize
        self.spacing = spacing
        self.color = color
    }

    public var body: some View {
        GeometryReader { proxy in
            let count = Int(proxy.size.width / (dotSize + spacing))
            HStack(spacing: spacing) {
                ForEach(0..<max(count, 1), id: \.self) { _ in
                    Circle()
                        .fill(color.opacity(0.35))
                        .frame(width: dotSize, height: dotSize)
                }
            }
        }
        .frame(height: 4)
    }
}
