import SwiftUI

// Danawa DDS Mobile v2.0 칩/태그.
// Live(Red) · Video(Purple) · Film(Blue) · Selected · Dashed · Custom.
public enum ChalNaChipVariant {
    case live
    case video
    case film
    case selected
    case dashed
    case custom(background: Color, foreground: Color, border: Color?)
}

public struct ChalNaChip: View {
    public let label: String
    public let variant: ChalNaChipVariant
    public let icon: ChalNaIconKind?

    public init(_ label: String, variant: ChalNaChipVariant, icon: ChalNaIconKind? = nil) {
        self.label = label
        self.variant = variant
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: 4) {
            leadingGlyph
                .frame(width: 10, height: 10)
            Text(label)
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.tag, weight: .semibold))
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
            case .live:     return ChalNaColor.Chip.liveBackground
            case .video:    return ChalNaColor.Chip.videoBackground
            case .film:     return ChalNaColor.Chip.filmBackground
            case .selected: return ChalNaColor.ink
            case .dashed:   return Color.white
            case .custom(let bg, _, _): return bg
        }
    }

    private var foreground: Color {
        switch variant {
            case .live:     return ChalNaColor.Chip.liveForeground
            case .video:    return ChalNaColor.Chip.videoForeground
            case .film:     return ChalNaColor.Chip.filmForeground
            case .selected: return .white
            case .dashed:   return ChalNaColor.taupe
            case .custom(_, let fg, _): return fg
        }
    }

    private var borderColor: Color? {
        switch variant {
            case .live:     return ChalNaColor.Chip.liveForeground.opacity(0.25)
            case .video:    return ChalNaColor.Chip.videoForeground.opacity(0.25)
            case .film:     return ChalNaColor.Chip.filmForeground.opacity(0.25)
            case .selected: return nil
            case .dashed:   return ChalNaColor.Gray.g300
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
                    .resizable()
                    .scaledToFit()
            case .video:
                Image(systemName: "video")
                    .resizable()
                    .scaledToFit()
            default:
                ChalNaIcon(icon ?? .download).frame(width: 10, height: 10)
        }
    }
}

#Preview {
    HStack {
        ChalNaChip("LIVE", variant: .live)
        ChalNaChip("VIDEO", variant: .video, icon: .film)
        ChalNaChip("FILM", variant: .film, icon: .film)
        ChalNaChip("SELECTED", variant: .selected, icon: .plus)
        ChalNaChip("+ 날짜", variant: .dashed)
    }
    .padding(32)
    .background(ChalNaColor.cream)
}
