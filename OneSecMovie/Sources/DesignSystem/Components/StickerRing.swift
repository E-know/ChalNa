import SwiftUI

/// 원형 dashed 스티커. 여행 다이어리 스탬프 느낌. 내부에 자유 컨텐츠.
public struct StickerRing<Content: View>: View {
    public var size: CGFloat
    public var rotation: Double
    public var content: () -> Content

    public init(
        size: CGFloat = 120,
        rotation: Double = -10,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.size = size
        self.rotation = rotation
        self.content = content
    }

    public var body: some View {
        ZStack {
            Circle().fill(MomentsColor.ivory)
            Circle()
                .strokeBorder(
                    MomentsColor.taupe,
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                )
            content()
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(rotation))
        .momentsShadow(MomentsShadow.polaroid)
    }
}

#Preview {
    StickerRing {
        VStack(spacing: 2) {
            Text("made with")
                .font(MomentsTypography.handFallback(16))
                .foregroundColor(MomentsColor.coral)
            Text("film")
                .font(MomentsTypography.serifFallback(26, italic: true))
                .foregroundColor(MomentsColor.ink)
            Text("EST · 2026")
                .font(MomentsTypography.monoFallback(9, weight: .medium))
                .tracking(1)
                .foregroundColor(MomentsColor.taupe)
        }
    }
    .padding(32)
    .background(MomentsColor.cream)
}
