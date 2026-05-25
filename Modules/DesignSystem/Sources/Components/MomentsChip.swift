import SwiftUI

// Danawa DDS Mobile v2.0 칩/태그.
// Live(Red) · Video(Purple) · Film(Blue) · Selected · Dashed · Custom.
public enum MomentsChipVariant {
    case live
    case video
    case film
    case selected
    case dashed
    case custom(background: Color, foreground: Color, border: Color?)
}

public struct MomentsChip: View {
    public let label: String
    public let variant: MomentsChipVariant
    public let icon: MomentsIconKind?

    public init(_ label: String, variant: MomentsChipVariant, icon: MomentsIconKind? = nil) {
        self.label = label
        self.variant = variant
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: 4) {
            leadingGlyph
            Text(label)
                .font(MomentsTypography.krBody(MomentsTypography.Size.tag, weight: .semibold))
                .tracking(-0.20)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(foreground)
        .background(Capsule(style: .continuous).fill(background))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(borderColor ?? .clear, style: .init(lineWidth: 1, dash: dashedBorder ? [3, 2] : []))
        )
    }

    private var background: Color {
        switch variant {
            case .live:     return MomentsColor.Chip.liveBackground
            case .video:    return MomentsColor.Chip.videoBackground
            case .film:     return MomentsColor.Chip.filmBackground
            case .selected: return MomentsColor.ink
            case .dashed:   return Color.white
            case .custom(let bg, _, _): return bg
        }
    }

    private var foreground: Color {
        switch variant {
            case .live:     return MomentsColor.Chip.liveForeground
            case .video:    return MomentsColor.Chip.videoForeground
            case .film:     return MomentsColor.Chip.filmForeground
            case .selected: return .white
            case .dashed:   return MomentsColor.taupe
            case .custom(_, let fg, _): return fg
        }
    }

    private var borderColor: Color? {
        switch variant {
            case .live:     return MomentsColor.Chip.liveForeground.opacity(0.25)
            case .video:    return MomentsColor.Chip.videoForeground.opacity(0.25)
            case .film:     return MomentsColor.Chip.filmForeground.opacity(0.25)
            case .selected: return nil
            case .dashed:   return MomentsColor.Gray.g300
            case .custom(_, _, let b): return b
        }
    }

    private var dashedBorder: Bool {
        if case .dashed = variant { return true }
        return false
    }

    @ViewBuilder
    private var leadingGlyph: some View {
        switch variant {
            case .live:
                Image(systemName: "livephoto")
                    .frame(width: 6, height: 6)
            case .video:
                Image(systemName: "video")
                    .frame(width: 6, height: 6)
            default:
                MomentsIcon(icon ?? .download).frame(width: 10, height: 10)
        }
    }
}

#Preview {
    HStack {
        MomentsChip("LIVE", variant: .live)
        MomentsChip("VIDEO", variant: .video, icon: .film)
        MomentsChip("FILM", variant: .film, icon: .film)
        MomentsChip("SELECTED", variant: .selected, icon: .plus)
        MomentsChip("+ 날짜", variant: .dashed)
    }
    .padding(32)
    .background(MomentsColor.cream)
}
