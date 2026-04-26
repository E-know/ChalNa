import SwiftUI

/// 클립 썸네일 카드의 시각 상태.
public enum ClipThumbState: Hashable, Sendable {
    case normal
    case selected
    case playing
    case lifted
    case ghost        // 드래그 중 원래 자리(빈 슬롯)
    case dimmed       // 뒤로 물러난 상태
}

/// 필름 스트립 안의 미니 폴라로이드 카드(흰 테두리 + 회전 + 작은 그림자).
/// 타임라인의 idle/selected/playing/ghost/lifted 상태를 모두 수용.
public struct ClipThumbCard<Content: View>: View {

    public var state: ClipThumbState
    public var rotationDegrees: Double
    public var size: CGSize
    public var content: () -> Content

    public init(
        state: ClipThumbState = .normal,
        rotationDegrees: Double = 0,
        size: CGSize = CGSize(width: 40, height: 52),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.state = state
        self.rotationDegrees = rotationDegrees
        self.size = size
        self.content = content
    }

    public var body: some View {
        if case .ghost = state {
            RoundedRectangle(cornerRadius: MomentsRadius.film, style: .continuous)
                .strokeBorder(MomentsColor.coral.opacity(0.5), style: .init(lineWidth: 2, dash: [4, 3]))
                .background(
                    RoundedRectangle(cornerRadius: MomentsRadius.film, style: .continuous)
                        .fill(MomentsColor.coral.opacity(0.08))
                )
                .frame(width: size.width + 4, height: size.height + 6)
        } else {
            card
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            content()
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
        .padding(EdgeInsets(top: 3, leading: 3, bottom: 12, trailing: 3))
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(selectionOverlay)
        .shadow(color: baseShadowColor, radius: baseShadowRadius, x: 0, y: baseShadowY)
        .shadow(color: glowColor, radius: glowRadius, x: 0, y: 0)
        .rotationEffect(.degrees(rotationDegrees))
        .scaleEffect(scale, anchor: .bottom)
        .offset(y: offsetY)
        .opacity(opacity)
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        switch state {
        case .selected, .playing:
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(MomentsColor.coral, lineWidth: 2)
        default:
            EmptyView()
        }
    }

    private var scale: CGFloat {
        switch state {
        case .playing: return 1.18
        case .lifted:  return 1.18
        default:       return 1.0
        }
    }

    private var offsetY: CGFloat {
        state == .playing ? -6 : 0
    }

    private var opacity: Double {
        switch state {
        case .dimmed: return 0.55
        default:      return 1.0
        }
    }

    // shadow: base + optional glow
    private var baseShadowColor: Color {
        switch state {
        case .lifted:  return MomentsColor.ink.opacity(0.35)
        default:       return MomentsColor.ink.opacity(0.18)
        }
    }

    private var baseShadowRadius: CGFloat {
        switch state {
        case .lifted:  return 14
        default:       return 2
        }
    }

    private var baseShadowY: CGFloat {
        switch state {
        case .lifted:  return 14
        default:       return 1
        }
    }

    private var glowColor: Color {
        switch state {
        case .playing: return MomentsColor.coral.opacity(0.5)
        default:       return .clear
        }
    }

    private var glowRadius: CGFloat {
        state == .playing ? 12 : 0
    }
}

#Preview {
    HStack(alignment: .bottom, spacing: MomentsSpacing.md) {
        ClipThumbCard(state: .normal, rotationDegrees: -1) {
            ThumbnailPreset.jejuSea.view()
        }
        ClipThumbCard(state: .selected, rotationDegrees: 1) {
            ThumbnailPreset.hallasan.view()
        }
        ClipThumbCard(state: .playing) {
            ThumbnailPreset.sunset.view()
        }
        ClipThumbCard(state: .ghost) { Color.clear }
        ClipThumbCard(state: .dimmed, rotationDegrees: -1) {
            ThumbnailPreset.cafe.view()
        }
        ClipThumbCard(state: .lifted, rotationDegrees: -5, size: CGSize(width: 46, height: 60)) {
            ThumbnailPreset.hallasan.view()
        }
    }
    .padding(MomentsSpacing.xl)
    .background(MomentsColor.ink)
}
