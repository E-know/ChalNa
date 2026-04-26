import SwiftUI

/// Live Photo를 나타내는 동심원 뱃지.
/// 바깥: 얇은 링, 안쪽: 채워진 원.
public struct LiveBadge: View {
    public enum Style {
        case light   // 흰색 (사진 위)
        case dark    // 잉크 (밝은 배경 위)
    }

    public var size: CGFloat
    public var style: Style

    public init(size: CGFloat = 12, style: Style = .light) {
        self.size = size
        self.style = style
    }

    public var body: some View {
        let color: Color = (style == .light) ? .white : MomentsColor.ink
        return ZStack {
            Circle()
                .stroke(color, lineWidth: size * 0.11)
            Circle()
                .fill(color)
                .frame(width: size * 0.5, height: size * 0.5)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: MomentsSpacing.md) {
        LiveBadge(size: 18)
            .padding(MomentsSpacing.md)
            .background(Color.black)
        LiveBadge(size: 18, style: .dark)
            .padding(MomentsSpacing.md)
            .background(MomentsColor.cream)
    }
}
