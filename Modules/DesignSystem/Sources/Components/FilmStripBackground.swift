import SwiftUI

/// ink 배경 + 위아래 필름 스프로킷 도트. 컬러 팔레트 컨테이너로 사용.
public struct FilmStripBackground<Content: View>: View {
    public var verticalInset: CGFloat
    public var content: () -> Content

    public init(verticalInset: CGFloat = 22, @ViewBuilder content: @escaping () -> Content) {
        self.verticalInset = verticalInset
        self.content = content
    }

    public var body: some View {
        content()
            .padding(.horizontal, 22)
            .padding(.vertical, verticalInset + 18)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(MomentsColor.ink)
                    VStack {
                        SprocketRow()
                        Spacer()
                        SprocketRow()
                    }
                    .padding(.vertical, 4)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }
}

private struct SprocketRow: View {
    var body: some View {
        GeometryReader { proxy in
            let count = Int(proxy.size.width / 18)
            HStack(spacing: 11) {
                ForEach(0..<count, id: \.self) { _ in
                    Circle()
                        .fill(MomentsColor.cream)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 14)
    }
}
