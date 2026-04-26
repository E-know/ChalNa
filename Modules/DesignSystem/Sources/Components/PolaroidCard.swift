import SwiftUI

public enum PolaroidRotation: CaseIterable {
    case left, center, right

    public var degrees: Double {
        switch self {
        case .left:   return -2.5
        case .center: return  0.4
        case .right:  return  2.2
        }
    }
}

public struct PolaroidCard<Content: View>: View {
    public var rotation: PolaroidRotation
    public var width: CGFloat
    public var caption: String?
    public var meta: String?
    public var topTape: Bool
    public var content: () -> Content

    public init(
        rotation: PolaroidRotation = .center,
        width: CGFloat = 180,
        caption: String? = nil,
        meta: String? = nil,
        topTape: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.rotation = rotation
        self.width = width
        self.caption = caption
        self.meta = meta
        self.topTape = topTape
        self.content = content
    }

    public var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                content()
                    .aspectRatio(4/5, contentMode: .fill)
                    .frame(width: width - 24)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))

                if let caption {
                    Text(caption)
                        .font(MomentsTypography.handFallback(18))
                        .foregroundColor(MomentsColor.ink)
                }

                if let meta {
                    Text(meta)
                        .font(MomentsTypography.monoFallback(9, weight: .medium))
                        .tracking(0.5)
                        .foregroundColor(MomentsColor.taupe)
                }
            }
            .padding(EdgeInsets(top: 12, leading: 12, bottom: 24, trailing: 12))
            .frame(width: width)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: MomentsRadius.film, style: .continuous))
            .momentsShadow(MomentsShadow.polaroid)

            if topTape {
                MaskingTape(width: 60, height: 20, tint: .coral)
                    .rotationEffect(.degrees(-3))
                    .offset(y: -10)
            }
        }
        .rotationEffect(.degrees(rotation.degrees))
    }
}

#Preview {
    HStack(spacing: 14) {
        PolaroidCard(rotation: .left,  width: 168, caption: "Jeju, 04.05", meta: "LIVE · 01 / 24", topTape: true) {
            Rectangle().fill(LinearGradient(colors: [Color(hex: 0xF3C9A8), Color(hex: 0xC98B72)],
                                            startPoint: .top, endPoint: .bottom))
        }
        PolaroidCard(rotation: .center, width: 180, caption: "소길리, 오후 4시", meta: "VIDEO · 00:03", topTape: true) {
            Rectangle().fill(LinearGradient(colors: [Color(hex: 0xA8B89E), Color(hex: 0x3D5240)],
                                            startPoint: .top, endPoint: .bottom))
        }
        PolaroidCard(rotation: .right, width: 168, caption: "Last light ◦", meta: "LIVE · 18 / 24") {
            Rectangle().fill(LinearGradient(colors: [Color(hex: 0xC9B9A0), Color(hex: 0x8D7A61)],
                                            startPoint: .top, endPoint: .bottom))
        }
    }
    .padding(32)
    .background(MomentsColor.cream)
}
