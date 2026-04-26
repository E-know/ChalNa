import SwiftUI

public enum MomentsChipVariant {
    case live
    case video
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
        HStack(spacing: 6) {
            leadingGlyph
            Text(label)
                .font(MomentsTypography.monoFallback(11, weight: .semibold))
                .tracking(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundColor(foreground)
        .background(
            Capsule(style: .continuous).fill(background)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(borderColor ?? .clear, style: .init(lineWidth: 1, dash: dashedBorder ? [3, 2] : []))
        )
    }

    // MARK: - Style resolution

    private var background: Color {
        switch variant {
        case .live:     return MomentsColor.Chip.liveBackground
        case .video:    return MomentsColor.Chip.videoBackground
        case .selected: return MomentsColor.ink
        case .dashed:   return MomentsColor.ivory
        case .custom(let bg, _, _): return bg
        }
    }

    private var foreground: Color {
        switch variant {
        case .live:     return MomentsColor.Chip.liveForeground
        case .video:    return MomentsColor.Chip.videoForeground
        case .selected: return MomentsColor.cream
        case .dashed:   return MomentsColor.taupe
        case .custom(_, let fg, _): return fg
        }
    }

    private var borderColor: Color? {
        switch variant {
        case .live:     return MomentsColor.Chip.liveForeground.opacity(0.2)
        case .video:    return MomentsColor.Chip.videoForeground.opacity(0.2)
        case .selected: return nil
        case .dashed:   return MomentsColor.taupe
        case .custom(_, _, let b): return b
        }
    }

    private var dashedBorder: Bool {
        if case .dashed = variant { return true }
        return false
    }

    @ViewBuilder
    private var leadingGlyph: some View {
        if case .live = variant {
            Circle()
                .fill(MomentsColor.Chip.liveForeground)
                .frame(width: 6, height: 6)
                .overlay(
                    Circle()
                        .stroke(MomentsColor.Chip.liveForeground.opacity(0.2), lineWidth: 3)
                        .frame(width: 10, height: 10)
                )
        } else if let icon {
            MomentsIcon(icon).frame(width: 10, height: 10)
        }
    }
}

#Preview {
    HStack {
        MomentsChip("LIVE", variant: .live)
        MomentsChip("VIDEO", variant: .video, icon: .film)
        MomentsChip("SELECTED", variant: .selected, icon: .plus)
        MomentsChip("+ 날짜", variant: .dashed)
    }
    .padding(32)
    .background(MomentsColor.cream)
}
