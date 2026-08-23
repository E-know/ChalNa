import SwiftUI

/// 클립 썸네일 카드 상태. 6종 전부 유지 —
/// `lifted`·`ghost` 는 필름스트립 long-press 드래그가 쓴다.
public enum MediaThumbState: Hashable, Sendable {
    case normal
    case selected
    case playing
    case lifted
    /// 드래그 중 원래 자리(빈 슬롯).
    case ghost
    case dimmed
}

/// 그리드·필름스트립 공용 클립 썸네일.
///
/// 선택 링은 `accent` **바깥선 + 어두운 안쪽선 이중 스트로크**다 —
/// 밝은 썸네일 위에서도 링이 사라지지 않게 한다.
public struct MediaThumb<Content: View>: View {

    public var state: MediaThumbState
    /// `nil` 이면 가용 폭을 채우고 `aspect` 비율로 높이를 잡는다.
    public var size: CGSize?
    public var aspect: CGFloat
    public var content: () -> Content

    public init(
        state: MediaThumbState = .normal,
        size: CGSize? = nil,
        aspect: CGFloat = 9.0 / 16.0,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.state = state
        self.size = size
        self.aspect = aspect
        self.content = content
    }

    public var body: some View {
        if state == .ghost {
            ghostSlot
        } else {
            card
        }
    }

    private var ghostSlot: some View {
        RoundedRectangle(cornerRadius: ChalNaRadius.xs, style: .continuous)
            .strokeBorder(ChalNaColor.accent.opacity(0.7), style: .init(lineWidth: 2, dash: [4, 3]))
            .background(
                RoundedRectangle(cornerRadius: ChalNaRadius.xs, style: .continuous)
                    .fill(ChalNaColor.accent.opacity(0.10))
            )
            .modifier(ThumbFrame(size: size, aspect: aspect))
    }

    private var card: some View {
        content()
            .modifier(ThumbFrame(size: size, aspect: aspect))
            .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.xs, style: .continuous))
            .overlay(selectionRing)
            .scaleEffect(scale, anchor: .bottom)
            .offset(y: offsetY)
            .opacity(opacity)
            .animation(ChalNaMotion.fast, value: state)
    }

    /// accent 바깥선 + 어두운 안쪽선 — 밝은 썸네일에서도 링이 보이게.
    @ViewBuilder
    private var selectionRing: some View {
        switch state {
        case .selected, .playing:
            ZStack {
                RoundedRectangle(cornerRadius: ChalNaRadius.xs, style: .continuous)
                    .strokeBorder(ChalNaColor.onMediaDark.opacity(0.55), lineWidth: 3)
                RoundedRectangle(cornerRadius: ChalNaRadius.xs, style: .continuous)
                    .strokeBorder(ChalNaColor.accent, lineWidth: 2)
            }
        default:
            EmptyView()
        }
    }

    private var scale: CGFloat {
        switch state {
        case .playing: return 1.06
        case .lifted:  return 1.12
        default:       return 1.0
        }
    }

    private var offsetY: CGFloat { state == .playing ? -3 : 0 }

    private var opacity: Double { state == .dimmed ? 0.5 : 1.0 }
}

/// 고정 크기 / 비율 채우기 두 모드를 한 곳에서 처리한다.
private struct ThumbFrame: ViewModifier {
    let size: CGSize?
    let aspect: CGFloat

    func body(content: Content) -> some View {
        if let size {
            content.frame(width: size.width, height: size.height)
        } else {
            // 컨테이너를 9:16 박스로 확정하고, 그 안의 이미지는 호출처가
            // scaledToFill 로 넘치게 한 뒤 .clipped() 로 크롭한다.
            //
            // contentMode 는 반드시 .fit 이다. .fill 은 "제안된 공간을 채우도록" 크기를
            // 정하는데, LazyVGrid 셀의 높이 제안은 유연하므로 결과가 불확정해진다.
            // .fit 은 제안 안에 맞추므로 폭 = 열 폭, 높이 = 폭 × 16/9 로 확정된다.
            content
                .frame(maxWidth: .infinity)
                .aspectRatio(aspect, contentMode: .fit)
                .clipped()
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(alignment: .bottom, spacing: 12) {
            MediaThumb(size: CGSize(width: 46, height: 80)) {
                LinearGradient(colors: [.blue.opacity(0.6), .cyan], startPoint: .top, endPoint: .bottom)
            }
            MediaThumb(state: .selected, size: CGSize(width: 46, height: 80)) {
                LinearGradient(colors: [.teal, .yellow], startPoint: .top, endPoint: .bottom)
            }
            MediaThumb(state: .playing, size: CGSize(width: 46, height: 80)) {
                LinearGradient(colors: [.orange, .pink], startPoint: .top, endPoint: .bottom)
            }
            MediaThumb(state: .lifted, size: CGSize(width: 46, height: 80)) {
                LinearGradient(colors: [.purple, .pink], startPoint: .top, endPoint: .bottom)
            }
            MediaThumb(state: .ghost, size: CGSize(width: 46, height: 80)) { Color.clear }
            MediaThumb(state: .dimmed, size: CGSize(width: 46, height: 80)) {
                LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
            }
        }

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(0..<3, id: \.self) { i in
                MediaThumb(state: i == 1 ? .selected : .normal) {
                    LinearGradient(colors: [.gray, .indigo], startPoint: .top, endPoint: .bottom)
                }
            }
        }
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ChalNaColor.bg)
}
