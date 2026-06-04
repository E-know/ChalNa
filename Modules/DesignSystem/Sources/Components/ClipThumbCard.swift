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

/// 타임라인/그리드의 평면 클립 카드. 다나와 톤(평면 4px 라운딩 + 단색 테두리).
public struct ClipThumbCard<Content: View>: View {

    public var state: ClipThumbState
    public var size: CGSize
    public var content: () -> Content

    public init(
        state: ClipThumbState = .normal,
        size: CGSize = CGSize(width: 40, height: 52),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.state = state
        self.size = size
        self.content = content
    }

    public var body: some View {
        if case .ghost = state {
            RoundedRectangle(cornerRadius: ChalNaRadius.film, style: .continuous)
                .strokeBorder(ChalNaColor.coral.opacity(0.6), style: .init(lineWidth: 2, dash: [4, 3]))
                .background(
                    RoundedRectangle(cornerRadius: ChalNaRadius.film, style: .continuous)
                        .fill(ChalNaColor.coral.opacity(0.08))
                )
                .frame(width: size.width + 4, height: size.height + 6)
        } else {
            card
        }
    }

    private var card: some View {
        content()
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.film, style: .continuous))
            .overlay(selectionOverlay)
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
            .scaleEffect(scale, anchor: .bottom)
            .offset(y: offsetY)
            .opacity(opacity)
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        switch state {
        case .selected, .playing:
            RoundedRectangle(cornerRadius: ChalNaRadius.film, style: .continuous)
                .strokeBorder(ChalNaColor.coral, lineWidth: 2)
        default:
            EmptyView()
        }
    }

    private var scale: CGFloat {
        switch state {
        case .playing: return 1.10
        case .lifted:  return 1.12
        default:       return 1.0
        }
    }

    private var offsetY: CGFloat {
        state == .playing ? -4 : 0
    }

    private var opacity: Double {
        switch state {
        case .dimmed: return 0.55
        default:      return 1.0
        }
    }

    private var shadowColor: Color {
        switch state {
        case .lifted:  return Color.black.opacity(0.30)
        case .playing: return ChalNaColor.coral.opacity(0.4)
        default:       return Color.black.opacity(0.10)
        }
    }

    private var shadowRadius: CGFloat {
        switch state {
        case .lifted:  return 14
        case .playing: return 8
        default:       return 2
        }
    }

    private var shadowY: CGFloat {
        switch state {
        case .lifted:  return 10
        default:       return 1
        }
    }
}

#Preview {
    HStack(alignment: .bottom, spacing: 16) {
        ClipThumbCard(state: .normal) {
            LinearGradient(colors: [.blue.opacity(0.6), .cyan], startPoint: .top, endPoint: .bottom)
        }
        ClipThumbCard(state: .selected) {
            LinearGradient(colors: [.green.opacity(0.7), .mint], startPoint: .top, endPoint: .bottom)
        }
        ClipThumbCard(state: .playing) {
            LinearGradient(colors: [.orange, .pink], startPoint: .top, endPoint: .bottom)
        }
        ClipThumbCard(state: .ghost) { Color.clear }
        ClipThumbCard(state: .lifted, size: CGSize(width: 46, height: 60)) {
            LinearGradient(colors: [.purple.opacity(0.7), .pink], startPoint: .top, endPoint: .bottom)
        }
    }
    .padding(32)
    .background(ChalNaColor.ivory)
}
