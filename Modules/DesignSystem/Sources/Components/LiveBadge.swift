import SwiftUI

/// Live Photo 강조용 작은 dot 뱃지. 다나와 톤에서는 Red-500 으로 노출.
public struct LiveBadge: View {
    public enum Style {
        case light   // 다크 배경 위 (사진 위) — White dot
        case dark    // 밝은 배경 위 — Red-500 dot
    }

    public var size: CGFloat
    public var style: Style

    public init(size: CGFloat = 12, style: Style = .light) {
        self.size = size
        self.style = style
    }

    public var body: some View {
        let color: Color = (style == .light) ? .white : MomentsColor.danger
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
    HStack(spacing: 16) {
        LiveBadge(size: 18)
            .padding(16)
            .background(Color.black)
        LiveBadge(size: 18, style: .dark)
            .padding(16)
            .background(MomentsColor.cream)
    }
}
