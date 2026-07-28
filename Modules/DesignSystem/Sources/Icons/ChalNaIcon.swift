import SwiftUI

/// 아이콘 종류. 내부 구현은 SF Symbols 로 통일돼 있다.
///
/// 이전에는 커스텀 Lucide 패스(1.5pt 고정 stroke) 20종 + SF Symbols 2종 + Chip 내부
/// SF Symbols 2종이 섞여 **같은 툴바에서 선 굵기가 다르게 보였다**. SF Symbols 로
/// 통일하면 optical sizing·weight 가 옆 텍스트와 자동으로 맞고 Dynamic Type 을 따른다.
///
/// 근거: `docs/superpowers/specs/2026-07-28-app-redesign-design.md` §5.4
public enum ChalNaIconKind: String, CaseIterable, Sendable {
    case play, pause, plus, share, download, heart, calendar, film
    case chevronLeft, chevronRight, close, check
    case skipBack, skipForward
    case scissors, reorderLines, trash, music
    case move
    case rotate
    case textLabel
    case settings
    case livePhoto
    case video

    /// 대응하는 SF Symbol 이름. `ChalNaIconTests` 가 존재 여부를 검증한다.
    public var systemName: String {
        switch self {
        case .play:         return "play.fill"
        case .pause:        return "pause.fill"
        case .plus:         return "plus"
        case .share:        return "square.and.arrow.up"
        case .download:     return "arrow.down.to.line"
        case .heart:        return "heart"
        case .calendar:     return "calendar"
        case .film:         return "film"
        case .chevronLeft:  return "chevron.left"
        case .chevronRight: return "chevron.right"
        case .close:        return "xmark"
        case .check:        return "checkmark"
        case .skipBack:     return "backward.end.fill"
        case .skipForward:  return "forward.end.fill"
        case .scissors:     return "scissors"
        case .reorderLines: return "line.3.horizontal"
        case .trash:        return "trash"
        case .music:        return "music.note"
        case .move:         return "arrow.up.and.down.and.arrow.left.and.right"
        case .rotate:       return "rotate.left"
        case .textLabel:    return "textformat"
        case .settings:     return "gearshape"
        case .livePhoto:    return "livephoto"
        case .video:        return "video"
        }
    }
}

/// SF Symbol 기반 아이콘.
///
/// `size` 는 기본 Dynamic Type 설정에서의 글리프 pt 이고, 사용자가 글씨를 키우면
/// `@ScaledMetric` 이 같은 비율로 확대한다.
public struct ChalNaIcon: View {
    /// Dynamic Type 배율. 값 1 을 `.body` 기준으로 스케일해 배율만 얻는다.
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    public let kind: ChalNaIconKind
    public var size: CGFloat
    public var weight: Font.Weight

    public init(_ kind: ChalNaIconKind, size: CGFloat = 24, weight: Font.Weight = .regular) {
        self.kind = kind
        self.size = size
        self.weight = weight
    }

    public var body: some View {
        Image(systemName: kind.systemName)
            .font(.system(size: size * typeScale, weight: weight))
            .symbolRenderingMode(.monochrome)
            .accessibilityHidden(true)   // 라벨은 감싸는 버튼이 제공한다
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 24) {
            ForEach(ChalNaIconKind.allCases, id: \.self) { kind in
                VStack(spacing: 8) {
                    ChalNaIcon(kind, size: 26)
                        .foregroundColor(ChalNaColor.textPrimary)
                    Text(verbatim: kind.rawValue)
                        .font(ChalNaTypography.caption)
                        .foregroundColor(ChalNaColor.textSecondary)
                }
            }
        }
        .padding(24)
    }
    .background(ChalNaColor.bg)
}
